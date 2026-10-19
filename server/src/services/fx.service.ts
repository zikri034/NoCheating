import db from '../db/knex';

export interface FxRatesResult {
  base: string;
  rates: Record<string, number>;
  source: 'live' | 'cache' | 'demo';
  updated_at: string;
}

const DEMO_FALLBACK_RATES: Record<string, number> = {
  USD: 0.00006154,
  EUR: 0.00005714,
  MYR: 0.00027397,
  JPY: 0.00921659,
};

/**
 * Fetch and cache exchange rates from base IDR to USD, EUR, MYR, JPY
 */
export async function getExchangeRates(base = 'IDR'): Promise<FxRatesResult> {
  const cacheHours = parseInt(process.env.FX_CACHE_HOURS || '6', 10);
  const now = new Date();
  const threshold = new Date(now.getTime() - cacheHours * 60 * 60 * 1000);

  // Check if we have recent cached rates
  const cached = await db('fx_rates')
    .where({ base })
    .where('fetched_at', '>=', threshold);

  if (cached.length >= 4) {
    const rates: Record<string, number> = {};
    cached.forEach((r) => {
      rates[r.quote] = Number(r.rate);
    });
    return {
      base,
      rates,
      source: 'cache',
      updated_at: cached[0].fetched_at.toISOString(),
    };
  }

  // Attempt live fetch from public exchange rate API (open.er-api.com)
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3500);

    const response = await fetch(`https://open.er-api.com/v6/latest/${base}`, {
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (response.ok) {
      const data = (await response.json()) as { rates?: Record<string, number> };
      if (data.rates) {
        const targetCurrencies = ['USD', 'EUR', 'MYR', 'JPY'];
        const liveRates: Record<string, number> = {};

        for (const quote of targetCurrencies) {
          if (data.rates[quote]) {
            liveRates[quote] = data.rates[quote];
            // Upsert into fx_rates
            await db('fx_rates')
              .insert({
                base,
                quote,
                rate: liveRates[quote],
                fetched_at: now,
              })
              .onConflict(['base', 'quote'])
              .merge({
                rate: liveRates[quote],
                fetched_at: now,
              });
          }
        }

        return {
          base,
          rates: liveRates,
          source: 'live',
          updated_at: now.toISOString(),
        };
      }
    }
  } catch (_err) {
    // Live fetch failed (network down/timeout) - fallback to any DB cache
  }

  // Fallback to any DB cached rates (even if older than threshold)
  const anyCached = await db('fx_rates').where({ base });
  if (anyCached.length > 0) {
    const rates: Record<string, number> = {};
    anyCached.forEach((r) => {
      rates[r.quote] = Number(r.rate);
    });
    return {
      base,
      rates,
      source: 'cache',
      updated_at: anyCached[0].fetched_at ? new Date(anyCached[0].fetched_at).toISOString() : now.toISOString(),
    };
  }

  // Final fallback to static demo rates
  return {
    base,
    rates: DEMO_FALLBACK_RATES,
    source: 'demo',
    updated_at: now.toISOString(),
  };
}

/**
 * Convert IDR amount to foreign currencies
 */
export function convertIdr(amountIdr: number, rates: Record<string, number>) {
  const result: Record<string, number> = {};
  for (const [curr, rate] of Object.entries(rates)) {
    result[curr] = parseFloat((amountIdr * rate).toFixed(curr === 'JPY' ? 2 : 4));
  }
  return result;
}
