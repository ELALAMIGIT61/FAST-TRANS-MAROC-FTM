// /frontend/src/constants/theme.ts
// FTM — Design System Tokens
 
export const COLORS = {
  primary:    '#0056B3', // Bleu Royal — Actions principales, headers
  cta:        '#F39C12', // Jaune Ambre — Boutons CTA, bouton micro audio
  success:    '#28A745', // Vert — Validation, statut "verified"
  alert:      '#DC3545', // Rouge — Erreurs, alertes, rejets
  background: '#F8F9FA', // Gris très clair — Fond des écrans
  white:      '#FFFFFF',
  textDark:   '#1A1A2E',
  textMuted:  '#6C757D',
} as const;
 
export const FONTS = {
  regular: 'Inter-Regular',
  medium:  'Inter-Medium',
  bold:    'Inter-Bold',
  arabic:  'Cairo-Regular',
} as const;
 
export const FONT_SIZES = {
  xs:   12,
  sm:   14,
  md:   16,
  lg:   18,
  xl:   22,
  xxl:  28,
} as const;
 
export const RADIUS = {
  card:   12,
  button:  8,
  input:   8,
  chip:   20,
} as const;
 
export const SPACING = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
} as const;
