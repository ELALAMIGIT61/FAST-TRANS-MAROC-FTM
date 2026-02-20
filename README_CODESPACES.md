# 🚀 Guide d'utilisation de Codespaces - Fast Trans Maroc

## 📋 Vue d'ensemble

Ce projet utilise GitHub Codespaces comme environnement de développement cloud pour tester l'application mobile générée par Natively.dev.

---

## 🎯 Workflow de développement
```
1. Offre de valeur (docs/) 
   ↓
2. Backend Supabase (configuré via migrations SQL)
   ↓
3. Spec.coding (préparée avec offre + schéma backend)
   ↓
4. Natively.dev génère le code → Push vers GitHub
   ↓
5. Codespaces → Tester l'app générée
   ↓
6. Ajustements si nécessaire → Commit
```

---

## 🛠️ Outils pré-installés dans Codespaces

- ✅ **Node.js 20** (environnement JavaScript)
- ✅ **Supabase CLI** (pour vérifier la connexion backend)
- ✅ **Expo CLI** (pour lancer l'app mobile)
- ✅ **EAS CLI** (pour builder et publier l'app)
- ✅ **GitHub CLI** (pour gérer GitHub depuis le terminal)

### Extensions VS Code installées automatiquement

- 🤖 **GitHub Copilot** + Chat (assistant IA)
- 🔍 **ESLint** (détection d'erreurs JavaScript)
- ✨ **Prettier** (formatage automatique du code)
- 📦 **Supabase VS Code** (extension officielle)
- 📱 **Expo Tools** (support React Native)

---

## 🚀 Démarrage rapide

### 1. Ouvrir un Codespace

Sur GitHub :
```
Code (bouton vert) → Codespaces → Create codespace on main
```

Attendez 1-2 minutes que l'environnement se configure automatiquement.

---

### 2. Configurer les variables d'environnement

Une fois le Codespace ouvert, dans le terminal :
```bash
# Copier le template
cp .env.example .env

# Éditer le fichier .env
code .env
```

Remplissez avec vos vraies clés Supabase (disponibles sur https://app.supabase.com/project/[votre-id]/settings/api) :
```bash
EXPO_PUBLIC_SUPABASE_URL=https://votre-project-id.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=votre-vraie-anon-key
```

⚠️ **Important** : Le fichier `.env` ne sera jamais committé (protection `.gitignore`).

---

### 3. Vérifier l'installation
```bash
# Vérifier Node.js
node --version

# Vérifier Supabase CLI
supabase --version

# Vérifier Expo CLI
npx expo --version
```

---

### 4. Installer les dépendances du projet
```bash
npm install
```

---

### 5. Lancer l'application mobile
```bash
npx expo start
```

L'app s'ouvrira automatiquement dans Expo Dev Tools (port 19001).

---

## 🔧 Commandes utiles

### Gestion de l'app
```bash
# Lancer l'app en mode développement
npx expo start

# Lancer avec tunnel (accès depuis votre téléphone)
npx expo start --tunnel

# Lancer sur un émulateur Android
npx expo start --android

# Lancer sur un simulateur iOS (Mac seulement)
npx expo start --ios

# Nettoyer le cache
npx expo start --clear
```

### Vérification Supabase
```bash
# Tester la connexion à Supabase
supabase projects list

# Vérifier les tables de la base
supabase db dump --data-only
```

### Debugging
```bash
# Voir les logs en temps réel
npx expo start --log

# Réinitialiser le Metro Bundler
npx expo start --clear
```

---

## 📡 Ports exposés automatiquement

| Port  | Service              | Accès                |
|-------|----------------------|----------------------|
| 8081  | Metro Bundler        | Notification         |
| 19000 | Expo Dev Server      | Notification         |
| 19001 | Expo Dev Tools       | Ouvre automatiquement|
| 19002 | Expo Tunnel          | Notification         |

---

## 🔐 Sécurité

### Variables d'environnement

- ✅ `.env` est ignoré par Git (`.gitignore`)
- ✅ Les clés sensibles restent dans GitHub Secrets (workflows CI/CD)
- ✅ Seules `SUPABASE_URL` et `SUPABASE_ANON_KEY` sont dans `.env` (safe côté client)

### Clés GitHub Secrets (ne PAS mettre dans `.env`)

- `SUPABASE_ACCESS_TOKEN` → Utilisée uniquement par les workflows
- `SUPABASE_DB_PASSWORD` → Utilisée pour les migrations SQL
- `SUPABASE_PROJECT_ID` → Utilisée pour la liaison au projet

---

## 📱 Tester sur votre téléphone

1. Installez **Expo Go** sur votre smartphone (iOS/Android)
2. Dans le terminal Codespace : `npx expo start --tunnel`
3. Scannez le QR code avec Expo Go
4. L'app se charge sur votre téléphone ! 🎉

---

## ❓ Résolution de problèmes

### "Module not found"
```bash
rm -rf node_modules
npm install
```

### "Metro bundler error"
```bash
npx expo start --clear
```

### "Supabase connection failed"
Vérifiez que votre `.env` contient les bonnes clés :
```bash
cat .env
```

### Le Codespace est lent
Fermez et recréez un nouveau Codespace :
```
Codespaces → ... → Delete codespace
Puis : Create codespace on main
```

---

## 📚 Ressources utiles

- [Documentation Expo](https://docs.expo.dev/)
- [Documentation Supabase](https://supabase.com/docs)
- [GitHub Codespaces Docs](https://docs.github.com/codespaces)
- [Natively.dev](https://natively.dev/)

---

## 🎯 Prochaines étapes

Après avoir testé l'app dans Codespaces :

1. ✅ Vérifier la connexion Supabase
2. ✅ Tester les fonctionnalités principales
3. ✅ Faire les ajustements nécessaires
4. ✅ Commiter les changements
5. ✅ Builder pour production avec EAS

---

**Projet** : Fast Trans Maroc - Application de mise en relation Clients/Transporteurs VUL
**Environnement** : GitHub Codespaces + Supabase Backend
**Framework** : React Native (Expo) + TypeScript
```

