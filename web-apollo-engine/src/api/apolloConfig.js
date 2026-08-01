/**
 * Apollo Engine — web runtime configuration.
 *
 * The web app talks to the same Rork AI proxy the iOS app + Worker use for LLM
 * calls, runs PDF export and esoteric generation client-side, and only needs the
 * Cloudflare Worker for audio/video analysis (Hume + AssemblyAI hold private keys).
 */

const env = import.meta.env ?? {};

/** Rork AI proxy (public toolkit). Used directly for all LLM calls. */
const TOOLKIT_URL = (env.EXPO_PUBLIC_TOOLKIT_URL || 'https://toolkit.rork.com').replace(/\/+$/, '');
export const RORK_LLM_URL = `${TOOLKIT_URL}/text/llm/`;
export const RORK_TOOLKIT_SECRET_KEY = env.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY || '';

/**
 * Apollo Worker URL — only required for audio/video analysis (Hume + AssemblyAI)
 * and presigned R2 uploads. Set VITE_APOLLO_WORKER_URL to your deployed Worker.
 * Leave empty to run fully client-side (audio analysis will be disabled).
 */
export const APOLLO_WORKER_URL = (env.VITE_APOLLO_WORKER_URL || '').replace(/\/+$/, '');
export const APOLLO_WORKER_SECRET = env.VITE_APOLLO_WORKER_SECRET || '';

export const hasWorker = () => APOLLO_WORKER_URL.length > 0;
