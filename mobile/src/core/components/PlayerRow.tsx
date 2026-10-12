import { StyleSheet, Text, View } from 'react-native';

import { useTranslation } from '@/core/i18n';
import { positionLabel } from '@/core/theme/labels';
import { Layout, Spacing, Typography, useAccessibilityTextSize, useTheme } from '@/core/theme/SentraTheme';
import type { FootballPosition, RSVPStatus } from '@/models';

import { SentraAvatar, SentraStatusBadge } from './SentraPrimitives';

export function PlayerRow({
  name,
  position = 'ANY',
  status,
  isGuest = false,
  waitlistPosition = null,
}: {
  name: string;
  position?: FootballPosition;
  status: RSVPStatus | null;
  isGuest?: boolean;
  /** The dense queue position from the database view, never the raw ordering ticket. */
  waitlistPosition?: number | null;
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const stacked = useAccessibilityTextSize();
  return (
    <View accessible style={[styles.row, stacked ? styles.stacked : null]}>
      <View style={styles.identity}>
        <SentraAvatar name={name} />
        <View style={styles.names}>
          <Text style={[Typography.bodyStrong, { color: colors.ink }]}>{name}</Text>
          <Text style={[Typography.caption, { color: colors.mutedInk }]}>
            {t(isGuest ? 'player.guest' : positionLabel[position])}
          </Text>
        </View>
      </View>
      {status ? (
        <View style={styles.status}>
          <SentraStatusBadge status={status} />
          {status === 'waitlist' && waitlistPosition !== null ? (
            <Text style={[Typography.caption, { color: colors.mutedInk }]}>
              {t('waitlist.position', waitlistPosition)}
            </Text>
          ) : null}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.medium,
    minHeight: Layout.rowHeight,
    paddingVertical: Spacing.small,
  },
  stacked: { flexDirection: 'column', alignItems: 'flex-start', gap: Spacing.small },
  identity: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: Spacing.medium },
  names: { flex: 1, gap: Spacing.tiny },
  status: { gap: Spacing.tiny },
});
