// Minimal Gemini REST client (no SDK). Requires Node 18+ (global fetch).
const sleep = ms => new Promise(r => setTimeout(r, ms));
const configured = () => !!process.env.GEMINI_API_KEY;

async function generateJSON({ system, prompt, schema, retries = 2 }) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('GEMINI_API_KEY not set');
  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  let lastErr;
  for (let a = 0; a <= retries; a++) {
    try {
      const r = await fetch(url, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key }, signal: AbortSignal.timeout(50000),
        body: JSON.stringify({ systemInstruction: { parts: [{ text: system }] }, contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, responseMimeType: 'application/json', responseSchema: schema } }),
      });
      const j = await r.json();
      if (r.status === 429 || r.status >= 500) { lastErr = new Error(j.error?.message || `Gemini HTTP ${r.status}`); await sleep(1500 * (a + 1)); continue; }
      if (!r.ok) throw new Error(j.error?.message || `Gemini HTTP ${r.status}`);
      const text = (j.candidates?.[0]?.content?.parts || []).map(p => p.text || '').join('').replace(/^```json|```$/gm, '').trim();
      if (!text) throw new Error('Empty Gemini response (possibly blocked)');
      return JSON.parse(text);
    } catch (e) { lastErr = e; if (/GEMINI_API_KEY|API key|PERMISSION/i.test(e.message)) break; await sleep(800); }
  }
  throw lastErr;
}
module.exports = { generateJSON, configured };
