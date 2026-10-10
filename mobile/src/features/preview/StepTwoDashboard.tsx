import { Stack, useRouter } from 'expo-router';
import { useState } from 'react';
import { ImageBackground, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Icon } from '@/core/components/Icon';
import { MatchSummaryCard } from '@/core/components/MatchSummaryCard';
import { MenuSheet, type MenuItem } from '@/core/components/MenuSheet';
import { PlayerCardShell } from '@/core/components/PlayerCardShell';
import { PlayerRow } from '@/core/components/PlayerRow';
import { RSVPButton, SentraSecondaryButton } from '@/core/components/SentraButtons';
import {
  SentraAvatar,
  SentraChip,
  SentraProgressHeader,
  SentraSectionHeader,
  SentraSegmentedControl,
  SentraSegmentedTabs,
} from '@/core/components/SentraPrimitives';
import { ErrorStateView, LoadingOverlay, SentraEmptyState } from '@/core/components/StateViews';
import { useTranslation, type StringKey } from '@/core/i18n';
import { positionLabel } from '@/core/theme/labels';
import {
  Layout,
  Spacing,
  ThemeOverride,
  Typography,
  useAccessibilityTextSize,
  useTheme,
  type AppearancePreference,
} from '@/core/theme/SentraTheme';
import { AppError } from '@/core/utilities/AppError';
import type { UUID } from '@/core/utilities/SentraJSON';
import { useEnvironment } from '@/environment/AppEnvironment';
import { routeHref, type AppRoute } from '@/environment/AppRoute';
import { playerCardExampleID, type RSVPStatus } from '@/models';

import { useDashboard, type DashboardSnapshot } from './dashboardModel';

const rosterTabs = ['players', 'waitlist', 'other'] as const;
type RosterTab = (typeof rosterTabs)[number];

const rosterStatuses: Record<RosterTab, readonly RSVPStatus[]> = {
  players: ['yes'],
  waitlist: ['waitlist'],
  other: ['maybe', 'no'],
};

const appearances = ['system', 'light', 'dark'] as const satisfies readonly AppearancePreference[];
const sampleStates = ['empty', 'loading', 'error'] as const;
type SampleState = (typeof sampleStates)[number];

/**
 * The offline component dashboard. Every selection here is local visual state:
 * nothing sends an RSVP, submits a vote or advances a workflow.
 */
export function StepTwoDashboard() {
  const environment = useEnvironment();
  const router = useRouter();
  const { colors, preference, setPreference } = useTheme();
  const { t } = useTranslation();
  const largeText = useAccessibilityTextSize();
  const { state, reload } = useDashboard(environment);
  const [sampleSelection, setSampleSelection] = useState<RSVPStatus | null>('yes');
  const [sampleState, setSampleState] = useState<SampleState>('empty');
  const [rosterTab, setRosterTab] = useState<RosterTab>('players');
  const [sampleMVP, setSampleMVP] = useState<UUID | null>(environment.previewData?.profiles[1]?.id ?? null);
  const [menuVisible, setMenuVisible] = useState(false);

  const open = (route: AppRoute) => router.push(routeHref(route));
  const menu: MenuItem[] = [
    { title: 'route.groups', icon: 'groups', onPress: () => open({ name: 'groups' }) },
    { title: 'route.createGroup', icon: 'add', onPress: () => open({ name: 'createGroup' }) },
    { title: 'route.profile', icon: 'profile', onPress: () => open({ name: 'profile' }) },
    { title: 'route.settings', icon: 'settings', onPress: () => open({ name: 'settings' }) },
  ];
  // The card gallery stands in for Xcode previews and is not part of the product.
  if (__DEV__) menu.push({ title: 'preview.cards', icon: 'cards', onPress: () => router.push('/dev/cards') });

  const mvpRow = (id: UUID, name: string, detail: StringKey) => {
    const selected = sampleMVP === id;
    return (
      <Pressable
        key={id}
        accessibilityRole="radio"
        accessibilityState={{ selected }}
        onPress={() => setSampleMVP(selected ? null : id)}
        style={[styles.mvpRow, { borderBottomColor: 'rgba(244, 248, 245, 0.12)' }]}
      >
        <SentraAvatar name={name} />
        <View style={styles.mvpNames}>
          <Text style={[Typography.bodyStrong, { color: colors.onMVP }]}>{name}</Text>
          <Text style={[Typography.caption, { color: colors.mutedMVP }]}>{t(detail)}</Text>
        </View>
        <Icon name={selected ? 'yes' : 'circle'} size={22} color={selected ? colors.mvpAccent : colors.mutedMVP} />
      </Pressable>
    );
  };

  const content = (snapshot: DashboardSnapshot) => {
    const count = (tab: RosterTab) =>
      snapshot.responses.filter((entry) => rosterStatuses[tab].includes(entry.response.status)).length;
    const confirmed = snapshot.profiles.filter((profile) =>
      snapshot.responses.some((entry) => entry.response.userID === profile.id && entry.response.status === 'yes'),
    );
    return (
      <>
        <View style={styles.section}>
          <View style={styles.headerRow}>
            <SentraSectionHeader title="preview.nextMatch" />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('action.clearSelection')}
              accessibilityState={{ disabled: sampleSelection === null }}
              disabled={sampleSelection === null}
              onPress={() => setSampleSelection(null)}
              style={[styles.tool, { opacity: sampleSelection === null ? 0.4 : 1 }]}
            >
              <Icon name="undo" size={22} color={colors.primary} />
            </Pressable>
          </View>
          <MatchSummaryCard
            match={snapshot.match}
            groupName={snapshot.group.name}
            counts={snapshot.counts}
            players={confirmed}
          />
          <View style={styles.rsvpStack}>
            {(['yes', 'maybe', 'no'] as const).map((status) => (
              <RSVPButton
                key={status}
                status={status}
                isSelected={sampleSelection === status}
                onPress={() => setSampleSelection(status)}
              />
            ))}
          </View>
          <SentraSecondaryButton
            title="action.openMatch"
            icon="football"
            onPress={() => open({ name: 'matchDetail', id: snapshot.match.id })}
          />
        </View>

        <View style={[styles.roster, { backgroundColor: colors.surface }]}>
          <View style={styles.rosterInset}>
            <SentraSectionHeader title="preview.players" />
            <SentraSegmentedTabs
              options={rosterTabs}
              selection={rosterTab}
              onSelect={setRosterTab}
              label={(tab) => t(`preview.roster.${tab}`, count(tab))}
            />
          </View>
          {snapshot.responses
            .filter((entry) => rosterStatuses[rosterTab].includes(entry.response.status))
            .map((entry) => {
              const profile = snapshot.profiles.find((candidate) => candidate.id === entry.response.userID);
              const guest = snapshot.guests.find((candidate) => candidate.id === entry.response.guestID);
              return (
                <View key={entry.response.id} style={[styles.rosterRow, { borderBottomColor: colors.border }]}>
                  <PlayerRow
                    name={profile?.displayName ?? guest?.name ?? ''}
                    position={profile?.position ?? 'ANY'}
                    status={entry.response.status}
                    isGuest={guest !== undefined}
                    waitlistPosition={entry.positionInWaitlist}
                  />
                </View>
              );
            })}
        </View>

        <View style={styles.section}>
          <SentraProgressHeader
            title="route.finishMatch"
            currentStep={1}
            totalSteps={3}
            stepTitles={['progress.players', 'progress.result', 'progress.cost']}
          />
        </View>

        <ThemeOverride scheme="dark">
          <View accessibilityRole="radiogroup" style={[styles.mvp, { backgroundColor: colors.mvpSurface }]}>
            <Text accessibilityRole="header" style={[Typography.title, styles.mvpTitle, { color: colors.onMVP }]}>
              {t('preview.mvp')}
            </Text>
            {snapshot.profiles.slice(1, 6).map((profile) =>
              mvpRow(profile.id, profile.displayName, positionLabel[profile.position]),
            )}
            {snapshot.guests.map((guest) => mvpRow(guest.id, guest.name, 'player.guest'))}
          </View>
        </ThemeOverride>

        <View style={styles.section}>
          <SentraSectionHeader title="preview.cards" />
          <View style={styles.cardGrid}>
            {snapshot.cards.map((example) => (
              <View key={playerCardExampleID(example)} style={largeText ? styles.cardCellFull : styles.cardCell}>
                <PlayerCardShell example={example} />
              </View>
            ))}
          </View>
        </View>

        <View style={styles.section}>
          <SentraSectionHeader title="preview.states" />
          <SentraSegmentedControl
            title="preview.states"
            options={sampleStates}
            selection={sampleState}
            onSelect={setSampleState}
            label={(value) => `state.${value}`}
          />
          <View style={styles.stateExample}>
            {sampleState === 'empty' ? (
              <SentraEmptyState title="empty.group" />
            ) : sampleState === 'loading' ? (
              <LoadingOverlay isLoading>
                <View style={styles.loadingSample} />
              </LoadingOverlay>
            ) : (
              <ErrorStateView error={new AppError('network')} retry={() => setSampleState('empty')} />
            )}
          </View>
          <SentraSecondaryButton title="action.refresh" onPress={reload} />
        </View>
      </>
    );
  };

  return (
    <ScrollView style={{ backgroundColor: colors.background }} contentContainerStyle={styles.scroll}>
      <Stack.Screen
        options={{
          title: t('app.name'),
          headerRight: () => (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={t('action.menu')}
              onPress={() => setMenuVisible(true)}
              style={styles.tool}
            >
              <Icon name="menu" size={24} color={colors.primary} />
            </Pressable>
          ),
        }}
      />
      <MenuSheet visible={menuVisible} items={menu} onClose={() => setMenuVisible(false)} />
      <View style={styles.column}>
        <ImageBackground
          source={require('../../../assets/images/welcome-pitch.png')}
          resizeMode="cover"
          style={styles.hero}
        >
          <View accessible style={styles.heroBand}>
            <Icon name="football" size={34} color={colors.onMVP} />
            <Text style={[Typography.brand, { color: colors.onMVP }]}>{t('app.name')}</Text>
            <Text style={[Typography.bodyStrong, styles.centered, { color: colors.onMVP }]}>
              {t('preview.hero.tagline')}
            </Text>
          </View>
        </ImageBackground>

        <View style={styles.section}>
          <View style={[styles.headerRow, largeText ? styles.headerStacked : null]}>
            <SentraSectionHeader title="preview.title" />
            <SentraChip title="preview.offline" icon="offline" tint={colors.mutedInk} />
          </View>
          <SentraSegmentedControl
            title="preview.appearance"
            options={appearances}
            selection={preference}
            onSelect={setPreference}
            label={(value) => `appearance.${value}`}
          />
        </View>

        {state.status === 'loading' ? (
          <LoadingOverlay isLoading>
            <View style={styles.loadingPlaceholder} />
          </LoadingOverlay>
        ) : state.status === 'failed' ? (
          <View style={styles.section}>
            <ErrorStateView error={state.error} retry={reload} />
          </View>
        ) : (
          content(state.snapshot)
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: Spacing.xLarge },
  column: { width: '100%', maxWidth: Layout.contentWidth, alignSelf: 'center', gap: Spacing.xxLarge },
  hero: { minHeight: Layout.heroHeight },
  heroBand: {
    alignItems: 'center',
    gap: Spacing.medium,
    padding: Spacing.xxLarge,
    backgroundColor: 'rgba(6, 27, 22, 0.86)',
  },
  centered: { textAlign: 'center' },
  section: { gap: Spacing.large, paddingHorizontal: Spacing.large },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.small },
  headerStacked: { flexDirection: 'column', alignItems: 'flex-start' },
  tool: {
    width: Layout.minimumTarget,
    height: Layout.minimumTarget,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rsvpStack: { gap: Spacing.small },
  roster: { paddingVertical: Spacing.large },
  rosterInset: { gap: Spacing.small, paddingHorizontal: Spacing.large },
  rosterRow: { marginHorizontal: Spacing.large, borderBottomWidth: StyleSheet.hairlineWidth },
  mvp: { padding: Spacing.xLarge, gap: Spacing.small },
  mvpTitle: { paddingBottom: Spacing.medium },
  mvpRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.medium,
    minHeight: Layout.rowHeight,
    paddingVertical: Spacing.small,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  mvpNames: { flex: 1, gap: Spacing.tiny },
  cardGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.large },
  cardCell: { flexGrow: 1, flexBasis: Layout.cardMinimumWidth, minWidth: Layout.cardMinimumWidth },
  cardCellFull: { width: '100%' },
  stateExample: { minHeight: 220, justifyContent: 'center' },
  loadingSample: { height: 180 },
  loadingPlaceholder: { height: 220 },
});
