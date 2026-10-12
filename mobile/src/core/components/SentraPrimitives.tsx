import type { ReactNode } from 'react';
import { Image, Pressable, StyleSheet, Text, View, type ImageSourcePropType } from 'react-native';

import type { StringKey } from '@/core/i18n';
import { useTranslation } from '@/core/i18n';
import { rsvpChipBackground, rsvpColor, rsvpIcon, rsvpLabel } from '@/core/theme/labels';
import {
  Layout,
  Radius,
  Shadow,
  Spacing,
  Typography,
  useAccessibilityTextSize,
  useTheme,
} from '@/core/theme/SentraTheme';
import type { RSVPStatus } from '@/models';

import { Icon, type IconName } from './Icon';

/** First letters of the first two words, for avatar and crest fallbacks. */
export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((word) => Array.from(word)[0])
    .join('')
    .toUpperCase();
}

export function SentraCard({ children }: { children: ReactNode }) {
  const { colors } = useTheme();
  return (
    <View style={[styles.card, Shadow, { backgroundColor: colors.surface, borderColor: colors.border }]}>
      {children}
    </View>
  );
}

export function SentraSectionHeader({ title }: { title: StringKey }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  return (
    <Text accessibilityRole="header" style={[Typography.heading, styles.sectionHeader, { color: colors.ink }]}>
      {t(title)}
    </Text>
  );
}

export function SentraChip({
  title,
  icon,
  tint,
  background,
}: {
  title: StringKey;
  icon: IconName;
  tint?: string;
  background?: string;
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const foreground = tint ?? colors.primary;
  return (
    <View accessible style={[styles.chip, { backgroundColor: background ?? `${foreground}1A` }]}>
      <Icon name={icon} size={14} color={foreground} />
      <Text style={[Typography.caption, { color: foreground }]}>{t(title)}</Text>
    </View>
  );
}

export function SentraStatusBadge({ status }: { status: RSVPStatus }) {
  const { colors } = useTheme();
  return (
    <SentraChip
      title={rsvpLabel[status]}
      icon={rsvpIcon[status]}
      tint={rsvpColor(status, colors)}
      background={rsvpChipBackground(status, colors)}
    />
  );
}

export function SentraAvatar({
  name,
  image,
  size = Layout.avatarSize,
  borderColor,
}: {
  name: string;
  image?: ImageSourcePropType;
  size?: number;
  borderColor?: string;
}) {
  const { colors } = useTheme();
  const letters = initials(name);
  return (
    <View
      accessible
      accessibilityLabel={name}
      style={[
        styles.avatar,
        { width: size, height: size, borderRadius: size / 2, backgroundColor: colors.surfaceMuted },
        borderColor ? { borderWidth: 2, borderColor } : null,
      ]}
    >
      {image ? (
        <Image source={image} style={StyleSheet.absoluteFill} resizeMode="cover" />
      ) : letters ? (
        <Text allowFontScaling={false} style={{ fontSize: size * 0.34, fontWeight: '600', color: colors.primary }}>
          {letters}
        </Text>
      ) : (
        <Icon name="person" size={size * 0.5} color={colors.primary} />
      )}
    </View>
  );
}

export function SentraProgressHeader({
  title,
  currentStep,
  totalSteps,
  stepTitles = [],
}: {
  title: StringKey;
  currentStep: number;
  totalSteps: number;
  stepTitles?: StringKey[];
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const stacked = useAccessibilityTextSize();
  const total = Math.max(totalSteps, 1);
  const current = Math.min(Math.max(currentStep, 0), total);
  const markerSize = 24;
  const steps = Array.from({ length: total }, (_, index) => index + 1);

  const marker = (step: number) => (
    <View
      style={[
        styles.marker,
        { width: markerSize, height: markerSize, borderRadius: markerSize / 2 },
        { backgroundColor: step <= current ? colors.brand : colors.surfaceMuted },
      ]}
    >
      {step < current ? (
        <Icon name="checkmark" size={14} color={colors.onBrand} />
      ) : (
        <Text
          allowFontScaling={false}
          style={[Typography.caption, { color: step <= current ? colors.onBrand : colors.mutedInk }]}
        >
          {step}
        </Text>
      )}
    </View>
  );
  const stepTitle = (step: number) =>
    stepTitles[step - 1] ? (
      <Text style={[Typography.caption, { color: colors.ink, textAlign: stacked ? 'left' : 'center' }]}>
        {t(stepTitles[step - 1])}
      </Text>
    ) : null;

  const summary = t('progress.steps', current, total);
  return (
    <View accessible accessibilityLabel={`${t(title)}, ${summary}`} style={styles.progress}>
      <Text accessibilityRole="header" style={[Typography.heading, { color: colors.ink }]}>
        {t(title)}
      </Text>
      <Text style={[Typography.caption, { color: colors.mutedInk }]}>{summary}</Text>
      {stacked ? (
        <View style={styles.progress}>
          {steps.map((step) => (
            <View key={step} style={styles.stackedStep}>
              {marker(step)}
              {stepTitle(step)}
            </View>
          ))}
        </View>
      ) : (
        <View style={styles.stepRow}>
          {steps.map((step) => (
            <View key={step} style={styles.stepGroup}>
              <View style={styles.step}>
                {marker(step)}
                {stepTitle(step)}
              </View>
              {step < total ? (
                <View
                  style={[
                    styles.connector,
                    { marginTop: markerSize / 2 - 1 },
                    { backgroundColor: step < current ? colors.brand : colors.border },
                  ]}
                />
              ) : null}
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

/** Equal-emphasis text tabs with a selected underline, as on the roster screen. */
export function SentraSegmentedTabs<Option extends string>({
  options,
  selection,
  onSelect,
  label,
}: {
  options: readonly Option[];
  selection: Option;
  onSelect: (option: Option) => void;
  label: (option: Option) => string;
}) {
  const { colors } = useTheme();
  const stacked = useAccessibilityTextSize();
  return (
    <View
      accessibilityRole="tablist"
      style={[stacked ? styles.tabsStacked : styles.tabs, { borderBottomColor: colors.border }]}
    >
      {options.map((option) => {
        const selected = option === selection;
        return (
          <Pressable
            key={option}
            accessibilityRole="tab"
            accessibilityState={{ selected }}
            onPress={() => onSelect(option)}
            style={[styles.tab, stacked ? null : styles.tabFlexible]}
          >
            <Text
              style={[Typography.caption, styles.tabLabel, { color: selected ? colors.primary : colors.mutedInk }]}
            >
              {label(option)}
            </Text>
            <View style={[styles.tabUnderline, { backgroundColor: selected ? colors.primary : 'transparent' }]} />
          </Pressable>
        );
      })}
    </View>
  );
}

/** A compact exclusive choice; it stacks vertically at accessibility text sizes. */
export function SentraSegmentedControl<Option extends string>({
  title,
  options,
  selection,
  onSelect,
  label,
}: {
  title: StringKey;
  options: readonly Option[];
  selection: Option;
  onSelect: (option: Option) => void;
  label: (option: Option) => StringKey;
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const stacked = useAccessibilityTextSize();
  return (
    <View
      accessibilityRole="radiogroup"
      accessibilityLabel={t(title)}
      style={[styles.segments, stacked ? styles.segmentsStacked : null, { backgroundColor: colors.surfaceMuted }]}
    >
      {options.map((option) => {
        const selected = option === selection;
        return (
          <Pressable
            key={option}
            accessibilityRole="radio"
            accessibilityState={{ selected }}
            onPress={() => onSelect(option)}
            style={[
              styles.segment,
              stacked ? null : styles.tabFlexible,
              selected ? [Shadow, { backgroundColor: colors.surface }] : null,
            ]}
          >
            <Text style={[Typography.caption, styles.tabLabel, { color: selected ? colors.ink : colors.mutedInk }]}>
              {t(label(option))}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    padding: Spacing.large,
    borderRadius: Radius.card,
    borderWidth: StyleSheet.hairlineWidth,
    alignSelf: 'stretch',
  },
  sectionHeader: { flex: 1 },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: Spacing.tiny,
    paddingHorizontal: Spacing.small,
    paddingVertical: Spacing.tiny,
    borderRadius: 999,
  },
  avatar: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  progress: { gap: Spacing.medium },
  stackedStep: { flexDirection: 'row', alignItems: 'center', gap: Spacing.medium },
  stepRow: { flexDirection: 'row', alignItems: 'flex-start' },
  stepGroup: { flex: 1, flexDirection: 'row', alignItems: 'flex-start', gap: Spacing.small },
  step: { flex: 1, alignItems: 'center', gap: Spacing.small },
  marker: { alignItems: 'center', justifyContent: 'center' },
  connector: { width: Spacing.large, height: 2, borderRadius: 1 },
  tabs: { flexDirection: 'row', gap: Spacing.small, borderBottomWidth: StyleSheet.hairlineWidth },
  tabsStacked: { gap: Spacing.tiny, borderBottomWidth: StyleSheet.hairlineWidth },
  tab: { minHeight: Layout.minimumTarget, justifyContent: 'center' },
  tabFlexible: { flex: 1 },
  tabLabel: { textAlign: 'center', paddingHorizontal: Spacing.small, paddingVertical: Spacing.small },
  tabUnderline: { position: 'absolute', left: 0, right: 0, bottom: 0, height: 2 },
  segments: { flexDirection: 'row', padding: 2, borderRadius: Radius.control, gap: 2 },
  segmentsStacked: { flexDirection: 'column' },
  segment: { minHeight: Layout.minimumTarget - 4, justifyContent: 'center', borderRadius: Radius.control - 2 },
});
