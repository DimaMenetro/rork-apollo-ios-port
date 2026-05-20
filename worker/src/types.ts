/**
 * Shared Worker bindings + secrets.
 */
export interface Env {
  EVIDENCE: R2Bucket;
  HUME_API_KEY: string;
  ASSEMBLYAI_API_KEY: string;
  RORK_TOOLKIT_SECRET_KEY: string;
  APOLLO_SHARED_SECRET?: string;
  RORK_AI_PROXY_URL: string;
  R2_PUBLIC_BASE?: string;
}
