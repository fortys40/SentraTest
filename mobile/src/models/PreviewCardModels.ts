import type { UUID } from '@/core/utilities/SentraJSON';

import type { BadgeDefinition } from './BadgeModels';
import type { Profile } from './IdentityModels';
import type { PlayerStats } from './StatsModels';

// Preview-only models. No rating history, card design or title configuration is
// deployed, so none of these may become a live query without approved schema work.

export const cardTiers = ['bronze', 'silver', 'gold', 'elite'] as const;
export type CardTier = (typeof cardTiers)[number];

export function cardTier(overall: number): CardTier {
  if (overall < 65) return 'bronze';
  if (overall < 75) return 'silver';
  if (overall < 85) return 'gold';
  return 'elite';
}

export type PreviewPlayerTitle = 'wall' | 'scorer' | 'everPresent' | 'mvpMachine';

export interface CardDesign {
  readonly id: string;
  readonly tier: CardTier;
}

export interface RatingHistoryEntry {
  readonly id: UUID;
  readonly userID: UUID;
  readonly groupID: UUID;
  readonly matchID: UUID;
  readonly overall: number;
  readonly recordedAt: Date;
}

export interface PlayerCardExample {
  readonly profile: Profile;
  readonly groupName: string;
  readonly stats: PlayerStats;
  readonly overall: number;
  readonly title: PreviewPlayerTitle;
  readonly design: CardDesign;
  readonly badges: readonly BadgeDefinition[];
}

export function playerCardExampleID(example: PlayerCardExample): string {
  return `${example.profile.id}:${example.design.id}`;
}
