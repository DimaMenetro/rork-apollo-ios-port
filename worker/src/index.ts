/**
 * Apollo Engine — Cloudflare Worker entry point.
 *
 * Hosts the four ported Base44 functions:
 *   POST /api/invokeLLM               — generic LLM bridge through Rork AI proxy
 *   POST /api/generateEsotericProfile — CP-012 esoteric profile (Gemini 3 Flash, 4 staggered prompts)
 *   POST /api/synthesizeDossier       — MELLMA unified dossier (Claude Sonnet 4.6, two parallel calls)
 *   POST /api/analyzeAudio            — Hume prosody + AssemblyAI universal-3-pro
 *   POST /api/exportDSP               — jsPDF export, dark + light themes
 *   POST /api/presignUpload           — R2 presigned PUT URL
 *   PUT  /api/upload                  — relay PUT to R2 (token-validated)
 *   GET  /api/evidence/:key           — read-back for uploaded evidence
 */
import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Env } from "./types";
import { invokeLLMHandler } from "./handlers/invokeLLM";
import { generateEsotericProfile } from "./handlers/generateEsotericProfile";
import { synthesizeDossier } from "./handlers/synthesizeDossier";
import { analyzeAudio } from "./handlers/analyzeAudio";
import { exportDSP } from "./handlers/exportDSP";
import { presignUpload, uploadRelay, serveEvidence } from "./handlers/presignUpload";

const app = new Hono<{ Bindings: Env }>();

app.use("*", cors({ origin: "*", allowMethods: ["GET", "POST", "PUT", "OPTIONS"] }));

// Optional shared-secret guard. If APOLLO_SHARED_SECRET is set, every /api/* call
// must include the matching X-Apollo-Secret header.
app.use("/api/*", async (c, next) => {
  const requiredSecret = c.env.APOLLO_SHARED_SECRET;
  if (requiredSecret) {
    // Upload and evidence relays go through query-token signing, not header secret.
    const path = new URL(c.req.url).pathname;
    if (!path.startsWith("/api/upload") && !path.startsWith("/api/evidence")) {
      if (c.req.header("X-Apollo-Secret") !== requiredSecret) {
        return c.json({ error: "Unauthorized" }, 401);
      }
    }
  }
  await next();
});

app.get("/", (c) => c.text("Apollo Engine Worker — see /worker/README.md"));
app.get("/health", (c) => c.json({ ok: true, ts: Date.now() }));

app.post("/api/invokeLLM", invokeLLMHandler);
app.post("/api/generateEsotericProfile", generateEsotericProfile);
app.post("/api/synthesizeDossier", synthesizeDossier);
app.post("/api/analyzeAudio", analyzeAudio);
app.post("/api/exportDSP", exportDSP);
app.post("/api/presignUpload", presignUpload);
app.put("/api/upload", uploadRelay);
app.get("/api/evidence/:key", serveEvidence);

export default app;
