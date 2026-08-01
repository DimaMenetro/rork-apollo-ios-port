/**
 * Apollo Engine — web backend client.
 *
 * Drop-in replacement for the Base44 SDK surface the app was built against
 * (`base44.entities.Subject`, `base44.integrations.Core`, `base44.functions`,
 * `base44.auth`, `base44.appLogs`). Instead of Base44 it uses:
 *
 *   - localStorage for Subject persistence (per-browser, offline-capable)
 *   - the Rork AI proxy directly for all LLM calls (InvokeLLM)
 *   - client-side jsPDF for report export
 *   - a client-side port of the CP-012 esoteric generation orchestration
 *   - the Apollo Worker for audio/video analysis (Hume + AssemblyAI)
 */
import {
  RORK_LLM_URL,
  RORK_TOOLKIT_SECRET_KEY,
  APOLLO_WORKER_URL,
  APOLLO_WORKER_SECRET,
  hasWorker,
} from './apolloConfig';
import { invokeLLM } from './llm';
import { generateEsotericProfileLocal } from './esoteric';
import { buildDSPPdfBlob } from './pdf';

const STORAGE_KEY = 'apollo_subjects_v1';

// ─── Local Subject store ───────────────────────────────────────────────────

function readAll() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(subjects) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(subjects));
}

function newId() {
  return (
    'sub_' +
    Date.now().toString(36) +
    '_' +
    Math.random().toString(36).slice(2, 10)
  );
}

function sortBy(list, order) {
  if (!order) return list;
  const desc = order.startsWith('-');
  const field = desc ? order.slice(1) : order;
  return [...list].sort((a, b) => {
    const av = a?.[field] ?? '';
    const bv = b?.[field] ?? '';
    if (av < bv) return desc ? 1 : -1;
    if (av > bv) return desc ? -1 : 1;
    return 0;
  });
}

const SubjectEntity = {
  async list(order = '-created_date', limit = 100) {
    const all = sortBy(readAll(), order);
    return all.slice(0, limit);
  },

  async filter(query = {}, order, limit) {
    let all = readAll();
    for (const [key, value] of Object.entries(query)) {
      all = all.filter((s) => s?.[key] === value);
    }
    if (order) all = sortBy(all, order);
    if (typeof limit === 'number') all = all.slice(0, limit);
    return all;
  },

  async get(id) {
    return readAll().find((s) => s.id === id) ?? null;
  },

  async create(data = {}) {
    const now = new Date().toISOString();
    const subject = {
      id: newId(),
      status: 'intake',
      created_date: now,
      updated_date: now,
      stream_a_text: [],
      stream_b_audio: [],
      stream_c_video: [],
      stream_d_behavioral: [],
      stream_e_analog: [],
      conflicts_detected: [],
      ...data,
    };
    const all = readAll();
    all.push(subject);
    writeAll(all);
    return subject;
  },

  async update(id, data = {}) {
    const all = readAll();
    const idx = all.findIndex((s) => s.id === id);
    if (idx === -1) throw new Error(`Subject ${id} not found`);
    all[idx] = { ...all[idx], ...data, updated_date: new Date().toISOString() };
    writeAll(all);
    return all[idx];
  },

  async delete(id) {
    writeAll(readAll().filter((s) => s.id !== id));
    return { id };
  },
};

// ─── Worker bridge (audio analysis only) ────────────────────────────────────

async function workerPost(path, body) {
  if (!hasWorker()) {
    throw new Error(
      'Audio/video analysis requires the Apollo Worker. Set VITE_APOLLO_WORKER_URL to your deployed Worker URL.'
    );
  }
  const headers = { 'Content-Type': 'application/json' };
  if (APOLLO_WORKER_SECRET) headers['X-Apollo-Secret'] = APOLLO_WORKER_SECRET;
  const res = await fetch(`${APOLLO_WORKER_URL}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    /* non-JSON */
  }
  if (!res.ok) {
    throw new Error(json?.error || `Worker ${res.status}: ${text.slice(0, 200)}`);
  }
  return json;
}

// ─── File upload ─────────────────────────────────────────────────────────────
// With a Worker configured, files go to R2 via a presigned PUT (server-fetchable
// URL — works for audio/video analysis). Without a Worker, small files are kept
// as data URLs so text/image analysis still works in the browser.

const DATA_URL_CUTOFF = 8 * 1024 * 1024; // 8 MB

function fileToDataURL(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(new Error('Failed to read file'));
    reader.readAsDataURL(file);
  });
}

async function uploadViaWorker(file) {
  const presign = await workerPost('/api/presignUpload', {
    filename: file.name,
    content_type: file.type || 'application/octet-stream',
  });
  const putRes = await fetch(presign.uploadURL, {
    method: 'PUT',
    headers: { 'Content-Type': file.type || 'application/octet-stream' },
    body: file,
  });
  if (!putRes.ok) throw new Error(`Upload failed: ${putRes.status}`);
  return presign.publicURL;
}

const Core = {
  async InvokeLLM(args) {
    return invokeLLM(args);
  },

  async UploadFile({ file }) {
    if (hasWorker()) {
      const file_url = await uploadViaWorker(file);
      return { file_url };
    }
    if (file.size > DATA_URL_CUTOFF) {
      throw new Error(
        `"${file.name}" is too large to process in-browser (${(file.size / 1048576).toFixed(1)}MB). Configure the Apollo Worker for large-file uploads.`
      );
    }
    const dataUrl = await fileToDataURL(file);
    // Tag the original filename so the UI can show it (data URLs have no path).
    return { file_url: `${dataUrl}#name=${encodeURIComponent(file.name)}` };
  },
};

// ─── Functions bridge ────────────────────────────────────────────────────────

const functions = {
  /**
   * Mirrors base44.functions.invoke(name, body, opts).
   * Returns an axios-like `{ data }` envelope so existing pages keep working.
   */
  async invoke(name, body = {}, opts = {}) {
    if (name === 'generateEsotericProfile') {
      const subject = await SubjectEntity.get(body.subject_id);
      if (!subject) return { data: { error: 'Subject not found' } };
      try {
        const esoteric_profile = await generateEsotericProfileLocal({
          subject_id: subject.id,
          subject_name: subject.name,
          esoteric_inputs: subject.esoteric_inputs || {},
          dsp_summary: subject.dsp?.executive_summary || '',
        });
        await SubjectEntity.update(subject.id, { esoteric_profile });
        return { data: { success: true, esoteric_profile } };
      } catch (e) {
        return { data: { error: e?.message || 'Esoteric generation failed' } };
      }
    }

    if (name === 'analyzeAudio') {
      const data = await workerPost('/api/analyzeAudio', {
        file_url: body.file_url,
        media_type: body.media_type,
      });
      return { data };
    }

    if (name === 'exportDSP') {
      const subject = await SubjectEntity.get(body.subject_id);
      if (!subject) throw new Error('Subject not found');
      const blob = await buildDSPPdfBlob({
        subject,
        mode: body.mode || 'dsp',
        theme: body.color_theme || 'light',
      });
      return { data: blob };
    }

    throw new Error(`Unknown function: ${name}`);
  },
};

// ─── Auth + logging shims (no Base44 gating on web) ──────────────────────────

const auth = {
  async me() {
    return { id: 'local-operator', full_name: 'Operator', role: 'admin' };
  },
  logout() {},
  redirectToLogin() {},
};

const appLogs = {
  async logUserInApp() {
    /* no-op on web */
  },
};

export const base44 = {
  entities: { Subject: SubjectEntity },
  integrations: { Core },
  functions,
  auth,
  appLogs,
};

export default base44;
