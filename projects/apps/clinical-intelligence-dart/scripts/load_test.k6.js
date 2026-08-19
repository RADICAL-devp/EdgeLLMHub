// k6 load test for the Clinical Intelligence backend.
//
// Targets every API route with a stub LLM (default backend config), so the
// test exercises auth, persistence, validation, and vector-store paths
// without external model dependencies.
//
// Usage:
//   k6 run scripts/load_test.k6.js                # default: http://localhost:8080
//   k6 run -e BASE_URL=http://192.168.1.10:8080 scripts/load_test.k6.js
//   k6 run --summary-trend-stats="avg,min,med,max,p(90),p(95)" scripts/load_test.k6.js
//
// Footnote: k6 — https://grafana.com/docs/k6/latest/
// Install: brew install k6   |   https://k6.io/docs/getting-started/installation/

import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const VU_TEST_DURATION_S = Number(__ENV.TEST_DURATION_S || 60);

const TRANSCRIPT = [
  'Dr. Smith saw the patient for persistent coughing. The cough started ',
  'about two weeks ago, worse at night. Patient reports mild fever on and ',
  'off and some wheezing. No known allergies. On examination, dullness on ',
  'percussion noted over the right base. Recommended chest X-ray and blood ',
  'work. Advised rest and increased fluids, follow up in one week.',
].join('');

export const options = {
  // Ramp up to 50 VUs, hold, then scale down.
  stages: [
    { duration: '30s', target: 10 },
    { duration: '60s', target: 50 },
    { duration: `${VU_TEST_DURATION_S}s`, target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.05'], // <5% error rate
    http_req_duration: ['p(95)<5000'], // p95 latency < 5s (LLM-backed)
    'http_req_duration{name:token}': ['p(95)<500'],
    'http_req_duration{name:notes_sync}': ['p(95)<1000'],
  },
};

// Mint one JWT per VU in setup(); reused by all iterations of that VU.
export function setup() {
  const res = http.post(`${BASE_URL}/api/v1/auth/token`, null, {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'auth token issued (200)': (r) => r.status === 200 });
  if (res.status !== 200) {
    throw new Error(`Token mint failed (${res.status}): ${res.body}`);
  }
  return { token: res.json('token') };
}

const authHeaders = (token) => ({
  'Content-Type': 'application/json',
  Authorization: `Bearer ${token}`,
});

// Lightweight (roughly deterministic) unique consultation id per iteration.
let iter = 0;

export default function (data) {
  const token = data.token;
  const headers = authHeaders(token);
  // Take a stable slice of the transcript so identical texts embed the same
  // and hit vector-store retrieval on context-enriched calls.
  const text = TRANSCRIPT + ` (iteration ${iter++})`;

  // 1. Clinical processing (voice-notes workflow)
  const processModes = ['VOCAB_ASSIST', 'CLEAN_TRANSCRIPT', 'SUMMARIZE'];
  for (const mode of processModes) {
    const res = http.post(
      `${BASE_URL}/api/v1/clinical-processing/process`,
      JSON.stringify({ inputText: text, processingMode: mode }),
      { tags: { name: 'process' }, headers },
    );
    check(res, {
      [`process ${mode} (200)`]: (r) => r.status === 200,
    });
  }

  // 2. Structured summary + persistent bundle (creates a consultation)
  const consultId = `loadtest-${__VU}-${iter}`;
  const summaryBody = JSON.stringify({
    transcriptText: text,
    consultationId: consultId,
    patientId: 'p-loadtest',
    doctorId: 'd-loadtest',
    consultationMode: 'IN_CLINIC',
  });
  const structured = http.post(
    `${BASE_URL}/api/v1/transcript-summary/structured`,
    summaryBody,
    { tags: { name: 'structured' }, headers },
  );
  check(structured, {
    'structured summary (200)': (r) => r.status === 200,
  });

  // 3. Context-enriched summary — omits pastContext on *some* iterations so
  //    the vector-store retrieval path is exercised.
  const enrichedBody =
    iter % 2 === 0
      ? JSON.stringify({ transcriptText: text })
      : JSON.stringify({
          transcriptText: text,
          pastContext: 'Previous consult: patient had mild seasonal asthma.',
        });
  const enriched = http.post(
    `${BASE_URL}/api/v1/transcript-summary/context-enriched`,
    enrichedBody,
    { tags: { name: 'context_enriched' }, headers },
  );
  check(enriched, {
    'context-enriched (200)': (r) => r.status === 200,
  });

  // 4. Executive summary + doctor note
  const exec = http.post(
    `${BASE_URL}/api/v1/transcript-summary/executive`,
    JSON.stringify({ transcriptText: text }),
    { tags: { name: 'executive' }, headers },
  );
  check(exec, { 'executive summary (200)': (r) => r.status === 200 });

  const note = http.post(
    `${BASE_URL}/api/v1/transcript-summary/doctor-note`,
    JSON.stringify({ transcriptText: text }),
    { tags: { name: 'doctor_note' }, headers },
  );
  check(note, { 'doctor note (200)': (r) => r.status === 200 });

  // 5. Notes sync (upsert) + fetch
  const now = new Date().toISOString();
  const syncBody = JSON.stringify({
    noteId: `note-${consultId}`,
    consultationId: consultId,
    patientId: 'p-loadtest',
    doctorId: 'd-loadtest',
    rawText: text,
    status: 'draft',
    createdAt: now,
    updatedAt: now,
    extractedFields: {
      symptoms: ['cough', 'wheezing'],
      duration: '2 weeks',
      medications: [],
      allergies: [],
      testsRecommended: ['chest X-ray'],
      followUpActions: [],
      provisionalDiagnosis: 'respiratory infection',
    },
  });
  const sync = http.post(`${BASE_URL}/api/v1/notes/sync`, syncBody, {
    tags: { name: 'notes_sync' },
    headers,
  });
  check(sync, { 'notes sync (200)': (r) => r.status === 200 });

  const fetchNote = http.get(
    `${BASE_URL}/api/v1/notes/consultation/${consultId}`,
    { tags: { name: 'notes_get' }, headers },
  );
  check(fetchNote, { 'notes fetch (200)': (r) => r.status === 200 });

  // 6. Fetch + regenerate the summary bundle
  const fetchBundle = http.get(
    `${BASE_URL}/api/v1/transcript-summary/${consultId}`,
    { tags: { name: 'summary_get' }, headers },
  );
  check(fetchBundle, { 'summary fetch (200)': (r) => r.status === 200 });

  const regenerate = http.post(
    `${BASE_URL}/api/v1/transcript-summary/${consultId}/regenerate`,
    null,
    { tags: { name: 'regenerate' }, headers },
  );
  check(regenerate, { 'regenerate (200)': (r) => r.status === 200 });

  // 7. Negative path: invalid body must be rejected by schema validation (400)
  const bad = http.post(
    `${BASE_URL}/api/v1/transcript-summary/structured`,
    JSON.stringify({ notATranscript: true }),
    { tags: { name: 'negative_path' }, headers },
  );
  check(bad, {
    'schema validation rejects bad body (400)': (r) => r.status === 400,
  });

  sleep(1);
}