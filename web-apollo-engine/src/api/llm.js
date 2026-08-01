/**
 * Rork AI proxy bridge — client-side port of the Worker's llm.ts.
 * Mirrors the Base44 `Core.InvokeLLM` surface: { model, prompt, response_json_schema, file_urls }.
 *
 * When a JSON schema is supplied this returns the parsed object directly (matching
 * how the pages consume it). Otherwise it returns the raw completion string.
 */
import { RORK_LLM_URL, RORK_TOOLKIT_SECRET_KEY } from './apolloConfig';

const MODEL_ALIASES = {
  gemini_3_flash: 'google/gemini-2.5-flash',
  claude_sonnet_4_6: 'anthropic/claude-sonnet-4',
};

function extractJSON(raw) {
  const cleaned = raw
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const match = cleaned.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error(`LLM did not return JSON. First 200 chars: ${cleaned.slice(0, 200)}`);
    }
    return JSON.parse(match[0]);
  }
}

/**
 * @param {{ model?: string, prompt: string, response_json_schema?: object, file_urls?: string[] }} args
 * @returns {Promise<object|string>} parsed object when a schema is provided, else the raw string
 */
export async function invokeLLM(args) {
  if (!args?.prompt) throw new Error('prompt required');

  const modelName =
    MODEL_ALIASES[args.model ?? ''] ?? args.model ?? 'anthropic/claude-sonnet-4';

  const schemaText = args.response_json_schema
    ? `\n\nReturn ONLY valid JSON matching this schema (no markdown fences):\n${JSON.stringify(args.response_json_schema)}`
    : '';

  const content = [{ type: 'text', text: `${args.prompt}${schemaText}` }];
  for (const url of args.file_urls ?? []) {
    content.push({ type: 'image', image: url });
  }

  const headers = { 'Content-Type': 'application/json' };
  if (RORK_TOOLKIT_SECRET_KEY) headers.Authorization = `Bearer ${RORK_TOOLKIT_SECRET_KEY}`;

  const res = await fetch(RORK_LLM_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      model: modelName,
      messages: [
        {
          role: 'system',
          content:
            'You are the Apollo analysis engine. When a JSON schema is supplied, respond with strict JSON only — no prose, no fences.',
        },
        { role: 'user', content },
      ],
    }),
  });

  if (!res.ok) {
    throw new Error(`LLM proxy ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }

  const data = await res.json();
  const raw = (data.completion ?? data.content ?? '').trim();

  if (args.response_json_schema) return extractJSON(raw);
  return raw;
}
