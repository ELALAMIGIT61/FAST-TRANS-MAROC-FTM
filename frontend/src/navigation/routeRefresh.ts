// /navigation/routeRefresh.ts
// Lot 3 (A10) : permet a un ecran de demander au RootNavigator de recalculer
// l'espace a afficher (client, chauffeur en attente, chauffeur actif, admin),
// sans redemarrer l'application. Utilise par l'ecran d'attente du chauffeur
// quand l'admin valide son dossier.
let handler: (() => void) | null = null;

export function setRouteRefreshHandler(h: (() => void) | null): void {
  handler = h;
}

export function requestRouteRefresh(): void {
  console.log('[FTM-DEBUG] App - Route refresh requested', { hasHandler: !!handler });
  handler?.();
}
