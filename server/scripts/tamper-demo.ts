import db from '../src/db/knex';
import {
  ensureGenesisBlock,
  appendBlock,
  verifyChain,
} from '../src/chain/blockchain.service';

/**
 * Tamper Demo Script (PRD F16)
 * Demonstrates how tampering with a single block in the database
 * breaks cryptographic integrity and causes verifyChain() to immediately detect it.
 */
async function runTamperDemo() {
  console.log('--- [DEMO TAMPER BLOCKCHAIN] ---');

  // 1. Ensure genesis exists and append a sample block
  console.log('1. Memastikan Genesis Block & menambahkan blok uji coba...');
  await ensureGenesisBlock();

  const sampleBlock = await appendBlock('SUBMISSION', {
    attempt_id: '11111111-1111-1111-1111-111111111111',
    exam_id: '22222222-2222-2222-2222-222222222222',
    student_ref: 'abc123hash',
    answers_hash: 'def456hash',
    submitted_at: new Date().toISOString(),
  });
  console.log(`-> Blok #${sampleBlock.idx} berhasil ditambahkan. Hash: ${sampleBlock.hash}`);

  // 2. Initial verification (should be valid)
  console.log('2. Memverifikasi integritas awal blockchain...');
  let check = await verifyChain();
  console.log('Hasil Verifikasi Awal:', check);
  if (!check.valid) {
    console.error('FAIL: Rantai awal seharusnya valid!');
    process.exit(1);
  }

  // 3. TAMPER! Modify data in the database directly
  console.log(`3. Melakukan TAMPER / manipulasi ilegal pada blok #${sampleBlock.idx} di database...`);
  const originalDataCanonical = sampleBlock.data_canonical;
  await db('blocks')
    .where({ idx: sampleBlock.idx })
    .update({
      data_canonical: JSON.stringify({ hacked: true, score: 100 }),
    });

  // 4. Verify again (MUST FAIL!)
  console.log('4. Memverifikasi ulang rantai setelah manipulasi...');
  check = await verifyChain();
  console.log('Hasil Verifikasi Setelah Tamper:', check);

  if (!check.valid && check.corruptedIndex === sampleBlock.idx) {
    console.log(`✅ BERHASIL: Sistem integritas sukses mendeteksi kecurangan pada blok #${check.corruptedIndex}!`);
    console.log(`Pesan Error: ${check.error}`);
  } else {
    console.error('FAIL: Sistem gagal mendeteksi manipulasi data!');
  }

  // 5. Restore original data so DB is left clean
  console.log('5. Mengembalikan data ke kondisi asli...');
  await db('blocks')
    .where({ idx: sampleBlock.idx })
    .update({
      data_canonical: originalDataCanonical,
    });

  check = await verifyChain();
  console.log('Hasil Verifikasi Akhir (Restored):', check);
  console.log('--- [DEMO SELESAI] ---');
  process.exit(0);
}

runTamperDemo().catch((err) => {
  console.error('Error executing tamper demo:', err);
  process.exit(1);
});
