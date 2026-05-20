/**
 * Media analysis — Hume multi-modal + AssemblyAI universal-3-pro transcription.
 *
 * Accepts both audio and video URLs. The Hume model bundle is selected per
 * media type so video evidence yields facial expression (FACS) data alongside
 * vocal prosody, while audio runs prosody + language + burst.
 *
 * Endpoint stays at /api/analyzeAudio for backwards compatibility with the
 * original Base44 contract; callers may pass an optional `media_type`.
 */
import { Context } from "hono";
import type { Env } from "../types";

const HUME_API_URL = "https://api.hume.ai/v0/batch/jobs";
const ASSEMBLY_API_URL = "https://api.assemblyai.com/v2";

async function pollHumeJob(env: Env, jobId: string): Promise<void> {
  const jobUrl = `${HUME_API_URL}/${jobId}`;
  let status = "IN_PROGRESS";
  let attempts = 0;
  while ((status === "IN_PROGRESS" || status === "QUEUED") && attempts < 60) {
    await new Promise((r) => setTimeout(r, 5000));
    try {
      const res = await fetch(jobUrl, { headers: { "X-Hume-Api-Key": env.HUME_API_KEY } });
      if (res.ok) {
        const data = (await res.json()) as { state: { status: string } };
        status = data.state.status;
      } else if (res.status >= 400 && res.status < 500) {
        throw new Error(`Hume polling client error: ${await res.text()}`);
      }
    } catch (e: any) {
      console.error("Hume poll error:", e?.message);
    }
    attempts++;
  }
  if (status !== "COMPLETED") throw new Error(`Hume job did not complete. Status: ${status}`);
}

async function transcribeWithAssembly(env: Env, fileUrl: string): Promise<string> {
  const submitRes = await fetch(`${ASSEMBLY_API_URL}/transcript`, {
    method: "POST",
    headers: { Authorization: env.ASSEMBLYAI_API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ audio_url: fileUrl, speech_models: ["universal-3-pro"] }),
  });
  if (!submitRes.ok) throw new Error(`AssemblyAI submit failed: ${await submitRes.text()}`);
  const { id } = (await submitRes.json()) as { id: string };

  let status = "processing";
  let result: any = null;
  let attempts = 0;
  while (status === "processing" || status === "queued") {
    if (attempts++ > 60) throw new Error("AssemblyAI transcript timed out");
    await new Promise((r) => setTimeout(r, 5000));
    const pollRes = await fetch(`${ASSEMBLY_API_URL}/transcript/${id}`, {
      headers: { Authorization: env.ASSEMBLYAI_API_KEY },
    });
    if (!pollRes.ok) throw new Error(`AssemblyAI poll failed: ${await pollRes.text()}`);
    result = await pollRes.json();
    status = result.status;
  }
  if (status === "error") throw new Error(`AssemblyAI error: ${result.error}`);
  return result.text || "";
}

function humeModelsFor(mediaType: "audio" | "video"): Record<string, unknown> {
  // Hume batch models. Video gets face (FACS) + prosody + language + burst so
  // facial/body expression lands alongside vocal emotion. Audio skips face.
  if (mediaType === "video") {
    return { face: {}, prosody: {}, language: {}, burst: {} };
  }
  return { prosody: {}, language: {}, burst: {} };
}

function inferMediaType(url: string, explicit?: string): "audio" | "video" {
  if (explicit === "video" || explicit === "audio") return explicit;
  const lower = url.toLowerCase().split("?")[0];
  if (/\.(mp4|mov|m4v|webm|avi|mkv|hevc|3gp)$/.test(lower)) return "video";
  return "audio";
}

export async function analyzeAudio(c: Context<{ Bindings: Env }>) {
  let body: { file_url?: string; media_type?: string };
  try {
    body = (await c.req.json()) as { file_url?: string; media_type?: string };
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const fileUrl = body.file_url;
  if (!fileUrl) return c.json({ error: "file_url is required" }, 400);
  const mediaType = inferMediaType(fileUrl, body.media_type);

  const env = c.env;
  if (!env.HUME_API_KEY || !env.ASSEMBLYAI_API_KEY) {
    return c.json({ error: "Audio service not configured (HUME_API_KEY / ASSEMBLYAI_API_KEY missing)" }, 500);
  }

  const [humeResult, transcript] = await Promise.allSettled([
    (async () => {
      const startRes = await fetch(HUME_API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Hume-Api-Key": env.HUME_API_KEY },
        body: JSON.stringify({ models: humeModelsFor(mediaType), urls: [fileUrl] }),
      });
      if (!startRes.ok) throw new Error(`Hume start failed: ${await startRes.text()}`);
      const { job_id } = (await startRes.json()) as { job_id: string };
      await pollHumeJob(env, job_id);
      const predRes = await fetch(`${HUME_API_URL}/${job_id}/predictions`, {
        headers: { "X-Hume-Api-Key": env.HUME_API_KEY },
      });
      if (!predRes.ok) throw new Error(`Hume predictions failed: ${await predRes.text()}`);
      return predRes.json();
    })(),
    transcribeWithAssembly(env, fileUrl),
  ]);

  if (humeResult.status === "rejected" && transcript.status === "rejected") {
    return c.json({
      error: `Both Hume and AssemblyAI failed: ${humeResult.reason?.message} / ${transcript.reason?.message}`,
    }, 500);
  }

  let humeData: any = humeResult.status === "fulfilled" ? humeResult.value : null;
  if (humeData && Array.isArray(humeData) && humeData[0]?.results?.predictions) {
    humeData = humeData[0].results;
  }
  const transcriptText = transcript.status === "fulfilled" ? transcript.value : null;

  return c.json({
    media_type: mediaType,
    predictions: humeData,
    transcript: transcriptText,
    hume_error: humeResult.status === "rejected" ? humeResult.reason?.message : null,
    transcript_error: transcript.status === "rejected" ? transcript.reason?.message : null,
  });
}
