/*
 * Edge Function : check-sms-credit — logique (lot 2, B5, 16/11/2026)
 *
 * Rôle : lire le crédit du compte AdaSMS et le transmettre à la base, qui
 * décide des alertes aux administrateurs (report_sms_credit, migration 082).
 * Appelée toutes les heures par la tâche planifiée « check-sms-credit », avec
 * la clé serveur. La consultation du solde n'envoie aucun SMS.
 *
 * Étapes :
 *  1. refuser tout appelant qui n'est pas le serveur ;
 *  2. GET https://api.adasms.ma/v1/account (en-tête X-API-Key), délai 10 s ;
 *  3. lire account.estimatedSmsRemaining (nombre), account.balance et
 *     account.smsUnitPrice (textes, convertis en nombres), account.currency ;
 *  4. appeler report_sms_credit avec le résultat ou l'erreur.
 *
 * La fonction send-sms (codes de connexion) n'est pas touchée. La clé AdaSMS
 * vient des secrets Supabase et n'est jamais écrite dans les journaux.
 */

export type Env = (name: string) => string | undefined;
export type Fetch = typeof fetch;

export interface Deps {
  env: Env;
  fetch: Fetch;
}

export interface Reading {
  httpStatus: number;          // 0 = pas de réponse
  smsRemaining: number | null; // null = réponse inexploitable
  balance: number | null;
  unitPrice: number | null;
  currency: string | null;
  error: string | null;
}

export const ADASMS_ACCOUNT_URL = "https://api.adasms.ma/v1/account";
const ADASMS_TIMEOUT_MS = 10000;
const DB_TIMEOUT_MS = 10000;

async function fetchWithTimeout(f: Fetch, url: string, init: RequestInit, ms: number): Promise<Response> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    return await f(url, { ...init, signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

// Nombre lu dans un texte ("549.8100") ou un nombre ; null si illisible
export function toNumber(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v.trim());
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

// 1. Appelant : seulement le serveur (clé serveur ou jeton de rôle service_role)
function jwtRole(authHeader: string): string | null {
  try {
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const part = token.split(".")[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(part.length / 4) * 4, "=");
    const payload = JSON.parse(atob(b64));
    return typeof payload.role === "string" ? payload.role : null;
  } catch {
    return null;
  }
}

export function isServiceCaller(authHeader: string, serviceKey: string | undefined): boolean {
  if (!authHeader) return false;
  if (serviceKey && authHeader === `Bearer ${serviceKey}`) return true;
  return jwtRole(authHeader) === "service_role";
}

// 2. et 3. Lecture du crédit AdaSMS
export async function readCredit(deps: Deps): Promise<Reading> {
  const key = deps.env("ADASMS_API_KEY");
  const empty = { smsRemaining: null, balance: null, unitPrice: null, currency: null };
  if (!key) return { httpStatus: 0, ...empty, error: "cle_absente" };
  let res: Response;
  try {
    res = await fetchWithTimeout(deps.fetch, ADASMS_ACCOUNT_URL, {
      method: "GET",
      headers: { "X-API-Key": key, "Accept": "application/json" },
    }, ADASMS_TIMEOUT_MS);
  } catch (e) {
    const aborted = e instanceof Error && e.name === "AbortError";
    return { httpStatus: 0, ...empty, error: aborted ? "delai_depasse" : "reseau" };
  }
  let body: unknown = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }
  if (res.status !== 200) {
    const code = (body as { code?: unknown } | null)?.code;
    return { httpStatus: res.status, ...empty, error: `HTTP ${res.status}${typeof code === "string" ? " " + code.slice(0, 40) : ""}` };
  }
  const account = (body as { success?: unknown; account?: Record<string, unknown> } | null)?.account;
  const sms = toNumber(account?.estimatedSmsRemaining);
  if ((body as { success?: unknown } | null)?.success !== true || !account || sms === null) {
    return { httpStatus: 200, ...empty, error: "reponse_illisible" };
  }
  return {
    httpStatus: 200,
    smsRemaining: Math.max(0, Math.floor(sms)),
    balance: toNumber(account.balance),
    unitPrice: toNumber(account.smsUnitPrice),
    currency: typeof account.currency === "string" ? account.currency.slice(0, 10) : null,
    error: null,
  };
}

// 4. Transmission à la base (clé serveur)
export async function reportCredit(deps: Deps, r: Reading): Promise<{ ok: boolean; result: unknown }> {
  const key = deps.env("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const res = await fetchWithTimeout(deps.fetch, `${deps.env("SUPABASE_URL")}/rest/v1/rpc/report_sms_credit`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      p_http_status: r.httpStatus,
      p_sms_remaining: r.smsRemaining,
      p_balance: r.balance,
      p_unit_price: r.unitPrice,
      p_currency: r.currency,
      p_error: r.error,
    }),
  }, DB_TIMEOUT_MS);
  let result: unknown = null;
  try {
    result = await res.json();
  } catch {
    result = null;
  }
  return { ok: res.ok, result };
}

function reply(status: number, payload: Record<string, unknown>): Response {
  return new Response(JSON.stringify(payload), { status, headers: { "Content-Type": "application/json" } });
}

export function createHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (!isServiceCaller(req.headers.get("Authorization") ?? "", deps.env("SUPABASE_SERVICE_ROLE_KEY"))) {
      return reply(401, { error: "acces_refuse" });
    }
    const reading = await readCredit(deps);
    console.log("[FTM-DEBUG] SMS credit - Reading", {
      httpStatus: reading.httpStatus, smsRemaining: reading.smsRemaining, error: reading.error,
    });
    try {
      const report = await reportCredit(deps, reading);
      console.log("[FTM-DEBUG] SMS credit - Reported", { ok: report.ok, result: report.result });
      return reply(report.ok ? 200 : 502, { reading: { ...reading }, report: report.result });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.log("[FTM-DEBUG] SMS credit - Report error", { msg });
      return reply(502, { reading: { ...reading }, error: "base_injoignable" });
    }
  };
}
