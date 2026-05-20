# Apollo Engine — Cloudflare Worker

The only server-side piece. Preserves the **exact** Base44 function logic — same models, same prompts, same outputs — so the iOS app receives byte-for-byte equivalent results.

## Endpoints

| Path | Function | Implementation |
|------|----------|----------------|
| `POST /api/invokeLLM`              | Generic LLM call (Processing + DSP synthesis) | Routed through Rork AI proxy. Default model `anthropic/claude-sonnet-4`. |
| `POST /api/generateEsotericProfile`| CP-012 esoteric profile                       | Same 4 staggered prompts (Phase I–II, III–IV, V–VII, VIII), same pre-computed Personal Year math, Gemini 3 Flash. |
| `POST /api/synthesizeDossier`      | MELLMA unified dossier                        | Same two parallel Claude Sonnet 4.6 calls (narrative sections + convergence map). |
| `POST /api/analyzeAudio`           | Hume prosody + AssemblyAI universal-3-pro     | Same `Promise.allSettled` fan-out, same polling intervals. |
| `POST /api/exportDSP`              | PDF export                                    | Same jsPDF layout — cover, confidence arc, personality bars, predictive model, ESP sections, SME validation, footer — in dark + light themes. |
| `POST /api/presignUpload`          | R2 presigned PUT URL                          | HMAC-signed token, 10-minute TTL. |
| `PUT  /api/upload`                 | Relayed upload to R2                          | Token-validated, content-type preserved. |
| `GET  /api/evidence/:key`          | Read-back for uploaded evidence               | Used when no public R2 base URL is configured. |

## Required secrets

```bash
wrangler secret put HUME_API_KEY
wrangler secret put ASSEMBLYAI_API_KEY
wrangler secret put RORK_TOOLKIT_SECRET_KEY     # same value as EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
wrangler secret put APOLLO_SHARED_SECRET        # optional — enforces X-Apollo-Secret header on /api/*
```

R2 bucket:

```bash
wrangler r2 bucket create apollo-evidence
```

Optional public read-back (saves bandwidth via Cloudflare's edge):

```bash
wrangler r2 bucket dev-url enable apollo-evidence
# then set R2_PUBLIC_BASE in wrangler.toml [vars]
```

## Deploying

```bash
cd worker
npm install
npm run deploy
```

Then copy the deployed URL into `ios/ApolloEngine/Services/ApolloConfig.swift` (`workerURL`) and, if you set `APOLLO_SHARED_SECRET`, into `ApolloConfig.workerSecret`.

## Why a Worker

Hume and AssemblyAI keys cannot ship in the iOS bundle. The Worker holds them, exposes the same endpoint shape Base44 exposed, and proxies LLM calls through Rork's AI proxy so model selection and prompts stay identical to the original Base44 functions.
