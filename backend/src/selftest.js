// Offline self-test (no API key needed): runs fallback pipeline + verification math.
const { hindcastCases } = require('./data'); const { processCases } = require('./pipeline'); const { verify } = require('./verify');
(async () => {
  const cases = hindcastCases(), res = await processCases(cases);
  const v = verify(cases.map((c, i) => ({ c, res: res[i] })), 64.5);
  console.table(v.metrics); console.log('classifier', v.classifier, 'brier', v.brier, 'sample', v.sample);
})();
