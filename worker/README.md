# Apollo Engine — Cloudflare Worker

The only server-side piece. Preserves the **exact** Base44 function logic — same models, same prompts, same outputs — so the iOS app receives byte-for-byte equivalent results.

## Endpoints

| Path | Function | Implementation |
|------|----------|----------------|
| `POST /api/invokeLLM`              | Generic LLM call (used by Processing + Review DSP synthesis) | Forwards to Rork AI proxy. Default model `claude-sonnet-4.6`. |
| `POST /api/generateEsotericProfile`| CP-012 esoteric profile                                      | Same 4 staggered prompts (Phase I–II, III–IV, V–VII, VIII), same pre-computed Personal Year math, Gemini 3 Flash. Port of `base44/functions/generateEsotericProfile/entry.ts` line-for-line. |
| `POST /api/synthesizeDossier`      | MELLMA unified dossier                                       | Same two parallel Claude Sonnet 4.6 calls (narrative sections + convergence map). Port of `base44/functions/synthesizeDossier/entry.ts`. |
| `POST /api/analyzeAudio`           | Hume prosody + AssemblyAI universal-3-pro                    | Same polling loops and Promise.allSettled fan-out. Port of `base44/functions/analyzeAudio/entry.ts`. |
| `POST /api/exportDSP`              | PDF export                                                   | Same jsPDF layout (cover, confidence arc, personality bars, predictive model, ESP sections, SME validation, footer) in light + dark themes. Port of `base44/functions/exportDSP/entry.ts`. |
| `POST /api/presignUpload`          | R2 presigned upload URL                                      | Returns `{ uploadURL, publicURL }` for the iOS client to PUT a voice memo / video before passing the public URL to `/api/analyzeAudio`. |

## Required secrets

```
HUME_API_KEY            # from hume.ai dashboard
ASSEMBLYAI_API_KEY      # from assemblyai.com dashboard
RORK_TOOLKIT_SECRET_KEY # same value as EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
R2_BUCKET               # bound R2 bucket for evidence files
```

## Why a Worker

Hume and AssemblyAI keys cannot ship in the iOS bundle. The Worker holds them, exposes the same endpoint shape Base44 exposed, and proxies LLM calls through Rork's AI proxy so model selection and prompts stay identical.

## Deploying

1. `cd worker && npm install`
2. `wrangler secret put HUME_API_KEY` (repeat for each secret)
3. `wrangler r2 bucket create apollo-evidence` and bind as `R2_BUCKET` in `wrangler.toml`
4. `wrangler deploy`
5. Copy the deployed URL into `ios/ApolloEngine/Services/ApolloConfig.swift` (`workerURL`)

## Source-of-truth files to port

The Worker is a direct TypeScript port of these four files — copy them verbatim into the corresponding `src/handlers/*.ts`:

- `base44/functions/generateEsotericProfile/entry.ts`
- `base44/functions/synthesizeDossier/entry.ts`
- `base44/functions/analyzeAudio/entry.ts`
- `base44/functions/exportDSP/entry.ts`

Only the imports change:
- `createClientFromRequest` → drop (Worker uses the Rork proxy directly)
- `base44.asServiceRole.integrations.Core.InvokeLLM` → `fetch(RORK_AI_PROXY_URL, ...)`
- `base44.asServiceRole.entities.Subject.update` → drop (iOS persists locally + CloudKit)

Everything else — every prompt, every schema, every polling interval — stays identical.
