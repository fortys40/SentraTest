import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { useTranslation, type StringKey } from '@/core/i18n';
import { useReduceMotion } from '@/core/theme/accessibility';
import { rsvpButtonBackground, rsvpButtonForeground, rsvpIcon, rsvpLabel } from '@/core/theme/labels';
import { Layout, Radius, Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';
import type { RSVPStatus } from '@/models';

import { Icon, type IconName } from './Icon';

type Kind = 'primary' | 'secondary' | 'destructive';

interface ButtonProps {
  title: StringKey;
  icon?: IconName;
  disabled?: boolean;
  onPress: () => void;
}

function SentraButton({
  kind,
  title,
  icon,
  isLoading = false,
  disabled = false,
  onPress,
}: ButtonProps & { kind: Kind; icon: IconName; isLoading?: boolean }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const reduceMotion = useReduceMotion();
  const foreground = kind === 'secondary' ? colors.ink : colors.onBrand;
  const background =
    kind === 'secondary' ? colors.surface : kind === 'destructive' ? colors.noFill : colors.brand;
  const inactive = disabled || isLoading;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={t(title)}
      accessibilityState={{ disabled: inactive, busy: isLoading }}
      disabled={inactive}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: background, opacity: inactive ? 0.5 : pressed ? 0.8 : 1 },
        kind === 'secondary' ? { borderWidth: 1, borderColor: colors.border } : null,
      ]}
    >
      {/* The icon slot keeps its size while loading so the title never moves. */}
      <View style={styles.iconSlot}>
        {isLoading && !reduceMotion ? (
          <ActivityIndicator color={foreground} />
        ) : (
          <Icon name={isLoading ? 'hourglass' : icon} size={20} color={foreground} />
        )}
      </View>
      <Text style={[Typography.bodyStrong, styles.title, { color: foreground }]}>{t(title)}</Text>
    </Pressable>
  );
}

export function SentraPrimaryButton({
  icon = 'forward',
  isLoading,
  ...props
}: ButtonProps & { isLoading?: boolean }) {
  return <SentraButton kind="primary" icon={icon} isLoading={isLoading} {...props} />;
}

export function SentraSecondaryButton({ icon = 'refresh', ...props }: ButtonProps) {
  return <SentraButton kind="secondary" icon={icon} {...props} />;
}

export function SentraDestructiveButton({ icon = 'trash', ...props }: ButtonProps) {
  return <SentraButton kind="destructive" icon={icon} {...props} />;
}

/**
 * Clients request yes, maybe or no only. Waitlist is a database outcome, so its
 * button is always disabled when shown.
 */
export function RSVPButton({
  status,
  isSelected = false,
  onPress,
}: {
  status: RSVPStatus;
  isSelected?: boolean;
  onPress: () => void;
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const foreground = rsvpButtonForeground(status, colors);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={t(rsvpLabel[status])}
      accessibilityState={{ selected: isSelected, disabled: status === 'waitlist' }}
      disabled={status === 'waitlist'}
      onPress={onPress}
      style={[styles.rsvp, { backgroundColor: rsvpButtonBackground(status, colors) }]}
    >
      {/* Selection adds an inset outline and a checkmark, never colour alone. */}
      <View
        pointerEvents="none"
        style={[styles.rsvpOutline, { borderColor: foreground, opacity: isSelected ? 0.8 : 0 }]}
      />
      <View style={styles.iconSlot}>
        <Icon name={rsvpIcon[status]} size={20} color={foreground} />
      </View>
      <Text style={[Typography.bodyStrong, styles.rsvpTitle, { color: foreground }]}>{t(rsvpLabel[status])}</Text>
      <View style={[styles.iconSlot, { opacity: isSelected ? 1 : 0 }]}>
        <Icon name="checkmark" size={20} color={foreground} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'stretch',
    gap: Spacing.medium,
    minHeight: Layout.buttonHeight,
    paddingHorizontal: Spacing.large,
    paddingVertical: Spacing.medium,
    borderRadius: Radius.control,
  },
  iconSlot: { width: 22, height: 22, alignItems: 'center', justifyContent: 'center' },
  title: { textAlign: 'center', flexShrink: 1 },
  rsvp: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'stretch',
    gap: Spacing.small,
    minHeight: Layout.buttonHeight,
    padding: Spacing.medium,
    borderRadius: Radius.control,
  },
  rsvpOutline: {
    position: 'absolute',
    top: 3,
    right: 3,
    bottom: 3,
    left: 3,
    borderWidth: 1,
    borderRadius: Radius.control - 2,
  },
  rsvpTitle: { flex: 1, textAlign: 'center' },
});
