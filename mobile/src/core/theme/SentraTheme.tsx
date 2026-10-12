import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import { useColorScheme, useWindowDimensions, type TextStyle } from 'react-native';

export type ColorScheme = 'light' | 'dark';
export type AppearancePreference = 'system' | ColorScheme;

// [light, dark] pairs. Every enabled text pair is checked at 4.5:1 or better.
const adaptive = {
  background: ['#F5F7F5', '#101A15'],
  surface: ['#FFFFFF', '#1A2720'],
  surfaceMuted: ['#EDF2EE', '#26382D'],
  ink: ['#17271D', '#F4F8F5'],
  mutedInk: ['#58665D', '#B6C9BE'],
  primary: ['#007B45', '#7BDCAE'],
  onPrimary: ['#FFFFFF', '#08251A'],
  warning: ['#735000', '#FFD16B'],
  danger: ['#B92E43', '#FFA5B1'],
  waitlist: ['#3F5D74', '#BAD2E4'],
  border: ['#D8E1DA', '#40564A'],
  yesSurface: ['#E5F5EB', '#153D29'],
  maybeSurface: ['#FFF3D6', '#423519'],
  noSurface: ['#FFE8EC', '#47242C'],
  waitlistSurface: ['#E6EFF5', '#273D48'],
} as const;

const solid = {
  brand: '#00864A',
  darkGreen: '#00482E',
  onBrand: '#FFFFFF',
  maybeFill: '#FFD16B',
  onMaybe: '#473204',
  noFill: '#D12F46',
  mvpSurface: '#061B16',
  mvpRaised: '#0D2B23',
  onMVP: '#F4F8F5',
  mutedMVP: '#B6CEC1',
  mvpAccent: '#79E2AE',
  premiumSurface: '#111B18',
  onPremium: '#FCF6E6',
  bronze: '#DBB18A',
  silver: '#D3E0E5',
  gold: '#E5C875',
  elite: '#F4DB91',
} as const;

export type ThemeColors = Record<keyof typeof adaptive | keyof typeof solid, string>;

export function themeColors(scheme: ColorScheme): ThemeColors {
  const index = scheme === 'dark' ? 1 : 0;
  const resolved = Object.fromEntries(Object.entries(adaptive).map(([name, pair]) => [name, pair[index]]));
  return { ...resolved, ...solid } as ThemeColors;
}

export const Typography = {
  brand: { fontSize: 34, fontWeight: '800', fontStyle: 'italic' },
  title: { fontSize: 22, fontWeight: '700' },
  heading: { fontSize: 17, fontWeight: '700' },
  body: { fontSize: 17 },
  bodyStrong: { fontSize: 17, fontWeight: '600' },
  caption: { fontSize: 12, fontWeight: '500' },
  cardName: { fontSize: 20, fontWeight: '700' },
  rating: { fontSize: 34, fontWeight: '800' },
} as const satisfies Record<string, TextStyle>;

export const Spacing = { tiny: 4, small: 8, medium: 12, large: 16, xLarge: 24, xxLarge: 32, section: 40 } as const;

export const Radius = { control: 8, card: 8 } as const;

export const Shadow = {
  shadowColor: '#000000',
  shadowOpacity: 0.06,
  shadowRadius: 10,
  shadowOffset: { width: 0, height: 4 },
  elevation: 2,
} as const;

export const Motion = { brief: 180 } as const;

export const Layout = {
  minimumTarget: 44,
  buttonHeight: 52,
  rowHeight: 60,
  avatarSize: 40,
  heroHeight: 360,
  cardMinimumWidth: 280,
  contentWidth: 880,
} as const;

interface ThemeValue {
  readonly scheme: ColorScheme;
  readonly colors: ThemeColors;
  readonly preference: AppearancePreference;
  readonly setPreference: (preference: AppearancePreference) => void;
}

const ThemeContext = createContext<ThemeValue | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const system = useColorScheme();
  const [preference, setPreference] = useState<AppearancePreference>('system');
  const scheme: ColorScheme = preference === 'system' ? (system === 'dark' ? 'dark' : 'light') : preference;
  const value = useMemo(
    () => ({ scheme, colors: themeColors(scheme), preference, setPreference }),
    [scheme, preference],
  );
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeValue {
  const theme = useContext(ThemeContext);
  if (!theme) throw new Error('useTheme requires a ThemeProvider');
  return theme;
}

/** Forces a colour scheme for a subtree, such as the always-dark MVP band. */
export function ThemeOverride({ scheme, children }: { scheme: ColorScheme; children: ReactNode }) {
  const parent = useTheme();
  const value = useMemo(() => ({ ...parent, scheme, colors: themeColors(scheme) }), [parent, scheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

/** True at the system's accessibility text sizes, where rows stack vertically. */
export function useAccessibilityTextSize(): boolean {
  return useWindowDimensions().fontScale > 1.4;
}
