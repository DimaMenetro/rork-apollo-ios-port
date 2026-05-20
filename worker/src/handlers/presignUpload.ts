/**
 * R2 presigned upload bridge.
 *
 * The Worker doesn't proxy the entire upload — instead it returns a short-lived
 * PUT URL and a public read URL. The iOS client PUTs the file directly to R2
 * and passes the public URL to /api/analyzeAudio.
 *
 * Because Cloudflare Workers don't yet expose S3-style presigning natively, we
 * mint a Worker-signed token (HMAC over filename + expiry) and accept the PUT
 * back through this same Worker at /api/upload/:token. The client doesn't care
 * about the mechanism — it just PUTs to `uploadURL`.
 */
import { Context } from "hono";
import type { Env } from "../types";

const TTL_MS = 10 * 60 * 1000; // 10 minutes

async function hmac(secret: string, data: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(data));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function sanitize(name: string): string {
  return name.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120);
}

export async function presignUpload(c: Context<{ Bindings: Env }>) {
  let body: { filename?: string; content_type?: string };
  try {
    body = (await c.req.json()) as { filename?: string; content_type?: string };
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const filename = sanitize(body.filename ?? "");
  const contentType = body.content_type ?? "application/octet-stream";
  if (!filename) return c.json({ error: "filename required" }, 400);

  const secret = c.env.APOLLO_SHARED_SECRET ?? c.env.RORK_TOOLKIT_SECRET_KEY ?? "apollo-fallback-secret";
  const key = `${Date.now()}-${crypto.randomUUID()}-${filename}`;
  const expiry = Date.now() + TTL_MS;
  const token = await hmac(secret, `${key}:${expiry}:${contentType}`);

  const origin = new URL(c.req.url).origin;
  const uploadURL = `${origin}/api/upload?key=${encodeURIComponent(key)}&exp=${expiry}&ct=${encodeURIComponent(contentType)}&token=${token}`;
  const publicURL = c.env.R2_PUBLIC_BASE
    ? `${c.env.R2_PUBLIC_BASE.replace(/\/+$/, "")}/${key}`
    : `${origin}/api/evidence/${encodeURIComponent(key)}`;

  return c.json({ uploadURL, publicURL, key });
}

export async function uploadRelay(c: Context<{ Bindings: Env }>) {
  const url = new URL(c.req.url);
  const key = url.searchParams.get("key");
  const exp = parseInt(url.searchParams.get("exp") ?? "0", 10);
  const ct = url.searchParams.get("ct") ?? "application/octet-stream";
  const token = url.searchParams.get("token") ?? "";
  if (!key || !exp || !token) return c.json({ error: "missing params" }, 400);
  if (Date.now() > exp) return c.json({ error: "upload URL expired" }, 410);

  const secret = c.env.APOLLO_SHARED_SECRET ?? c.env.RORK_TOOLKIT_SECRET_KEY ?? "apollo-fallback-secret";
  const expected = await hmac(secret, `${key}:${exp}:${ct}`);
  if (expected !== token) return c.json({ error: "invalid token" }, 403);

  await c.env.EVIDENCE.put(key, c.req.raw.body, { httpMetadata: { contentType: ct } });
  return c.json({ ok: true, key });
}

export async function serveEvidence(c: Context<{ Bindings: Env }>) {
  const key = c.req.param("key");
  if (!key) return c.text("missing key", 400);
  const obj = await c.env.EVIDENCE.get(key);
  if (!obj) return c.text("not found", 404);
  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set("Cache-Control", "private, max-age=3600");
  return new Response(obj.body, { headers });
}
