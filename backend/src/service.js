const { THRESHOLDS, currentCases, hindcastCases } = require('./data');
const { processCases, explain } = require('./pipeline');
const { verify } = require('./verify');
const TTL = () => (+process.env.CACHE_TTL_MIN || 60) * 60000;
const cache = new Map();
function cached(key, fn) {
  const e = cache.get(key); if (e && Date.now() - e.t < TTL()) return e.p;
  const p = fn().catch(err => { cache.delete(key); throw err; }); cache.set(key, { t: Date.now(), p }); return p;
}
const clear = () => cache.clear();
const srcOf = rs => { const s = new Set(rs.map(r => r.source)); return s.size === 1 ? [...s][0] : 'mixed'; };

const forecast = () => cached('forecast', async () => {
  const cases = currentCases(), res = await processCases(cases);
  const rows = cases.map((c, i) => ({ c, res: res[i] }));
  return {
    rows, source: srcOf(res), districts: rows.map(({ c, res: r }) => ({
      district: c.district, regime: r.regime, confidence: r.confidence,
      rawMm: c.rawMm, correctedMm: r.correctedMm, heavyProb: r.heavyProb, veryHeavyProb: r.veryHeavyProb, source: r.source, rationale: r.rationale
    }))
  };
});
const summary = async () => {
  const f = await forecast(), ds = f.districts, top = [...ds].sort((a, b) => b.heavyProb - a.heavyProb)[0];
  const counts = {}; ds.forEach(d => counts[d.regime] = (counts[d.regime] || 0) + 1);
  const regime = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
  const conf = ds.filter(d => d.regime === regime).reduce((s, d) => s + d.confidence, 0) / counts[regime];
  return {
    cycle: '00 UTC • Day-1 (sample)', regime, confidence: +conf.toFixed(2), threshold: THRESHOLDS.heavy, source: f.source,
    headline: `${top.district} has the highest heavy-rain risk (${Math.round(top.heavyProb * 100)}%)`,
    highRiskCount: ds.filter(d => d.heavyProb >= .5).length, modelVersion: `Gemini regime-router (${process.env.GEMINI_MODEL || 'gemini-2.5-flash'})`
  };
};
const verification = () => cached('verify', async () => {
  const cases = hindcastCases(), res = await processCases(cases);
  const v = verify(cases.map((c, i) => ({ c, res: res[i] })), THRESHOLDS.heavy);
  return { ...v, note: `Hindcast on ${cases.length} synthetic district-days at ≥${THRESHOLDS.heavy} mm. AI never saw observations. Source: ${v.sample.aiSources.join(', ')}.` };
});
const explainDistrict = async name => {
  const f = await forecast(), row = f.rows.find(r => r.c.district.toLowerCase() === name.toLowerCase());
  if (!row) return null; return cached('explain:' + row.c.district, async () => ({ district: row.c.district, ...(await explain(row.c, row.res)) }));
};
module.exports = { forecast, summary, verification, explainDistrict, clear, THRESHOLDS };
