// Deterministic verification: RMSE, ETS, CSI, POD, FAR, FSS (+ Brier, reliability, regime-wise). Same sample/threshold for raw & corrected.
const r3 = v => +v.toFixed(3);
function rmse(p, o) { return Math.sqrt(p.reduce((s, x, i) => s + (x - o[i]) ** 2, 0) / p.length); }
function contingency(p, o, t) {
  let H = 0, FA = 0, M = 0, CN = 0;
  p.forEach((x, i) => { const f = x >= t, ob = o[i] >= t; if (f && ob) H++; else if (f) FA++; else if (ob) M++; else CN++; }); return { H, FA, M, CN };
}
function cat({ H, FA, M, CN }) {
  const N = H + FA + M + CN, hr = N ? (H + FA) * (H + M) / N : 0, d = (a, b) => (b ? a / b : 0);
  return { ETS: d(H - hr, H + FA + M - hr), CSI: d(H, H + FA + M), POD: d(H, H + M), FAR: d(FA, H + FA) };
}
function fss(rows, pick, t, radius = 1) { // district-grid FSS, neighbourhood = (2r+1)^2 cells
  let num = 0, den = 0; const days = [...new Set(rows.map(r => r.c.day))];
  for (const day of days) {
    const rs = rows.filter(r => r.c.day === day);
    const frac = key => rs.map(a => {
      let n = 0, k = 0;
      rs.forEach(b => { if (Math.abs(a.c.gx - b.c.gx) <= radius && Math.abs(a.c.gy - b.c.gy) <= radius) { n++; if (key(b) >= t) k++; } }); return k / n;
    });
    const pf = frac(pick), po = frac(r => r.c.observedMm);
    pf.forEach((x, i) => { num += (x - po[i]) ** 2; den += x * x + po[i] * po[i]; });
  }
  return den ? 1 - num / den : 0;
}

function verify(rows, thr) {
  const obs = rows.map(r => r.c.observedMm), raw = rows.map(r => r.c.rawMm), cor = rows.map(r => r.res.correctedMm);
  const cr = cat(contingency(raw, obs, thr)), cc = cat(contingency(cor, obs, thr));
  const M = (name, a, b, lowerBetter = false, unit) => ({ name, raw: r3(a), corrected: r3(b), ...(lowerBetter && { lowerBetter }), ...(unit && { unit }) });
  const regimeWise = [...new Set(rows.map(r => r.c.trueRegime))].map(reg => {
    const s = rows.filter(r => r.c.trueRegime === reg), o = s.map(r => r.c.observedMm);
    return { regime: reg, n: s.length, rmseRaw: r3(rmse(s.map(r => r.c.rawMm), o)), rmseCorrected: r3(rmse(s.map(r => r.res.correctedMm), o)) };
  });
  const bins = [0, .2, .4, .6, .8, 1.0001].slice(0, -1).map((lo, i) => {
    const hi = [.2, .4, .6, .8, 1.0001][i], s = rows.filter(r => r.res.heavyProb >= lo && r.res.heavyProb < hi);
    return {
      range: `${lo}-${Math.min(hi, 1).toFixed(1)}`, n: s.length, meanForecast: s.length ? r3(s.reduce((a, r) => a + r.res.heavyProb, 0) / s.length) : null,
      observedFreq: s.length ? r3(s.filter(r => r.c.observedMm >= thr).length / s.length) : null
    };
  });
  const brier = rows.reduce((s, r) => s + (r.res.heavyProb - (r.c.observedMm >= thr ? 1 : 0)) ** 2, 0) / rows.length;
  const ok = rows.filter(r => r.res.regime === r.c.trueRegime || (r.res.regime === 'Coastal Rainfall' && r.c.terrain === 'coastal') || (r.res.regime === 'Orographic Rainfall' && r.c.terrain === 'orographic')).length;
  return {
    metrics: [M('RMSE', rmse(raw, obs), rmse(cor, obs), true, 'mm'), M('ETS', cr.ETS, cc.ETS), M('CSI', cr.CSI, cc.CSI), M('POD', cr.POD, cc.POD),
    M('FAR', cr.FAR, cc.FAR, true), M('FSS', fss(rows, r => r.c.rawMm, thr), fss(rows, r => r.res.correctedMm, thr))],
    regimeWise, brier: r3(brier), reliability: bins, classifier: { accuracy: r3(ok / rows.length), n: rows.length },
    sample: { cases: rows.length, observedEvents: obs.filter(x => x >= thr).length, threshold: thr, aiSources: [...new Set(rows.map(r => r.res.source))] }
  };
}
module.exports = { verify };
