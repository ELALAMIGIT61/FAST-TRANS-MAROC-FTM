/*
 * Edge Function : send-sms (crochet « Send SMS » de Supabase Auth)
 * Option B, lot SMS-2 (11/11/2026). Toute la logique est dans handler.ts.
 * Déployée avec --no-verify-jwt : Supabase Auth l'appelle sans jeton
 * utilisateur ; la protection est la signature vérifiée dans handler.ts.
 * Inactive tant que le crochet n'est pas activé dans le tableau de bord
 * (Authentication > Hooks).
 */
import { createHandler } from "./handler.ts";

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

Deno.serve(createHandler({
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  now: () => Date.now(),
  background: (p) => {
    if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) EdgeRuntime.waitUntil(p);
  },
}));
