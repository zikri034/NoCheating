import { Router, Request, Response } from 'express';
import { jwtMiddleware } from '../middleware/auth.middleware';
import { getExchangeRates, convertIdr } from '../services/fx.service';

const router = Router();

/**
 * GET /api/fx
 * Fetch exchange rates for currency conversion (IDR to USD, EUR, MYR, JPY)
 */
router.get('/', jwtMiddleware, async (req: Request, res: Response) => {
  try {
    const base = (req.query.base as string) || 'IDR';
    const amountStr = req.query.amount as string | undefined;

    const fxData = await getExchangeRates(base);

    if (amountStr && !isNaN(Number(amountStr))) {
      const amount = Number(amountStr);
      const converted = convertIdr(amount, fxData.rates);
      return res.json({
        ...fxData,
        input_amount: amount,
        converted,
      });
    }

    return res.json(fxData);
  } catch (error: any) {
    return res.status(500).json({
      error: { code: 'FX_FETCH_ERROR', message: error.message },
    });
  }
});

export default router;
