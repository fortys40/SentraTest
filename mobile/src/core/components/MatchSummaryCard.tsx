import { StyleSheet, Text, View } from 'react-native';

import { useTranslation } from '@/core/i18n';
import { matchStatusLabel } from '@/core/theme/labels';
import { Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';
import { euros, matchDate } from '@/core/utilities/DateFormatters';
import type { Match, MatchRSVPCounts, Profile } from '@/models';

import { Icon } from './Icon';
import { SentraAvatar, SentraCard } from './SentraPrimitives';

export function MatchSummaryCard({
  match,
  groupName,
  counts,
  players = [],
}: {
  match: Match;
  groupName: string;
  counts: MatchRSVPCounts | null;
  players?: Profile[];
}) {
  const { colors } = useTheme();
  const { t, locale } = useTranslation();
  const confirmed = counts ? t('match.confirmed', counts.yesCount, match.capacity) : '';
  const progress = counts ? Math.min(counts.yesCount / Math.max(match.capacity, 1), 1) : 0;
  return (
    <SentraCard>
      <View style={styles.content}>
        <View style={styles.summary}>
          <Text style={[Typography.caption, { color: colors.mutedInk }]}>{groupName}</Text>
          <View style={styles.labelRow}>
            <Icon name="calendar" size={18} color={colors.ink} />
            <Text style={[Typography.heading, styles.flexible, { color: colors.ink }]}>
              {matchDate(match.startsAt, locale)}
            </Text>
          </View>
          <View style={styles.labelRow}>
            <Icon name="location" size={14} color={colors.mutedInk} />
            <Text style={[Typography.caption, styles.flexible, { color: colors.mutedInk }]}>{match.venue}</Text>
          </View>
        </View>
        <View style={styles.metadata}>
          <Text style={[Typography.bodyStrong, { color: colors.ink }]}>{match.format}</Text>
          <Text style={[Typography.caption, { color: colors.mutedInk }]}>{t(matchStatusLabel[match.status])}</Text>
        </View>
        {counts ? (
          <View style={styles.summary}>
            <View style={styles.occupancy}>
              <View style={styles.attendees}>
                {players.slice(0, 4).map((player, index) => (
                  <View key={player.id} style={index > 0 ? styles.overlap : null}>
                    <SentraAvatar name={player.displayName} size={28} borderColor={colors.surface} />
                  </View>
                ))}
              </View>
              <Text style={[Typography.caption, styles.confirmed, { color: colors.ink }]}>{confirmed}</Text>
            </View>
            <View
              accessible
              accessibilityRole="progressbar"
              accessibilityLabel={confirmed}
              accessibilityValue={{ min: 0, max: match.capacity, now: counts.yesCount }}
              style={[styles.track, { backgroundColor: colors.surfaceMuted }]}
            >
              <View style={[styles.fill, { backgroundColor: colors.brand, width: `${progress * 100}%` }]} />
            </View>
          </View>
        ) : null}
        {match.expectedCost ? (
          <View style={styles.cost}>
            <Text style={[Typography.caption, styles.flexible, { color: colors.ink }]}>{t('match.expectedCost')}</Text>
            <Text style={[Typography.bodyStrong, { color: colors.ink }]}>{euros(match.expectedCost, locale)}</Text>
          </View>
        ) : null}
      </View>
    </SentraCard>
  );
}

const styles = StyleSheet.create({
  content: { gap: Spacing.large },
  summary: { gap: Spacing.small },
  labelRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.small },
  flexible: { flexShrink: 1 },
  metadata: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: Spacing.medium },
  occupancy: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: Spacing.medium },
  attendees: { flexDirection: 'row' },
  overlap: { marginLeft: -6 },
  confirmed: { flexGrow: 1, textAlign: 'right' },
  track: { height: 4, borderRadius: 2, overflow: 'hidden' },
  fill: { height: 4, borderRadius: 2 },
  cost: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: Spacing.small },
});
