import { Stack, useLocalSearchParams } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { SentraEmptyState } from '@/core/components/StateViews';
import { useTranslation } from '@/core/i18n';
import { Spacing, useTheme } from '@/core/theme/SentraTheme';
import { isAppRouteName, routeTitleKey } from '@/environment/AppRoute';

/** Shared placeholder for all fourteen routes until their steps are authorized. */
export default function PlaceholderScreen() {
  const { name } = useLocalSearchParams<{ name: string }>();
  const { colors } = useTheme();
  const { t } = useTranslation();
  return (
    <View style={[styles.screen, { backgroundColor: colors.background }]}>
      <Stack.Screen options={{ title: isAppRouteName(name) ? t(routeTitleKey(name)) : '' }} />
      <SentraEmptyState title="error.unavailable" icon="clock" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, justifyContent: 'center', padding: Spacing.large },
});
