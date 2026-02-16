# OFFRE DE VALEUR : Fast Trans Maroc (FTM)

**Document de Référence (Source de Vérité) — Version 1.2**

---

## 1. Vision du Produit

**Fast Trans Maroc (FTM)** est une application mobile de mise en relation intelligente conçue pour le marché marocain. Elle connecte les clients (particuliers, TPME, E-commerçants) avec des transporteurs professionnels vérifiés.

### Objectif Principal
Optimiser le transport intra et inter-villes en réduisant les trajets à vide et en offrant une transparence totale sur les prix et la fiabilité des prestataires.

---

## 2. Piliers Stratégiques & Positionnement

### 🔐 Confiance Digitale
Vérification stricte des documents obligatoires :
- Permis de conduire
- Carte grise
- Assurance
- Visite technique

### 💰 Modèle "Cash-Friendly"
Le client paie directement le chauffeur en espèces. **FTM n'intervient pas dans le flux financier de la course.**

### 🌍 Accessibilité Locale
- Interface bilingue (Arabe/Français)
- Chat Vocal en **Darija** pour une utilisation sans friction

### 📦 Logistique E-commerce
Mutualisation des trajets existants pour le transport de petits colis à prix réduit.

---

## 3. Identité Visuelle (Design System UI)

L'interface est conçue pour la **visibilité** et la **rapidité d'exécution**, même en plein soleil (haut contraste).

### Palette de Couleurs

| Élément | Couleur | Code Hex | Usage |
|---------|---------|----------|-------|
| **Primaire (Actions)** | Bleu Royal | `#0056B3` | Sérieux & Professionnalisme |
| **Appel à l'Action (CTA)** | Jaune Ambre | `#F39C12` | Visibilité & Énergie |
| **Statut Succès** | Vert | `#28A745` | Confirmation, validation |
| **Statut Alerte** | Rouge | `#DC3545` | Erreur, attention |
| **Fond** | Gris très clair | `#F8F9FA` | Arrière-plan neutre |

### Ergonomie (UX)

- **Arrondis** : 12px pour les cartes (Cards) et 8px pour les boutons principaux
- **Typographie** : Sans-serif (Inter / Roboto) avec support Arabe
- **Interaction** : Bouton Micro orange pour le chat audio simplifié

---

## 4. Propositions de Valeur par Segment

### A. Clients (Particuliers & TPME)

✅ **Simplicité**  
Réservation d'un véhicule (VUL ou N2) via géolocalisation

✅ **Économie**  
Négociation directe du prix avec le chauffeur

✅ **Options**  
Possibilité de demander de la manutention (chargement/déchargement)

---

### B. Transporteurs (Indépendants & Flottes)

💼 **Plus de revenus**  
Accès à une demande constante et réduction des retours à vide

💳 **Simplicité financière**  
Pas d'abonnement. Prélèvement automatique d'une commission fixe sur un solde revolving (min. 100 DH)

🔔 **Assistance**  
Rappels automatiques pour le renouvellement des documents légaux

---

### C. E-commerce Local

📦 **Colisage Intelligent**  
Expédition de colis en profitant de trajets déjà payés par d'autres clients

📐 **Flexibilité**  
Gestion par dimensions (L×l×h) pour un matching précis avec l'espace libre dans les camions

---

## 5. Modèle Économique (Business Model)

FTM utilise un **modèle de commission fixe** par type de véhicule, prélevée sur le portefeuille numérique du chauffeur.

### Grille Tarifaire

| Catégorie Véhicule | Capacité | Commission FTM / Course |
|-------------------|----------|------------------------|
| **VUL** (Petit utilitaire) | ≤ 3,5 tonnes | **25 DH** |
| **N2** (Moyen camion) | 3,5 – 7,5 tonnes | **40 DH** |
| **N2** (Grand camion) | 7,5 – 12 tonnes | **50 DH** |

---

## 6. Architecture Technique (Spécifications)

### Backend (Supabase/SQL)

**Authentification**  
OTP par numéro de téléphone (standard Maroc)

**Base de données**  
- Gestion des profils (Client/Driver/Admin)
- Table des missions
- Table de transactions (Wallet Revolving)

**Temps Réel**  
Tracking GPS des chauffeurs pour le matching

---

### Application (Natively / Flutter)

**Fonctionnalités natives**
- Notifications Push
- Géolocalisation
- Accès stockage (pour documents)
- Microphone (Chat Audio)

**Multilingue**  
Switch dynamique Arabe/Français dans les réglages

---

## 7. Comparatif Marché

| Fonctionnalité | Fast Trans Maroc (FTM) | Plateformes Classiques |
|----------------|------------------------|------------------------|
| **Paiement** | Direct (Cash) | Intermédié (Carte) |
| **Commission** | Fixe (25/40/50 DH) | Pourcentage (%) élevé |
| **Documents** | Vérification manuelle/AI | Souvent peu contrôlés |
| **E-commerce** | Inclus d'office | Service séparé |

---

## 📌 Résumé Exécutif

**Fast Trans Maroc** se positionne comme la solution de transport logistique la plus adaptée au contexte marocain :

- 🇲🇦 **Locale** : Darija, Cash, réalités du terrain
- 🔒 **Sécurisée** : Vérification stricte des transporteurs
- 💡 **Innovante** : Mutualisation des trajets pour l'e-commerce
- 💰 **Équitable** : Commission fixe et transparente

---

**Document maintenu par** : Équipe Produit FTM  
**Dernière mise à jour** : Version 1.2  
**Contact** : [À compléter]

---

> Ce document constitue la **source de vérité** pour toutes les décisions produit, design et technique de Fast Trans Maroc.
