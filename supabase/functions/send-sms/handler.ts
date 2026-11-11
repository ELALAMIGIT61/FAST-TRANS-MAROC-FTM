/*
 * Edge Function : send-sms — logique (lot SMS-1/SMS-2, option B, 11/11/2026)
 *
 * Rôle : crochet « Send SMS » de Supabase Auth. Supabase fabrique et vérifie le
 * code de connexion ; cette fonction ne fait que l'envoyer par SMS.
 * Les numéros de test de Supabase n'arrivent jamais ici (Supabase les traite
 * avant d'appeler le crochet).
 *
 * Étapes :
 *  1. vérifier la signature de Supabase (norme « Standard Webhooks ») ;
 *  2. demander l'état d'aiguillage à la base (sms_routing_state, migration 079) ;
 *  3. choisir la route : AdaSMS (principal), Twilio (secours, en sommeil tant
 *     que ses clés n'existent pas) ;
 *  4. envoyer, avec un délai d'attente ;
 *  5. inscrire chaque tentative au journal sms_send_log (numéro masqué,
 *     jamais le code) ;
 *  6. répondre à Supabase : {} si envoyé, sinon {"error": {...}}.
 *
 * Aucun secret n'est écrit ici : tout vient des variables d'environnement
 * (secrets Supabase alimentés depuis GitHub Secrets).
 */

export type Env = (name: string) => string | undefined;
export type Fetch = typeof fetch;

export interface Deps {
  env: Env;
  fetch: Fetch;
  now: () => number;
  // Exécute une tâche après la réponse (EdgeRuntime.waitUntil si disponible)
  background: (p: Promise<unknown>) => void;
}

export interface SendResult {
  ok: boolean;
  httpStatus: number | null;
  errorCode: string | null;
  errorMessage: string | null;
  providerMessageId: string | null;
  cost: number | null;
  segments: number | null;
  durationMs: number;
}

interface RoutingState {
  mode: number;
  timeout_primary_ms: number;
  timeout_with_fallback_ms: number;
  resend_fallback_from: number;
  breaker_open: boolean;
  send_number: number;
}

const DEFAULT_STATE: RoutingState = {
  mode: 0,
  timeout_primary_ms: 3500,
  timeout_with_fallback_ms: 2500,
  resend_fallback_from: 3,
  breaker_open: false,
  send_number: 1,
};

const SIGNATURE_TOLERANCE_S = 5 * 60;
const STATE_TIMEOUT_MS = 800;
// Supabase abandonne à 5 s : tout doit être fini en 4,6 s après réception
const TOTAL_BUDGET_MS = 4600;
const LOG_TIMEOUT_MS = 3000;
const USER_ERROR_MESSAGE = "Envoi du SMS impossible pour le moment. Réessayez dans une minute.";

// Texte du SMS (point P1 validé le 11/11/2026). Modifiable par un nouveau déploiement.
export function smsText(otp: string): string {
  return `BiniBinak : votre code est ${otp}. Ne le communiquez a personne.`;
}

// +2126••••5678 : 4 premiers chiffres, 4 derniers, le reste masqué
export function maskPhone(phone: string): string {
  const d = (phone ?? "").replace(/\D/g, "");
  if (d.length < 8) return "+" + "•".repeat(Math.max(d.length, 1));
  return "+" + d.slice(0, 4) + "•".repeat(d.length - 8) + d.slice(-4);
}

// Jamais 5 chiffres à la suite dans le journal (ni code, ni numéro)
export function cleanMessage(s: string | null | undefined): string | null {
  if (!s) return null;
  return s.replace(/[0-9]{5,}/g, "…").replace(/\s+/g, " ").trim().slice(0, 300) || null;
}

function toE164(phone: string): string {
  return "+" + (phone ?? "").replace(/\D/g, "");
}

// ---------- 1. Signature Standard Webhooks ----------

function b64decode(s: string): Uint8Array {
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64encode(b: ArrayBuffer): string {
  const u = new Uint8Array(b);
  let s = "";
  for (let i = 0; i < u.length; i++) s += String.fromCharCode(u[i]);
  return btoa(s);
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

export async function verifySignature(
  secret: string,
  headers: Headers,
  body: string,
  nowMs: number,
): Promise<boolean> {
  const id = headers.get("webhook-id");
  const ts = headers.get("webhook-timestamp");
  const sigHeader = headers.get("webhook-signature");
  if (!id || !ts || !sigHeader || !/^\d+$/.test(ts)) return false;
  if (Math.abs(nowMs / 1000 - Number(ts)) > SIGNATURE_TOLERANCE_S) return false;
  let keyBytes: Uint8Array;
  try {
    keyBytes = b64decode(secret.replace(/^v1,/, "").replace(/^whsec_/, ""));
  } catch {
    return false;
  }
  if (keyBytes.length === 0) return false;
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${ts}.${body}`));
  const expected = b64encode(mac);
  const candidates = [...sigHeader.matchAll(/v1,([A-Za-z0-9+/=]+)/g)].map((m) => m[1]);
  return candidates.some((c) => safeEqual(c, expected));
}

// ---------- Appels avec délai d'attente ----------

async function fetchWithTimeout(f: Fetch, url: string, init: RequestInit, ms: number): Promise<Response> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await f(url, { ...init, signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

function failure(errorCode: string, errorMessage: string, httpStatus: number | null, start: number, now: () => number): SendResult {
  return {
    ok: false, httpStatus, errorCode, errorMessage: cleanMessage(errorMessage),
    providerMessageId: null, cost: null, segments: null, durationMs: Math.round(now() - start),
  };
}

// ---------- 3. Branchements ----------

export function adasmsConfigured(env: Env): boolean {
  return !!env("ADASMS_API_KEY");
}

export function twilioConfigured(env: Env): boolean {
  return !!(env("TWILIO_ACCOUNT_SID") && env("TWILIO_AUTH_TOKEN") &&
    (env("TWILIO_FROM") || env("TWILIO_MESSAGING_SERVICE_SID")));
}

export async function sendAdasms(deps: Deps, to: string, text: string, reference: string, timeoutMs: number): Promise<SendResult> {
  const start = deps.now();
  const key = deps.env("ADASMS_API_KEY");
  if (!key) return failure("ADASMS_NOT_CONFIGURED", "clé AdaSMS absente", null, start, deps.now);
  const payload: Record<string, string> = { to: toE164(to), text, type: "otp", reference };
  const sender = deps.env("ADASMS_SENDER_ID");
  if (sender) payload.from = sender;
  let res: Response;
  try {
    res = await fetchWithTimeout(deps.fetch, "https://api.adasms.ma/v1/messages", {
      method: "POST",
      headers: { "X-API-Key": key, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }, timeoutMs);
  } catch (e) {
    const timeout = e instanceof DOMException && e.name === "AbortError";
    return failure(timeout ? "TIMEOUT" : "NETWORK", timeout ? `pas de réponse en ${timeoutMs} ms` : String(e), null, start, deps.now);
  }
  let data: Record<string, unknown> = {};
  try {
    data = await res.json();
  } catch { /* corps illisible */ }
  if (res.ok && data.success === true) {
    const cost = Number(data.cost);
    return {
      ok: true, httpStatus: res.status, errorCode: null, errorMessage: null,
      providerMessageId: typeof data.messageId === "string" ? data.messageId.slice(0, 128) : null,
      cost: Number.isFinite(cost) ? cost : null,
      segments: typeof data.segments === "number" ? data.segments : null,
      durationMs: Math.round(deps.now() - start),
    };
  }
  return failure(
    typeof data.code === "string" ? data.code.slice(0, 64) : `HTTP_${res.status}`,
    typeof data.message === "string" ? data.message : "réponse AdaSMS en échec",
    res.status, start, deps.now,
  );
}

export async function sendTwilio(deps: Deps, to: string, text: string, timeoutMs: number): Promise<SendResult> {
  const start = deps.now();
  const sid = deps.env("TWILIO_ACCOUNT_SID");
  const token = deps.env("TWILIO_AUTH_TOKEN");
  if (!twilioConfigured(deps.env) || !sid || !token) {
    return failure("TWILIO_NOT_CONFIGURED", "secours Twilio non configuré", null, start, deps.now);
  }
  const form = new URLSearchParams({ To: toE164(to), Body: text });
  const service = deps.env("TWILIO_MESSAGING_SERVICE_SID");
  if (service) form.set("MessagingServiceSid", service);
  else form.set("From", deps.env("TWILIO_FROM") as string);
  let res: Response;
  try {
    res = await fetchWithTimeout(deps.fetch, `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(sid)}/Messages.json`, {
      method: "POST",
      headers: { Authorization: "Basic " + btoa(`${sid}:${token}`), "Content-Type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    }, timeoutMs);
  } catch (e) {
    const timeout = e instanceof DOMException && e.name === "AbortError";
    return failure(timeout ? "TIMEOUT" : "NETWORK", timeout ? `pas de réponse en ${timeoutMs} ms` : String(e), null, start, deps.now);
  }
  let data: Record<string, unknown> = {};
  try {
    data = await res.json();
  } catch { /* corps illisible */ }
  if (res.status === 201 || (res.ok && typeof data.sid === "string")) {
    const segments = Number(data.num_segments);
    return {
      ok: true, httpStatus: res.status, errorCode: null, errorMessage: null,
      providerMessageId: typeof data.sid === "string" ? data.sid.slice(0, 128) : null,
      cost: null, segments: Number.isFinite(segments) ? segments : null,
      durationMs: Math.round(deps.now() - start),
    };
  }
  return failure(
    data.code !== undefined ? `TWILIO_${String(data.code).slice(0, 50)}` : `HTTP_${res.status}`,
    typeof data.message === "string" ? data.message : "réponse Twilio en échec",
    res.status, start, deps.now,
  );
}

// ---------- 2. et 5. Base de données (clé serveur) ----------

function dbHeaders(env: Env): Record<string, string> {
  const key = env("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
}

async function routingState(deps: Deps, userId: string | null): Promise<RoutingState> {
  try {
    const res = await fetchWithTimeout(deps.fetch, `${deps.env("SUPABASE_URL")}/rest/v1/rpc/sms_routing_state`, {
      method: "POST", headers: dbHeaders(deps.env), body: JSON.stringify({ p_user_id: userId }),
    }, STATE_TIMEOUT_MS);
    if (!res.ok) return DEFAULT_STATE;
    const s = await res.json();
    return { ...DEFAULT_STATE, ...s };
  } catch {
    return DEFAULT_STATE; // base injoignable : AdaSMS seul, valeurs par défaut
  }
}

export interface LogRow {
  id: string;
  user_id: string | null;
  phone_masked: string;
  send_number: number;
  attempt: number;
  mode: number;
  provider: "adasms" | "twilio";
  outcome: "sent" | "failed";
  is_fallback: boolean;
  breaker_open: boolean;
  http_status: number | null;
  error_code: string | null;
  error_message: string | null;
  duration_ms: number;
  provider_message_id: string | null;
  cost_mad: number | null;
  segments: number | null;
}

async function writeLog(deps: Deps, rows: LogRow[]): Promise<void> {
  try {
    await fetchWithTimeout(deps.fetch, `${deps.env("SUPABASE_URL")}/rest/v1/sms_send_log`, {
      method: "POST", headers: { ...dbHeaders(deps.env), Prefer: "return=minimal" }, body: JSON.stringify(rows),
    }, LOG_TIMEOUT_MS);
  } catch {
    // le journal ne doit jamais empêcher l'envoi du code
  }
}

// ---------- Choix de la route ----------

export interface Step {
  provider: "adasms" | "twilio";
  isFallback: boolean;
  timeoutMs: number;
}

export function planRoute(state: RoutingState, fallbackAvailable: boolean): { steps: Step[]; warning: string | null } {
  const mode = [0, 1, 2].includes(state.mode) ? state.mode : 0;
  const primary = Math.min(Math.max(state.timeout_primary_ms, 500), 4500);
  const withFallback = Math.min(Math.max(state.timeout_with_fallback_ms, 500), 3000);
  if (mode === 0) return { steps: [{ provider: "adasms", isFallback: false, timeoutMs: primary }], warning: null };
  if (!fallbackAvailable) {
    return {
      steps: [{ provider: "adasms", isFallback: false, timeoutMs: primary }],
      warning: "FALLBACK_NOT_CONFIGURED",
    };
  }
  if (mode === 2) return { steps: [{ provider: "twilio", isFallback: true, timeoutMs: primary }], warning: null };
  if (state.breaker_open || state.send_number >= state.resend_fallback_from) {
    return { steps: [{ provider: "twilio", isFallback: true, timeoutMs: primary }], warning: null };
  }
  return {
    steps: [
      { provider: "adasms", isFallback: false, timeoutMs: withFallback },
      { provider: "twilio", isFallback: true, timeoutMs: Math.max(4500 - withFallback, 500) },
    ],
    warning: null,
  };
}

// ---------- Point d'entrée ----------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export function createHandler(deps: Deps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return json({ error: { http_code: 405, message: "Méthode non autorisée" } }, 405);
    const body = await req.text();
    const secret = deps.env("SEND_SMS_HOOK_SECRET");
    if (!secret || !(await verifySignature(secret, req.headers, body, deps.now()))) {
      return json({ error: { http_code: 401, message: "Signature invalide" } }, 401);
    }

    let payload: { user?: { id?: string; phone?: string }; sms?: { otp?: string } };
    try {
      payload = JSON.parse(body);
    } catch {
      return json({ error: { http_code: 400, message: "Requête invalide" } }, 400);
    }
    const phone = payload.user?.phone ?? "";
    const otp = payload.sms?.otp ?? "";
    const userId = payload.user?.id ?? null;
    if (!/\d{8,}/.test(phone.replace(/\D/g, "")) || !/^\d{4,10}$/.test(otp)) {
      return json({ error: { http_code: 400, message: "Requête invalide" } }, 400);
    }

    const deadline = deps.now() + TOTAL_BUDGET_MS;
    const state = await routingState(deps, userId);
    const { steps, warning } = planRoute(state, twilioConfigured(deps.env));
    const text = smsText(otp);
    const rows: LogRow[] = [];
    let sent = false;

    for (let i = 0; i < steps.length && !sent; i++) {
      const step = steps[i];
      const id = crypto.randomUUID();
      const budget = Math.min(step.timeoutMs, Math.floor(deadline - deps.now()));
      const r = budget < 300
        ? failure("TIME_BUDGET", "plus assez de temps avant la limite de 5 s", null, deps.now(), deps.now)
        : step.provider === "adasms"
        ? await sendAdasms(deps, phone, text, id, budget)
        : await sendTwilio(deps, phone, text, budget);
      sent = r.ok;
      rows.push({
        id,
        user_id: userId,
        phone_masked: maskPhone(phone),
        send_number: state.send_number,
        attempt: i === 0 ? 1 : 2,
        mode: [0, 1, 2].includes(state.mode) ? state.mode : 0,
        provider: step.provider,
        outcome: r.ok ? "sent" : "failed",
        is_fallback: step.isFallback,
        breaker_open: state.breaker_open,
        http_status: r.httpStatus,
        error_code: r.errorCode ?? (i === 0 ? warning : null),
        error_message: r.errorMessage ??
          (i === 0 && warning ? "avertissement : secours demandé mais non configuré, envoi par AdaSMS" : null),
        duration_ms: r.durationMs,
        provider_message_id: r.providerMessageId,
        cost_mad: r.cost,
        segments: r.segments,
      });
    }

    deps.background(writeLog(deps, rows));
    if (sent) return json({});
    return json({ error: { http_code: 503, message: USER_ERROR_MESSAGE } });
  };
}
