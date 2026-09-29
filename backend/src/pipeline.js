// Regime classification + correction + heavy-rain probability, powered by Gemini (rule-based fallback if unavailable).
const { generateJSON, configured } = require('./gemini');
const { THRESHOLDS, promptView } = require('./data');
const REGIMES = ['Active Monsoon', 'Break Monsoon', 'Monsoon Depression', 'Coastal Rainfall', 'Orographic Rainfall', 'Western Disturbance', 'Unclassified'];
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const num = (v, d = 0) => (Number.isFinite(+v) ? +v : d);

const SYSTEM = `You are an operational post-processing engine for Indian monsoon rainfall forecasts (IMD style).
For EACH input case (24h raw NWP rainfall in mm plus atmospheric features):
1. Classify the prevailing regime from: ${REGIMES.join(', ')}. Use humidity, CAPE, 850hPa wind, MSLP anomaly (negative = low pressure), monsoon-core-zone anomaly (sigma: >0.5 active, <-0.5 break) and terrain.
2. Apply a regime-conditioned correction to rawMm. Known NWP tendencies: underestimates rain in monsoon depressions and orographic/coastal enhancement, mildly underestimates in active spells, overestimates in break spells. Do not blindly scale: use your judgement per case.
3. Estimate P(24h rain > ${THRESHOLDS.heavy} mm) as heavyProb and P(> ${THRESHOLDS.veryHeavy} mm) as veryHeavyProb for the CORRECTED forecast, reflecting realistic uncertainty (avoid 0 or 1). veryHeavyProb must be <= heavyProb.
4. confidence is your 0-1 confidence in the regime label. rationale: max 25 words.
Never invent data. Return one result per id.`;
const SCHEMA = {
  type: 'ARRAY', items: {
    type: 'OBJECT', required: ['id', 'regime', 'confidence', 'correctedMm', 'heavyProb', 'veryHeavyProb', 'rationale'],
    properties: {
      id: { type: 'STRING' }, regime: { type: 'STRING', enum: REGIMES }, confidence: { type: 'NUMBER' }, correctedMm: { type: 'NUMBER' },
      heavyProb: { type: 'NUMBER' }, veryHeavyProb: { type: 'NUMBER' }, rationale: { type: 'STRING' }
    }
  }
};

// Physical / sanity constraints (over-correction guard)
function sanitize(r, c, source) {
  const raw = c.rawMm, lo = raw < 5 ? 0 : raw * .3, hi = raw * 3 + 10;
  const heavy = clamp(num(r.heavyProb), 0, 1);
  return {
    id: c.id, regime: REGIMES.includes(r.regime) ? r.regime : 'Unclassified', confidence: clamp(num(r.confidence, .5), 0, 1),
    correctedMm: +clamp(num(r.correctedMm, raw), lo, hi).toFixed(1), heavyProb: +heavy.toFixed(2),
    veryHeavyProb: +Math.min(heavy, clamp(num(r.veryHeavyProb), 0, 1)).toFixed(2), rationale: String(r.rationale || '').slice(0, 200), source
  };
}

// ---- Rule-based fallback (used when Gemini is unavailable or a case is missing) ----
function fallbackOne(c, why = 'Gemini unavailable') {
  const f = c.features; let regime, factor;
  if (f.mslpAnomalyHpa <= -5 && f.humidityPct >= 88) { regime = 'Monsoon Depression'; factor = 1.35; }
  else if (f.mczAnomalySigma <= -.5 || f.humidityPct < 72) { regime = 'Break Monsoon'; factor = .7; }
  else if (c.terrain === 'orographic' && f.wind850ms >= 15) { regime = 'Orographic Rainfall'; factor = 1.3; }
  else if (c.terrain === 'coastal' && f.humidityPct >= 84) { regime = 'Coastal Rainfall'; factor = 1.2; }
  else { regime = 'Active Monsoon'; factor = 1.15; }
  const corr = c.rawMm * factor, sig = Math.max(8, corr * .3);
  const p = t => 1 / (1 + Math.exp(-(corr - t) / (sig * .6)));
  return sanitize({
    regime, confidence: .6, correctedMm: corr, heavyProb: p(THRESHOLDS.heavy), veryHeavyProb: p(THRESHOLDS.veryHeavy),
    rationale: `Rule-based fallback (${why}).`
  }, c, 'fallback');
}

async function processCases(cases, size = 20) {
  const out = [];
  for (let i = 0; i < cases.length; i += size) {
    const chunk = cases.slice(i, i + size);
    try {
      if (!configured()) throw new Error('no API key');
      const res = await generateJSON({
        system: SYSTEM, schema: SCHEMA,
        prompt: `Threshold context: heavy=${THRESHOLDS.heavy} mm, very heavy=${THRESHOLDS.veryHeavy} mm.\nCases:\n${JSON.stringify(chunk.map(promptView))}`
      });
      const m = new Map((Array.isArray(res) ? res : []).map(x => [x.id, x]));
      chunk.forEach(c => out.push(m.has(c.id) ? sanitize(m.get(c.id), c, 'gemini') : fallbackOne(c, 'missing in AI reply')));
    } catch (e) { console.warn('[pipeline] Gemini failed:', e.message); chunk.forEach(c => out.push(fallbackOne(c, e.message.slice(0, 60)))); }
  }
  return out;
}

async function explain(c, r) {
  const fb = {
    summary: `${c.district}: ${r.regime} regime, raw ${c.rawMm} mm corrected to ${r.correctedMm} mm; heavy-rain probability ${Math.round(r.heavyProb * 100)}%.`,
    drivers: [`MSLP anomaly ${c.features.mslpAnomalyHpa} hPa`, `Humidity ${c.features.humidityPct}%`, `850hPa wind ${c.features.wind850ms} m/s`],
    caveats: ['Probabilities express risk, not certainty.', 'Requires forecaster review.'], action: 'Monitor updates and follow official IMD warnings.', source: 'fallback'
  };
  if (!configured()) return fb;
  try {
    const j = await generateJSON({
      system: 'You are a senior IMD forecaster assistant. Explain briefly and factually for a district-level user. Decision support only; never claim certainty.',
      schema: {
        type: 'OBJECT', required: ['summary', 'drivers', 'caveats', 'action'], properties: {
          summary: { type: 'STRING' },
          drivers: { type: 'ARRAY', items: { type: 'STRING' } }, caveats: { type: 'ARRAY', items: { type: 'STRING' } }, action: { type: 'STRING' }
        }
      },
      prompt: `Explain this post-processed rainfall forecast (max 60 words summary, 3 drivers, 2 caveats, 1 action).\nInput: ${JSON.stringify(promptView(c))}\nResult: ${JSON.stringify(r)}`
    });
    return { ...j, source: 'gemini' };
  } catch (e) { return fb; }
}
module.exports = { processCases, explain, fallbackOne, REGIMES };
