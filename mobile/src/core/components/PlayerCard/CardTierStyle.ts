import { cardTier } from '@/models';

export const playerCardAppearances = ['bronze', 'silver', 'gold', 'elite', 'playerOfTheWeek', 'provisional'] as const;
export type PlayerCardAppearance = (typeof playerCardAppearances)[number];

/** Provisional wins first, then the weekly MVP, then the free tier for the overall rating. */
export function playerCardAppearance(
  overall: number,
  appearances: number,
  isPlayerOfTheWeek = false,
): PlayerCardAppearance {
  if (appearances < 3) return 'provisional';
  if (isPlayerOfTheWeek) return 'playerOfTheWeek';
  return cardTier(overall);
}

export function showsOverall(appearance: PlayerCardAppearance): boolean {
  return appearance !== 'provisional';
}

export interface CardTierStyle {
  readonly appearance: PlayerCardAppearance;
  /** Material gradient, top-leading to bottom-trailing. */
  readonly top: string;
  readonly middle: string;
  readonly bottom: string;
  readonly ink: string;
  readonly accent: string;
  readonly highlight: string;
  readonly photoTint: string;
  readonly photoTintOpacity: number;
  readonly photoSaturation: number;
  readonly photoContrast: number;
  readonly photoBrightness: number;
  readonly hasMarbleTexture: boolean;
}

type Palette = Omit<CardTierStyle, 'appearance' | 'photoBrightness' | 'hasMarbleTexture'>;

// Card materials are independent of the app's light or dark appearance.
const palettes: Record<PlayerCardAppearance, Palette> = {
  bronze: {
    top: '#F8DEC2', middle: '#D9A776', bottom: '#EDC69A', ink: '#3B2415', accent: '#7A491F',
    highlight: '#FFF0D4', photoTint: '#D29569', photoTintOpacity: 0.08, photoSaturation: 0.96, photoContrast: 1.02,
  },
  silver: {
    top: '#F1F4F6', middle: '#B9C3CA', bottom: '#E8EEF0', ink: '#25333F', accent: '#51606C',
    highlight: '#FFFFFF', photoTint: '#ACC4DA', photoTintOpacity: 0.06, photoSaturation: 0.88, photoContrast: 1.02,
  },
  gold: {
    top: '#FFF1AD', middle: '#E4BB57', bottom: '#F6DF95', ink: '#3F2D08', accent: '#8B6214',
    highlight: '#FFFBE6', photoTint: '#E7C572', photoTintOpacity: 0.07, photoSaturation: 0.98, photoContrast: 1.03,
  },
  elite: {
    top: '#FFFFFF', middle: '#EBEADF', bottom: '#FCF8E8', ink: '#77580C', accent: '#B89432',
    highlight: '#FFFFFF', photoTint: '#FFF9E0', photoTintOpacity: 0.05, photoSaturation: 0.98, photoContrast: 0.98,
  },
  playerOfTheWeek: {
    top: '#0C141A', middle: '#1A241E', bottom: '#080E11', ink: '#FFEAA6', accent: '#EDC85A',
    highlight: '#FFF3C7', photoTint: '#FFD66D', photoTintOpacity: 0.06, photoSaturation: 1.0, photoContrast: 1.12,
  },
  provisional: {
    top: '#EAEEEF', middle: '#C3CCCB', bottom: '#DDE3E3', ink: '#384840', accent: '#66776E',
    highlight: '#FFFFFF', photoTint: '#D3DBD8', photoTintOpacity: 0.04, photoSaturation: 0.55, photoContrast: 0.98,
  },
};

export function cardTierStyle(appearance: PlayerCardAppearance): CardTierStyle {
  return {
    appearance,
    ...palettes[appearance],
    photoBrightness: appearance === 'elite' ? 0.025 : 0,
    hasMarbleTexture: appearance === 'elite' || appearance === 'gold',
  };
}

/** Metal outline gradient stops: highlight, accent, highlight, accent. */
export function metalStops(style: CardTierStyle): readonly { offset: number; color: string }[] {
  return [
    { offset: 0, color: style.highlight },
    { offset: 0.28, color: style.accent },
    { offset: 0.52, color: style.highlight },
    { offset: 1, color: style.accent },
  ];
}

/**
 * One SVG colour matrix (20 values, row-major) applying saturation, then
 * contrast, then brightness, matching the per-tier photo grading.
 */
export function photoGradingMatrix(style: CardTierStyle): number[] {
  const s = style.photoSaturation;
  const c = style.photoContrast;
  const shift = 0.5 * (1 - c) + style.photoBrightness;
  const [r, g, b] = [0.213, 0.715, 0.072];
  const row = (weights: [number, number, number], own: number) =>
    weights.map((weight, index) => c * (weight * (1 - s) + (index === own ? s : 0)));
  return [
    ...row([r, g, b], 0), 0, shift,
    ...row([r, g, b], 1), 0, shift,
    ...row([r, g, b], 2), 0, shift,
    0, 0, 0, 1, 0,
  ];
}
