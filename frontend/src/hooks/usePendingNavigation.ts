// /frontend/src/hooks/usePendingNavigation.ts
// FTM A1 (correction 31) — ouverture d'un ecran demande par une notification.
// La notification met a jour l'accueil du role (pendingScreen / pendingParams,
// voir pushSetup.ts) ; l'accueil, deja affiche et pret, ouvre alors l'ecran
// demande. C'est le meme chemin que la notification « Nouvelle mission »,
// qui fonctionne, alors que l'ouverture directe ramenait a l'accueil.

import { useEffect } from 'react';

type Nav = {
  navigate: (screen: string, params?: Record<string, unknown>) => void;
  setParams: (params: Record<string, unknown>) => void;
};

export function usePendingNavigation(
  params: Record<string, unknown> | undefined,
  navigation: Nav
): void {
  const pendingScreen = params?.pendingScreen as string | undefined;
  const pendingParams = params?.pendingParams as Record<string, unknown> | undefined;
  const pendingAt = params?.pendingAt as number | undefined;

  useEffect(() => {
    if (!pendingScreen) return;
    console.log('[FTM-DEBUG] Push - Opening screen from home', { screen: pendingScreen });
    navigation.setParams({ pendingScreen: undefined, pendingParams: undefined, pendingAt: undefined });
    navigation.navigate(pendingScreen, pendingParams ?? {});
    // pendingAt : une nouvelle notification vers le meme ecran relance l'ouverture
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pendingScreen, pendingAt]);
}
