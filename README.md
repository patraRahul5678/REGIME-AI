# 🌧️ RainRegime AI
### Regime-Aware AI Post-Processing of Monsoon Rainfall Forecasts
**Smart India Hackathon 2026 — Problem Statement 26080**

> This repository is a **Smart India Hackathon (SIH) 2026 project prototype**, built against **Problem Statement 26080**. It is a working demonstration of the required product flow, not an official government or IMD system. All forecast data shipped in this repo is **synthetic/sample data**, and the "ML model" stage is currently powered by the **Google Gemini API** as a stand-in — both of these are explained in detail below, along with exactly what a real operational deployment would need instead.

```
Raw NWP  →  Weather Regime  →  Suitable Correction  →  Heavy-Rain Probability  →  District/Grid Product  →  Verification
```

---

## Table of contents
1. [What this project is](#1-what-this-project-is)
2. [Problem statement (SIH 26080)](#2-problem-statement-sih-26080)
3. [What's real vs. what's a stand-in](#3-whats-real-vs-whats-a-stand-in)
4. [Architecture](#4-architecture)
5. [Project structure](#5-project-structure)
6. [Prerequisites](#6-prerequisites)
7. [How to use it — backend setup](#7-how-to-use-it--backend-setup)
8. [How to use it — Flutter app setup](#8-how-to-use-it--flutter-app-setup)
9. [Using the app (screen by screen)](#9-using-the-app-screen-by-screen)
10. [API reference](#10-api-reference)
11. [How the Gemini pipeline works](#11-how-the-gemini-pipeline-works)
12. [How verification is computed](#12-how-verification-is-computed)
13. [What a real operational system would use instead](#13-what-a-real-operational-system-would-use-instead)
14. [What we can do next to make it real](#14-what-we-can-do-next-to-make-it-real)
15. [Three-minute demo script](#15-three-minute-demo-script)
16. [Security checklist before any real deployment](#16-security-checklist-before-any-real-deployment)
17. [Troubleshooting](#17-troubleshooting)
18. [Limitations & honesty notes](#18-limitations--honesty-notes)
19. [Credits](#19-credits)

---

## 1. What this project is
RainRegime AI is a **Flutter mobile app** + **Node.js/Express backend** that demonstrates the complete chain required by SIH Problem Statement 26080:

1. Take a raw NWP (Numerical Weather Prediction) rainfall forecast.
2. Identify the **prevailing weather regime** (active monsoon, break monsoon, monsoon depression, coastal rainfall, orographic rainfall, western disturbance).
3. Apply a **regime-suitable correction** to the raw rainfall.
4. Estimate the **probability of heavy / very heavy rainfall**.
5. Present a **district/grid-level product** (map-style list, raw vs. corrected values).
6. **Verify** the correction against raw NWP using standard skill scores (RMSE, ETS, CSI, POD, FAR, FSS).

It also includes a full user-facing shell: splash screen, login/registration, profile management and logout — because a real forecaster-facing tool needs those too.

## 2. Problem statement (SIH 26080)
> Rainfall forecast errors over India vary with weather regimes such as active monsoon, break monsoon, monsoon lows/depressions, orographic rainfall, coastal rainfall and western disturbances. A single bias-correction method may not work equally well in all situations. The challenge is to build an AI/ML-based rainfall post-processing system that first identifies the prevailing weather regime and then applies suitable correction to the raw NWP rainfall forecast, improving district/grid-level rainfall forecasts, especially for heavy and very heavy rainfall events.

**Expected outcomes** (all implemented in this prototype, with the caveats in section 3):
| Expected outcome | Where it is in this repo |
|---|---|
| Weather regime classifier | `backend/src/pipeline.js` (Gemini prompt + schema) |
| Bias-corrected rainfall forecast | Same pipeline, `correctedMm` field |
| Heavy rainfall probability | Same pipeline, `heavyProb` / `veryHeavyProb` fields |
| District-level rainfall product | Flutter **Districts** tab |
| Verification report (RMSE/ETS/CSI/POD/FAR/FSS) | `backend/src/verify.js` + Flutter **Verification** tab |

## 3. What's real vs. what's a stand-in
Be precise about this — it matters for judging and for anyone building on top of this repo.

### ✅ Fully real / fully working
- Flutter UI (all screens, navigation, animations)
- Node.js/Express backend (routing, JWT auth, caching)
- Verification math — RMSE, ETS, CSI, POD, FAR, FSS, Brier score, reliability bins are all computed with the real formulas (see §12), not hard-coded numbers
- The end-to-end **flow/wiring**: regime → correction → probability → product → verification is genuinely connected, not mocked in the UI

### 🔶 Stand-ins (clearly not the final, operational version)
| Slot | What we use right now | What it should be in a real system |
|---|---|---|
| **The ML model** (regime classifier + bias-correction model) | **Google Gemini API**, prompted to classify the regime and correct the rainfall number, constrained by a JSON schema and sanity clamps | A **trained, validated statistical/ML model** — see §13 |
| **Raw NWP rainfall input** | Synthetic numbers generated in `backend/src/data.js` (`currentCases()`) | Real NWP model output (IMD NCUM/GFS, ECMWF IFS, WRF) |
| **Atmospheric features** (humidity, CAPE, 850 hPa wind, MSLP anomaly, monsoon-core-zone anomaly) | Synthetic, hand-picked to look plausible per regime | Extracted from the same NWP run, or ERA5 reanalysis |
| **Observed rainfall** (used only for verification) | Synthetic, generated with a fixed random seed to *loosely* resemble real bias patterns | IMD gridded rain-gauge data, or satellite estimates like GPM IMERG |
| **District/grid geography** | 8 fictional Odisha districts on a tiny 4×2 toy grid | A real shapefile/PostGIS mapping of India's districts to the NWP grid |
| **"True regime" labels** (only used in the internal hindcast to sanity-check the classifier) | Synthetic, assigned when generating the fake data | Not available in real time at all — real systems evaluate a classifier against historical IMD monsoon-phase bulletins, not per-case ground truth |

**In short: Gemini is doing the job a trained ML model would do, and `data.js` is doing the job a live NWP/observation data pipeline would do.** Nothing about the UI, backend routing, auth or verification math needs to change when you swap either of these out — only `backend/src/data.js` (data) and optionally `backend/src/pipeline.js` (model) need to be replaced.

## 4. Architecture
```
┌────────────────┐  HTTPS/JSON + JWT   ┌───────────────────────────────────────────┐
│ Flutter app    │ ──────────────────▶ │ Node.js + Express (server.js)             │
│ (lib/screens)  │ ◀────────────────── │  auth · routes · TTL cache (service.js)   │
└────────────────┘                     │        │                                  │
                                        │  pipeline.js ──▶ gemini.js ──▶ Gemini API │
                                        │   • regime classification (JSON schema)   │
                                        │   • regime-conditioned rainfall correction │
                                        │   • P(>64.5 mm), P(>115.6 mm)              │
                                        │   • sanity clamps + rule-based fallback    │
                                        │  verify.js   (RMSE/ETS/CSI/POD/FAR/FSS)    │
                                        │  data.js     (⚠ synthetic NWP + hindcast)  │
                                        └───────────────────────────────────────────┘
```

## 5. Project structure
```
rainregime/
├── README.md                 ← you are here
├── backend/
│   ├── server.js             # Express app: auth + forecast + verification routes
│   ├── package.json
│   ├── .env.example          # copy to .env and fill in
│   └── src/
│       ├── gemini.js         # Gemini REST client (retry, timeout, JSON parsing)
│       ├── pipeline.js       # prompts, schema, sanitising, rule-based fallback, explanations
│       ├── verify.js         # verification metrics (real formulas)
│       ├── service.js        # orchestration + TTL cache
│       ├── data.js           # ⚠ SYNTHETIC sample data, thresholds, districts — replace for production
│       └── selftest.js       # offline test, no API key needed
└── app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart · api.dart · theme.dart
        └── screens/
            ├── splash.dart   # animated splash + auto-login check
            ├── login.dart    # login / register
            └── home.dart     # Overview, Districts, Verification, Profile tabs
```

## 6. Prerequisites
- **Node.js 18+** (20 LTS recommended) — https://nodejs.org — needed for the built-in `fetch` used to call Gemini
- **Flutter 3.27+ / Dart 3+** — https://docs.flutter.dev/get-started/install — run `flutter doctor` and make sure it passes
- **A Gemini API key** (free tier available) — https://aistudio.google.com/apikey
- Android Studio emulator, iOS simulator, or a physical phone with the Flutter app installed
- (Optional) `curl` and Python 3 for the API testing examples below

## 7. How to use it — backend setup
```bash
cd backend
npm install
cp .env.example .env          # Windows PowerShell: copy .env.example .env
# open .env and set JWT_SECRET and GEMINI_API_KEY
npm start
```
You should see:
```
RainRegime API on :4000 | Gemini ON
```
If you don't set `GEMINI_API_KEY`, you'll instead see `Gemini OFF (rule-based fallback)` — the app still works end-to-end, just with the simpler rule-based logic instead of Gemini (see §11).

**Quick checks:**
```bash
npm run selftest                              # offline: runs the fallback pipeline + verification math, no key needed
curl localhost:4000/api/health                # {"ok":true,"gemini":true,"model":"gemini-2.5-flash"}
```

**Environment variables** (`backend/.env`):
| Variable | Default | Purpose |
|---|---|---|
| `PORT` | 4000 | API port |
| `JWT_SECRET` | insecure dev value | **Must be changed to a long random string for any real deployment** |
| `GEMINI_API_KEY` | — | Enables Gemini. Leave empty to run on the rule-based fallback only |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Any Gemini model supporting structured/JSON output (e.g. `gemini-2.5-pro` for higher quality, at higher latency/cost) |
| `CACHE_TTL_MIN` | 60 | Minutes AI results are cached, to save API quota and speed up repeat loads |

## 8. How to use it — Flutter app setup
```bash
cd app
flutter create .        # generates android/ios/web/etc. folders — keeps your lib/ and pubspec.yaml untouched
flutter pub get
flutter run
```
**Point the app at your backend** — the `base` URL in `app/lib/api.dart` defaults to `localhost:4000` (works for Chrome/web and iOS simulator). Override it per platform using `--dart-define`:

| Where the app runs | Command |
|---|---|
| Chrome / web | `flutter run -d chrome` (no flag needed — defaults to `localhost:4000`) |
| iOS simulator | `flutter run -d ios` (no flag needed) |
| Android emulator | `flutter run -d emulator --dart-define=API_BASE=http://10.0.2.2:4000/api` |
| Real phone (same Wi-Fi) | `flutter run --dart-define=API_BASE=http://<your-PC-LAN-IP>:4000/api` — allow port 4000 through your firewall |

If you run on a real **Android** device over plain `http`, add `android:usesCleartextTraffic="true"` to the `<application>` tag in `android/app/src/main/AndroidManifest.xml` (generated by `flutter create .`), and confirm `<uses-permission android:name="android.permission.INTERNET"/>` is present (it's included by default in debug builds).

**Demo login:** `forecaster@rain.ai` / `rain1234` — or tap "New here? Create account" to register your own user.

## 9. Using the app (screen by screen)
1. **Splash** — animated rain background while the app checks whether you're already logged in (saved JWT token).
2. **Login / Register** — sign in with the demo account, or register a new one with name, email, password, role and organization.
3. **Overview tab** — the headline heavy-rain risk line, the dominant regime for the current cycle with its confidence, the number of high-risk districts, and which engine produced the numbers (`Gemini AI` or `Rule-based`).
4. **Districts tab** — search and filter districts; each card shows the regime, a probability ring for heavy rain, and raw mm → corrected mm with a +/- change badge. **Tap any district** to open a bottom sheet with a Gemini-written explanation: a summary, key drivers, caveats, and a suggested action.
5. **Verification tab** — average skill improvement banner, then each metric (RMSE, ETS, CSI, POD, FAR, FSS) shown as raw-vs-corrected bars with a percentage change badge.
6. **Profile tab** — edit your name, role and organization, and **Log out** (with a confirmation dialog) — this clears the saved token and returns you to the login screen.

Pull down on any data screen to refresh; the backend serves cached AI results within `CACHE_TTL_MIN` minutes, so a refresh is usually instant unless the cache has expired or you call `POST /api/forecast/refresh`.

## 10. API reference
All routes except `/api/health`, `/api/auth/login` and `/api/auth/register` require `Authorization: Bearer <token>`.

| Method | Route | Description |
|---|---|---|
| GET | `/api/health` | Server status + whether Gemini is configured |
| POST | `/api/auth/register` | `{name,email,password,role?,organization?}` → `{token,user}` |
| POST | `/api/auth/login` | `{email,password}` → `{token,user}` |
| GET / PUT | `/api/auth/me` | Get / update profile (`name`, `role`, `organization`) |
| POST | `/api/auth/logout` | Client discards the token |
| GET | `/api/forecast/summary` | Headline risk, dominant regime, high-risk count, model version, data source |
| GET | `/api/forecast/districts` | Per district: regime, confidence, rawMm, correctedMm, heavyProb, veryHeavyProb, source, rationale |
| GET | `/api/forecast/explain/:district` | Gemini explanation `{summary, drivers[], caveats[], action, source}` |
| POST | `/api/forecast/refresh` | Clears the AI cache; next request recomputes |
| GET | `/api/verification` | Raw vs corrected metrics, regime-wise RMSE, Brier score, reliability bins, classifier accuracy |

Example:
```bash
TOKEN=$(curl -s -X POST localhost:4000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"forecaster@rain.ai","password":"rain1234"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -H "Authorization: Bearer $TOKEN" localhost:4000/api/forecast/districts
```

## 11. How the Gemini pipeline works
1. **Input per district** — 24h raw NWP rainfall (mm) plus features: humidity %, CAPE (J/kg), 850 hPa wind (m/s), MSLP anomaly (hPa), monsoon-core-zone anomaly (σ), and terrain type. Example sent to Gemini:
   ```json
   {"id":"Khordha","district":"Khordha","terrain":"coastal","rawMm":72,
    "features":{"humidityPct":93,"capeJkg":1700,"wind850ms":21,"mslpAnomalyHpa":-6.5,"mczAnomalySigma":0.5}}
   ```
2. **System prompt** — defines the allowed regimes (Active Monsoon, Break Monsoon, Monsoon Depression, Coastal Rainfall, Orographic Rainfall, Western Disturbance, Unclassified), known NWP error tendencies per regime, the operational thresholds (IMD heavy ≥ 64.5 mm, very heavy ≥ 115.6 mm), and the output rules.
3. **Structured JSON output**, enforced by a response schema, e.g.:
   ```json
   {"id":"Khordha","regime":"Monsoon Depression","confidence":0.87,"correctedMm":94.5,
    "heavyProb":0.71,"veryHeavyProb":0.22,"rationale":"Strong MSLP anomaly and high humidity..."}
   ```
4. **Sanity clamps (safety net)** — every Gemini response is validated: regime must be one of the allowed values; corrected rainfall is clamped to roughly 0.3×–3× the raw value (an over-correction guard); `veryHeavyProb ≤ heavyProb`; all probabilities clamped to [0,1].
5. **Rule-based fallback** — if Gemini has no key, errors, times out, or hits quota, a deterministic rule-based function (`fallbackOne()` in `pipeline.js`) produces a result instead, so the app never breaks. Every result carries a `source: "gemini"` or `source: "fallback"` tag, shown in the UI.
6. **Caching** — results are cached for `CACHE_TTL_MIN` minutes and the cache is warmed when the server starts, to keep the app responsive and save API quota.
7. **Explainability** — `GET /api/forecast/explain/:district` makes a second, separate Gemini call asking for a short, cautious, forecaster-facing explanation (summary/drivers/caveats/action) for that specific district's result.

Gemini is not analyzing satellite imagery or running physical equations — it is pattern-matching the numeric features you send it against general meteorological knowledge from its training data, following the rules given in the prompt. Its output quality is therefore bounded by prompt quality and by what a general-purpose LLM can reasonably infer from six numbers — see §13 for why this differs from a real trained model.

## 12. How verification is computed
- A **hindcast set** of 5 synthetic days × 8 districts = 40 cases is generated with fake-but-structured "observed" rainfall (`hindcastCases()` in `data.js`).
- **Gemini never sees the observed values or the "true regime"** — only the same raw NWP + features it would get in real use. This avoids leaking the answer into the AI's evaluation.
- The **same sample, same threshold (64.5 mm), same spatial domain** is used for both raw and corrected scores, as required for a fair comparison.
- **Formulas used** (H = hits, FA = false alarms, M = misses, N = total cases):
  - `RMSE = √( mean( (Forecast − Observed)² ) )` — lower is better
  - `POD = H / (H + M)` — probability of detection
  - `FAR = FA / (H + FA)` — false alarm ratio, lower is better
  - `CSI = H / (H + FA + M)` — critical success index
  - `ETS = (H − Hr) / (H + FA + M − Hr)`, where `Hr = (H+FA)(H+M) / N` — equitable threat score
  - `FSS = 1 − Σ(Pf−Po)² / Σ(Pf² + Po²)` — fractions skill score, computed over 3×3 grid-cell neighbourhoods on the toy 4×2 grid
  - Also reported: **Brier score** (probability calibration), a 5-bin **reliability table** (forecast probability vs. observed frequency), **regime-wise RMSE**, and overall **classifier accuracy**.
- **Honesty note**: with only 40 cases and ~17 observed heavy-rain events, individual metrics can be noisy or even move the "wrong" way for a given run (e.g. FAR rising from 0). The app shows whatever the formulas produce rather than curating the numbers.

## 13. What a real operational system would use instead
This is the core question: **what changes if this were built for actual IMD/state-government operational use?**

### 13.1 In place of Gemini — a trained, validated ML pipeline
| Stage | Recommended real-world approach |
|---|---|
| Regime classification | A supervised classifier (Random Forest / Gradient Boosting / small neural net) trained on historical labeled monsoon-phase data (IMD active/break bulletins, depression tracks from IMD/RSMC New Delhi, western disturbance records), using NWP + reanalysis features as input |
| Bias correction | Regime-conditioned statistical post-processing: quantile mapping / quantile regression forests per regime, or a spatially-aware model (CNN / U-Net) trained on paired NWP-vs-observed rainfall fields, so corrections respect spatial coherence between neighbouring grid cells |
| Heavy-rainfall probability | A calibrated probabilistic model (ensemble NWP spread, logistic/quantile regression, or a properly calibrated neural network with isotonic/Platt calibration) rather than an LLM's self-reported probability |
| Where Gemini/LLMs *do* still add value | Generating natural-language explanations of a trained model's output for forecasters (as `explain()` does here), orchestration, anomaly summarization, and report drafting — **not** as the core numerical prediction engine |

Gemini's current role is a reasonable **prototype stand-in** because it can approximate the required behavior end-to-end for a demo without months of model training — but it has no guarantee of spatial/temporal physical consistency, can't learn from your specific historical bias patterns the way a trained model can, and its outputs can vary run to run.

### 13.2 In place of synthetic data — real data feeds
| Slot in `data.js` | Real-world replacement |
|---|---|
| `rawMm` (raw NWP rainfall) | Actual NWP output — e.g. IMD's **NCUM/GFS**, **ECMWF IFS**, or a regional **WRF** run — pulled as GRIB2/NetCDF files or via an API, aggregated to 24h totals per grid cell |
| `features` (humidity, CAPE, 850 hPa wind, MSLP anomaly, monsoon-core-zone anomaly) | Extracted from the same NWP run's other output fields, or from **ERA5** reanalysis, at each grid point and valid time |
| `observedMm` (used only for verification) | Real observed rainfall — **IMD's gridded rain-gauge dataset**, or satellite-based estimates like **GPM IMERG** |
| `DISTRICTS` (grid ↔ district mapping) | A real **shapefile/PostGIS** mapping of India's district boundaries onto the NWP model's lat/lon grid, so grid cells can be aggregated to district-level statistics correctly |
| `trueRegime` | Not available in real time at all — a real system doesn't get "ground truth regime" per case; classifiers are instead validated offline against historical IMD monsoon-phase bulletins |

### 13.3 In place of the in-memory user store
Replace the array in `server.js` with **PostgreSQL** (or another proper database), add password policies, refresh tokens, rate limiting (`express-rate-limit`), and audit logging of who accessed which forecast when.

## 14. What we can do next to make it real
Roughly in priority order:
1. **Swap in real NWP + observation feeds** (§13.2) — this alone makes every downstream number meaningful.
2. **Train and validate real ML models** for regime classification and bias correction (§13.1), keeping Gemini only for explanation/orchestration.
3. **Add a real district/grid map** (MapLibre or Leaflet) instead of the current list-based Districts tab.
4. **Move users and forecast history to PostgreSQL/PostGIS**, with proper migrations.
5. **Add role-based access control** (Meteorologist / Analyst / Disaster-Management / Model Developer / Reviewer / Administrator, as outlined in the original concept book).
6. **Add push notifications/alerts** for districts crossing heavy-rain thresholds.
7. **Add a time-series view** (forecast vs. observed rainfall over time) and **multi-model blending** across NWP sources.
8. **Add model-version tracking and an audit trail** for every forecast run, for governance and reproducibility.
9. **Load-test and secure the API** (HTTPS, hardened CORS, `helmet`, secrets management) before any real deployment.

## 15. Three-minute demo script
| Time | Scene | What to show |
|---|---|---|
| 0:00–0:25 | Splash → login | Animated splash, sign in with the demo account |
| 0:25–0:55 | Overview | Headline risk, current regime + confidence |
| 0:55–1:25 | Districts | Raw vs. corrected rainfall, probability rings |
| 1:25–1:55 | District explanation | Tap a district → Gemini's summary/drivers/caveats/action |
| 1:55–2:25 | Verification | Raw vs. corrected RMSE/ETS/CSI/POD/FAR/FSS |
| 2:25–3:00 | Profile / wrap-up | Logout, mention model version, caching, and the rule-based fallback |

**Demo line:** *"The system first identified the weather regime, then corrected the rainfall forecast, and finally showed whether the correction improved skill — with Gemini standing in for the trained ML model in this prototype."*

## 16. Security checklist before any real deployment
- Set a strong, random `JWT_SECRET`; never commit `.env` to version control.
- Serve the API behind HTTPS only.
- Move users to PostgreSQL with a real password policy, rate limiting (`express-rate-limit`) and `helmet`.
- Restrict CORS to known origins instead of allowing all.
- Keep the Gemini API key **server-side only** — it is never shipped inside the Flutter app.
- Add audit logs and model-version tracking for every forecast run.

## 17. Troubleshooting
| Problem | Fix |
|---|---|
| App shows "Cannot reach server" | Is the backend running? Did you pass the correct `--dart-define=API_BASE=...` for your device? Same Wi-Fi/firewall? Cleartext traffic allowed on Android? |
| First load takes 10–40 seconds | Gemini is computing live; results are cached afterwards — pull down to refresh if needed |
| Source badge shows `Rule-based` instead of `Gemini AI` | Missing/invalid `GEMINI_API_KEY`, you've hit quota (HTTP 429), or `GEMINI_MODEL` is misspelled — check the backend console log |
| `fetch is not defined` error in backend | Upgrade to Node.js 18+ |
| Gemini error about schema/JSON output | Set `GEMINI_MODEL` to a model that supports structured/JSON output |
| `flutter create .` seems to do nothing | That's expected — it only adds the missing platform folders (android/ios/etc.) and won't touch your existing `lib/` or `pubspec.yaml` |
| Want fresh AI results immediately | Call `POST /api/forecast/refresh`, or restart the backend |

## 18. Limitations & honesty notes
- All forecast/observation data in this repo is **synthetic**; the skill scores shown demonstrate that the *pipeline* works, not real-world forecast accuracy.
- **Gemini is a general-purpose LLM, not a physically trained rainfall post-processor.** It is a reasonable, fast stand-in for a hackathon prototype, but a production system should use trained/validated statistical or ML models for the core numerical prediction, with an LLM layered on top only for explanation and orchestration (see §13 and §14).
- Users are stored **in memory** and are lost when the backend restarts; there is no refresh-token rotation or account recovery flow.
- This is **not an official early-warning or disaster-management system**. It does not replace, and should never be used in place of, official **IMD (India Meteorological Department)** forecasts and warnings. Always defer to official advisories. Human review is required before any operational use.

## 19. Credits
Built as a submission concept for **Smart India Hackathon 2026, Problem Statement 26080 ("Regime-Aware AI Post-Processing of Monsoon Rainfall Forecasts")**. This is a **student/hackathon prototype**, not an official SIH, government, or IMD deliverable. AI assistance (Google Gemini) was used both as the in-app rainfall post-processing stand-in and as a development aid while building this repository.