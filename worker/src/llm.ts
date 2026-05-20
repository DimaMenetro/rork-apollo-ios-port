/**
 * Centralized Rork AI proxy bridge.
 * Mirrors the Base44 `Core.InvokeLLM` API surface: { model, prompt, response_json_schema, file_urls }.
 *
 * The Rork proxy currently accepts a messages array, so we adapt the prompt-style call
 * into a single user message. JSON schema constraints are encoded into the system instruction.
 */
import type { Env } from "./types";

export interface InvokeLLMArgs {
  model?: string;
  prompt: string;
  response_json_schema?: Record<string, unknown>;
  file_urls?: string[];
}

export interface InvokeLLMResult<T = Record<string, unknown>> {
  response: T;
  raw: string;
}

const MODEL_ALIASES: Record<string, string> = {
  gemini_3_flash: "google/gemini-2.5-flash",
  claude_sonnet_4_6: "anthropic/claude-sonnet-4",
};

export async function invokeLLM<T = Record<string, unknown>>(
  env: Env,
  args: InvokeLLMArgs,
): Promise<InvokeLLMResult<T>> {
  const modelName = MODEL_ALIASES[args.model ?? ""] ?? args.model ?? "anthropic/claude-sonnet-4";

  const schemaText = args.response_json_schema
    ? `\n\nReturn ONLY valid JSON matching this schema (no markdown fences):\n${JSON.stringify(args.response_json_schema)}`
    : "";

  const content: Array<{ type: string; text?: string; image?: string }> = [
    { type: "text", text: `${args.prompt}${schemaText}` },
  ];
  for (const url of args.file_urls ?? []) {
    content.push({ type: "image", image: url });
  }

  const body = {
    messages: [
      {
        role: "system",
        content:
          "You are the Apollo analysis engine. When a JSON schema is supplied, respond with strict JSON only — no prose, no fences.",
      },
      { role: "user", content },
    ],
    model: modelName,
  };

  const res = await fetch(env.RORK_AI_PROXY_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.RORK_TOOLKIT_SECRET_KEY}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`LLM proxy ${res.status}: ${await res.text()}`);
  }
  const data = (await res.json()) as { completion?: string; content?: string };
  const raw = (data.completion ?? data.content ?? "").trim();
  const cleaned = raw.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "");
  let parsed: T;
  try {
    parsed = JSON.parse(cleaned) as T;
  } catch {
    // Fallback: try to extract the first JSON object in the response.
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error(`LLM did not return JSON. First 200 chars: ${cleaned.slice(0, 200)}`);
    }
    parsed = JSON.parse(match[0]) as T;
  }
  return { response: parsed, raw };
}
