/**
 * Generic InvokeLLM bridge — used by iOS Processing + Review DSP synthesis.
 * Mirrors the Base44 `Core.InvokeLLM` API surface.
 */
import { Context } from "hono";
import type { Env } from "../types";
import { invokeLLM } from "../llm";

interface RequestBody {
  prompt: string;
  response_json_schema?: Record<string, unknown>;
  file_urls?: string[];
  model?: string;
}

export async function invokeLLMHandler(c: Context<{ Bindings: Env }>) {
  let body: RequestBody;
  try {
    body = (await c.req.json()) as RequestBody;
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  if (!body.prompt) return c.json({ error: "prompt required" }, 400);

  try {
    const result = await invokeLLM(c.env, {
      model: body.model,
      prompt: body.prompt,
      response_json_schema: body.response_json_schema,
      file_urls: body.file_urls,
    });
    return c.json({ response: result.response });
  } catch (e: any) {
    return c.json({ error: e?.message ?? "LLM call failed" }, 500);
  }
}
