import crypto from 'crypto';
import db from '../db/knex';
import { Knex } from 'knex';

export interface Block {
  idx: number;
  type: 'GENESIS' | 'SUBMISSION' | 'RESULT';
  prev_hash: string;
  hash: string;
  data_canonical: string;
  data: Record<string, any>;
  nonce: number;
  created_at: Date | string;
}

/**
 * Standardize JSON string representation with deterministically sorted keys
 * to guarantee cryptographic hash reproducibility regardless of DB JSON formatting.
 */
export function deterministicStringify(obj: any): string {
  if (obj === null || typeof obj !== 'object') {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return '[' + obj.map(deterministicStringify).join(',') + ']';
  }
  const keys = Object.keys(obj).sort();
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + deterministicStringify(obj[k])).join(',') + '}';
}

/**
 * Compute SHA-256 hash of canonical data string
 */
export function computeDataHash(dataCanonical: string): string {
  return crypto.createHash('sha256').update(dataCanonical).digest('hex');
}

/**
 * Compute block hash: SHA-256(idx | prev_hash | SHA-256(data_canonical) | nonce)
 */
export function computeBlockHash(
  idx: number | string,
  prevHash: string,
  dataHash: string,
  nonce: number | string
): string {
  const payload = `${idx}|${prevHash}|${dataHash}|${nonce}`;
  return crypto.createHash('sha256').update(payload).digest('hex');
}

/**
 * Mine block nonce that satisfies lightweight Proof-of-Work (CHAIN_DIFFICULTY leading zeros)
 */
export function mineNonce(
  idx: number,
  prevHash: string,
  dataHash: string,
  difficulty = 3
): { nonce: number; hash: string } {
  const prefix = '0'.repeat(difficulty);
  let nonce = 0;
  while (true) {
    const hash = computeBlockHash(idx, prevHash, dataHash, nonce);
    if (hash.startsWith(prefix)) {
      return { nonce, hash };
    }
    nonce++;
  }
}

/**
 * Genesis Block Initializer
 */
export async function ensureGenesisBlock(trx?: Knex.Transaction | Knex): Promise<Block> {
  const client = trx || db;
  const existingGenesis = await client('blocks').where({ idx: 0 }).first();
  if (existingGenesis) {
    return {
      ...existingGenesis,
      idx: Number(existingGenesis.idx),
      nonce: Number(existingGenesis.nonce),
    };
  }

  const difficulty = parseInt(process.env.CHAIN_DIFFICULTY || '3', 10);
  const data = {
    title: 'SafeExam Genesis Anchor',
    message: 'Academic integrity and tamper-evident examination hash-chain',
    version: '1.0.0',
  };
  const dataCanonical = deterministicStringify(data);
  const dataHash = computeDataHash(dataCanonical);
  const prevHash = '0'.repeat(64);

  const { nonce, hash } = mineNonce(0, prevHash, dataHash, difficulty);

  const [genesis] = await client('blocks')
    .insert({
      idx: 0,
      type: 'GENESIS',
      prev_hash: prevHash,
      hash,
      data_canonical: dataCanonical,
      data: JSON.stringify(data),
      nonce,
      created_at: new Date(),
    })
    .returning('*');

  return {
    ...genesis,
    idx: Number(genesis.idx),
    nonce: Number(genesis.nonce),
  };
}

/**
 * Append a new block (SUBMISSION or RESULT) with PostgreSQL advisory transaction lock
 */
export async function appendBlock(
  type: 'SUBMISSION' | 'RESULT',
  data: Record<string, any>
): Promise<Block> {
  const difficulty = parseInt(process.env.CHAIN_DIFFICULTY || '3', 10);

  return await db.transaction(async (trx) => {
    // Acquire transaction-scoped advisory lock to serialize block creation
    await trx.raw('SELECT pg_advisory_xact_lock(16)');

    await ensureGenesisBlock(trx);

    const latest = await trx('blocks').orderBy('idx', 'desc').first();
    const nextIdx = Number(latest.idx) + 1;
    const prevHash = latest.hash;

    const dataCanonical = deterministicStringify(data);
    const dataHash = computeDataHash(dataCanonical);

    const { nonce, hash } = mineNonce(nextIdx, prevHash, dataHash, difficulty);

    const [inserted] = await trx('blocks')
      .insert({
        idx: nextIdx,
        type,
        prev_hash: prevHash,
        hash,
        data_canonical: dataCanonical,
        data: JSON.stringify(data),
        nonce,
        created_at: new Date(),
      })
      .returning('*');

    return {
      ...inserted,
      idx: Number(inserted.idx),
      nonce: Number(inserted.nonce),
    };
  });
}

/**
 * Verify entire blockchain integrity from genesis to the latest block
 */
export async function verifyChain(trx?: Knex.Transaction | Knex): Promise<{
  valid: boolean;
  blockCount: number;
  corruptedIndex?: number;
  error?: string;
}> {
  const client = trx || db;
  const blocks = await client('blocks').orderBy('idx', 'asc');

  if (blocks.length === 0) {
    return { valid: true, blockCount: 0 };
  }

  const difficulty = parseInt(process.env.CHAIN_DIFFICULTY || '3', 10);
  const prefix = '0'.repeat(difficulty);

  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i];
    const idx = Number(block.idx);
    const nonce = Number(block.nonce);

    if (idx !== i) {
      return {
        valid: false,
        blockCount: blocks.length,
        corruptedIndex: idx,
        error: `Urutan index tidak berurutan: diharapkan ${i}, ditemukan ${idx}`,
      };
    }

    if (i === 0) {
      if (block.type !== 'GENESIS' || block.prev_hash !== '0'.repeat(64)) {
        return {
          valid: false,
          blockCount: blocks.length,
          corruptedIndex: 0,
          error: 'Genesis block tidak valid',
        };
      }
    } else {
      const prevBlock = blocks[i - 1];
      if (block.prev_hash !== prevBlock.hash) {
        return {
          valid: false,
          blockCount: blocks.length,
          corruptedIndex: idx,
          error: `Hash rantai terputus pada block #${idx}: prev_hash tidak cocok dengan hash block #${idx - 1}`,
        };
      }
    }

    // Recompute hash
    const dataHash = computeDataHash(block.data_canonical);
    const recomputedHash = computeBlockHash(idx, block.prev_hash, dataHash, nonce);

    if (recomputedHash !== block.hash) {
      return {
        valid: false,
        blockCount: blocks.length,
        corruptedIndex: idx,
        error: `Manipulasi data terdeteksi pada block #${idx}: hash tersimpan tidak cocok dengan hash rekalkulasi`,
      };
    }

    if (!recomputedHash.startsWith(prefix)) {
      return {
        valid: false,
        blockCount: blocks.length,
        corruptedIndex: idx,
        error: `Proof of Work tidak valid pada block #${idx}: hash tidak diawali ${difficulty} nol`,
      };
    }
  }

  return {
    valid: true,
    blockCount: blocks.length,
  };
}

/**
 * Fetch receipt blocks by attemptId
 */
export async function getReceiptByAttemptId(attemptId: string) {
  const blocks = await db('blocks')
    .whereRaw("data->>'attempt_id' = ?", [attemptId])
    .orderBy('idx', 'asc');

  return blocks.map((b) => ({
    ...b,
    idx: Number(b.idx),
    nonce: Number(b.nonce),
    qr_payload: `SAFEEXAM:BLOCK:${b.idx}:${b.hash}:${b.type}`,
  }));
}
