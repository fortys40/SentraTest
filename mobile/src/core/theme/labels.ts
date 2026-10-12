import type { StringKey } from '@/core/i18n';
import type { CardTier, FootballPosition, MatchStatus, PreviewPlayerTitle, RSVPStatus } from '@/models';

import type { IconName } from '../components/Icon';
import type { ThemeColors } from './SentraTheme';

// Status is always carried by an icon and a label as well as colour.
export const rsvpLabel: Record<RSVPStatus, StringKey> = {
  yes: 'rsvp.yes', maybe: 'rsvp.maybe', no: 'rsvp.no', waitlist: 'rsvp.waitlist',
};

export const rsvpIcon: Record<RSVPStatus, IconName> = {
  yes: 'yes', maybe: 'maybe', no: 'no', waitlist: 'waitlist',
};

export function rsvpColor(status: RSVPStatus, colors: ThemeColors): string {
  return { yes: colors.primary, maybe: colors.warning, no: colors.danger, waitlist: colors.waitlist }[status];
}

export function rsvpChipBackground(status: RSVPStatus, colors: ThemeColors): string {
  return {
    yes: colors.yesSurface, maybe: colors.maybeSurface, no: colors.noSurface, waitlist: colors.waitlistSurface,
  }[status];
}

export function rsvpButtonBackground(status: RSVPStatus, colors: ThemeColors): string {
  return { yes: colors.brand, maybe: colors.maybeFill, no: colors.noFill, waitlist: colors.waitlistSurface }[status];
}

export function rsvpButtonForeground(status: RSVPStatus, colors: ThemeColors): string {
  return { yes: colors.onBrand, maybe: colors.onMaybe, no: colors.onBrand, waitlist: colors.waitlist }[status];
}

export const positionLabel: Record<FootballPosition, StringKey> = {
  GK: 'position.goalkeeper', DEF: 'position.defender', MID: 'position.midfielder',
  FWD: 'position.forward', ANY: 'position.any',
};

export const positionShortLabel: Record<FootballPosition, StringKey> = {
  GK: 'position.goalkeeper.short', DEF: 'position.defender.short', MID: 'position.midfielder.short',
  FWD: 'position.forward.short', ANY: 'position.any.short',
};

export const matchStatusLabel: Record<MatchStatus, StringKey> = {
  scheduled: 'match.scheduled', locked: 'match.locked', finished: 'match.finished', cancelled: 'match.cancelled',
};

export const tierLabel: Record<CardTier, StringKey> = {
  bronze: 'tier.bronze', silver: 'tier.silver', gold: 'tier.gold', elite: 'tier.elite',
};

export const playerTitleLabel: Record<PreviewPlayerTitle, StringKey> = {
  wall: 'title.wall', scorer: 'title.scorer', everPresent: 'title.everPresent', mvpMachine: 'title.mvpMachine',
};
