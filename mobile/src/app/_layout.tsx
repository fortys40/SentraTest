import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

import { LocaleProvider } from '@/core/i18n';
import { ThemeProvider, useTheme } from '@/core/theme/SentraTheme';
import { record } from '@/core/utilities/Logger';
import { EnvironmentProvider, previewEnvironment } from '@/environment/AppEnvironment';
import { makeMockDataset } from '@/services/mock/MockDataFactory';

function ThemedStack() {
  const { colors, scheme } = useTheme();
  return (
    <>
      <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.background },
          headerTintColor: colors.primary,
          headerTitleStyle: { color: colors.ink },
          headerShadowVisible: false,
          headerBackButtonDisplayMode: 'minimal',
          contentStyle: { backgroundColor: colors.background },
        }}
      />
    </>
  );
}

export default function RootLayout() {
  // The app always launches into the offline preview: no credentials are read
  // and no network client is constructed.
  const [environment] = useState(() => {
    record('preview_started');
    return previewEnvironment(makeMockDataset(new Date()));
  });
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <LocaleProvider>
        <ThemeProvider>
          <EnvironmentProvider environment={environment}>
            <ThemedStack />
          </EnvironmentProvider>
        </ThemeProvider>
      </LocaleProvider>
    </GestureHandlerRootView>
  );
}
