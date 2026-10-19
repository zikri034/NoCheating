import { Router, Request, Response } from 'express';
import { jwtMiddleware } from '../middleware/auth.middleware';
import db from '../db/knex';
import {
  verifyChain,
  getReceiptByAttemptId,
  ensureGenesisBlock,
} from '../chain/blockchain.service';

const router = Router();

/**
 * GET /api/chain
 * List all blocks on the blockchain
 */
router.get('/', jwtMiddleware, async (_req: Request, res: Response) => {
  try {
    await ensureGenesisBlock();
    const blocks = await db('blocks').orderBy('idx', 'asc');
    return res.json({
      blocks: blocks.map((b) => ({
        ...b,
        idx: Number(b.idx),
        nonce: Number(b.nonce),
      })),
    });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'CHAIN_FETCH_ERROR', message: error.message },
    });
  }
});

/**
 * GET /api/chain/verify
 * Recalculate entire chain hashes and verify tamper status
 */
router.get('/verify', jwtMiddleware, async (_req: Request, res: Response) => {
  try {
    await ensureGenesisBlock();
    const result = await verifyChain();
    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'CHAIN_VERIFY_ERROR', message: error.message },
    });
  }
});

/**
 * GET /api/chain/receipt/:attemptId
 * Fetch blockchain receipts (SUBMISSION & RESULT) for an exam attempt
 */
router.get('/receipt/:attemptId', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const attemptId = req.params.attemptId as string;
    const receipts = await getReceiptByAttemptId(attemptId);
    return res.json({ receipts });
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'RECEIPT_FETCH_ERROR', message: error.message },
    });
  }
});

export default router;
