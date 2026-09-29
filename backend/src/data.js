// Synthetic sample data. Replace with real NWP (e.g. IMD GFS/NCUM) + observed (IMD gridded / GPM IMERG) feeds.
const THRESHOLDS = { heavy: 64.5, veryHeavy: 115.6 }; // IMD 24h categories (mm)
const DISTRICTS = [
  { name: 'Balasore', gx: 0, gy: 0, terrain: 'coastal' }, { name: 'Cuttack', gx: 1, gy: 0, terrain: 'plains' },
  { name: 'Sundargarh', gx: 2, gy: 0, terrain: 'plains' }, { name: 'Sambalpur', gx: 3, gy: 0, terrain: 'plains' },
  { name: 'Puri', gx: 0, gy: 1, terrain: 'coastal' }, { name: 'Khordha', gx: 1, gy: 1, terrain: 'coastal' },
  { name: 'Ganjam', gx: 2, gy: 1, terrain: 'coastal' }, { name: 'Koraput', gx: 3, gy: 1, terrain: 'orographic' },
];
const feat = (h, c, w, m, z) => ({ humidityPct: h, capeJkg: c, wind850ms: w, mslpAnomalyHpa: m, mczAnomalySigma: z });
// name: [rawMm, humidity, CAPE, 850hPa wind, MSLP anomaly, monsoon-core-zone anomaly]
const CURRENT = {
  Khordha: [72, 93, 1700, 21, -6.5, .5], Puri: [55, 90, 1500, 18, -5, .5], Cuttack: [48, 88, 1400, 15, -3, .8],
  Ganjam: [38, 86, 1300, 14, -2.5, .7], Koraput: [64, 89, 1200, 19, -3, .7], Sundargarh: [30, 80, 1000, 11, -1, .6],
  Balasore: [81, 94, 1900, 23, -7.5, .5], Sambalpur: [12, 66, 800, 7, 1.5, -1.0],
};
function currentCases() {
  return DISTRICTS.map(d => { const [r, ...f] = CURRENT[d.name];
    return { id: d.name, district: d.name, terrain: d.terrain, gx: d.gx, gy: d.gy, day: 0, rawMm: r, features: feat(...f) }; });
}

function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const gauss = r => Math.sqrt(-2 * Math.log(r() + 1e-9)) * Math.cos(2 * Math.PI * r());

// 5 past days x 8 districts with observations (hidden from the AI; used only to verify)
function hindcastCases() {
  const r = rng(26080), out = [];
  const scen = ['Active Monsoon', 'Monsoon Depression', 'Break Monsoon', 'Active Monsoon', 'Monsoon Depression'];
  const base = { 'Active Monsoon': [85, 1400, 14, -2, .9, 35, 1.2], 'Monsoon Depression': [92, 1800, 20, -7, .4, 60, 1.4], 'Break Monsoon': [68, 900, 8, 2, -1.1, 10, .65] };
  scen.forEach((reg, day) => DISTRICTS.forEach(d => {
    const [h, c, w, m, z, rain, bias] = base[reg], tf = d.terrain === 'coastal' ? 1.2 : d.terrain === 'orographic' ? 1.3 : 1;
    const raw = Math.max(0, rain * tf * Math.exp(.4 * gauss(r)));
    const obs = Math.max(0, raw * bias * (d.terrain === 'orographic' ? 1.15 : 1) * Math.exp(.3 * gauss(r)));
    out.push({ id: `${d.name}-d${day + 1}`, district: d.name, terrain: d.terrain, gx: d.gx, gy: d.gy, day: day + 1,
      rawMm: +raw.toFixed(1), observedMm: +obs.toFixed(1), trueRegime: reg,
      features: feat(Math.round(h + 3 * gauss(r)), Math.round(c + 120 * gauss(r)), +(w + 1.5 * gauss(r)).toFixed(1), +(m + gauss(r)).toFixed(1), +(z + .2 * gauss(r)).toFixed(2)) });
  }));
  return out;
}
const promptView = c => ({ id: c.id, district: c.district, terrain: c.terrain, rawMm: c.rawMm, features: c.features }); // no truth leakage
module.exports = { THRESHOLDS, DISTRICTS, currentCases, hindcastCases, promptView };
