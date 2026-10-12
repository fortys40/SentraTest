import type { ReactNode } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { useTranslation, type StringKey } from '@/core/i18n';
import { useReduceMotion } from '@/core/theme/accessibility';
import { Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';
import type { AppError } from '@/core/utilities/AppError';

import { Icon, type IconName } from './Icon';
import { SentraSecondaryButton } from './SentraButtons';

export function SentraEmptyState({ title, icon = 'pitch' }: { title: StringKey; icon?: IconName }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  return (
    <View accessible style={styles.state}>
      <Icon name={icon} size={34} color={colors.primary} />
      <Text style={[Typography.bodyStrong, styles.message, { color: colors.ink }]}>{t(title)}</Text>
    </View>
  );
}

export function ErrorStateView({ error, retry }: { error: AppError; retry: () => void }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  return (
    <View style={styles.state}>
      <Icon name="warning" size={34} color={colors.danger} />
      <Text style={[Typography.body, styles.message, { color: colors.ink }]}>{t(error.messageKey)}</Text>
      <SentraSecondaryButton title="action.retry" onPress={retry} />
    </View>
  );
}

/** Covers its content while loading so it cannot be used or read by assistive technology. */
export function LoadingOverlay({ isLoading, children }: { isLoading: boolean; children?: ReactNode }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const reduceMotion = useReduceMotion();
  return (
    <View>
      <View
        pointerEvents={isLoading ? 'none' : 'auto'}
        accessibilityElementsHidden={isLoading}
        importantForAccessibility={isLoading ? 'no-hide-descendants' : 'auto'}
      >
        {children}
      </View>
      {isLoading ? (
        <View
          accessible
          accessibilityLabel={t('state.loading')}
          style={[StyleSheet.absoluteFill, styles.overlay, { backgroundColor: colors.surface }]}
        >
          {reduceMotion ? (
            <Icon name="hourglass" size={22} color={colors.primary} />
          ) : (
            <ActivityIndicator color={colors.primary} />
          )}
          <Text style={[Typography.bodyStrong, { color: colors.ink }]}>{t('state.loading')}</Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  state: { alignItems: 'center', alignSelf: 'stretch', gap: Spacing.large, paddingVertical: Spacing.xLarge },
  message: { textAlign: 'center' },
  overlay: { alignItems: 'center', justifyContent: 'center', gap: Spacing.medium },
});
