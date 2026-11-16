/*
 * Edge Function : check-sms-credit (lot 2, B5, 16/11/2026)
 * Lit le crédit du compte AdaSMS toutes les heures (tâche planifiée
 * « check-sms-credit », migration 082) et le transmet à la base, qui prévient
 * les administrateurs. Toute la logique est dans handler.ts.
 * Déployée avec la vérification du jeton (par défaut) : seul le serveur l'appelle.
 */
import { createHandler } from "./handler.ts";

Deno.serve(createHandler({
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
}));
