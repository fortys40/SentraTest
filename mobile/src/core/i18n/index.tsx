import { getLocales } from 'expo-localization';
import { createContext, useContext, useMemo, type ReactNode } from 'react';

import el from './el.json';
import en from './en.json';

export type StringKey = keyof typeof el;
export type AppLocale = 'el' | 'en';

const catalogs: Record<AppLocale, Record<string, string>> = { el, en };

export function translate(locale: AppLocale, key: StringKey, ...values: (string | number)[]): string {
  const template = catalogs[locale][key] ?? catalogs.el[key] ?? key;
  return template.replace(/\{(\d+)\}/g, (placeholder, index) => {
    const value = values[Number(index)];
    return value === undefined ? placeholder : String(value);
  });
}

/** Fixture text is Greek regardless of the interface language. */
export function greek(key: StringKey): string {
  return translate('el', key);
}

/** Greek is the development language: it is used unless the device prefers English first. */
export function deviceLocale(): AppLocale {
  for (const { languageCode } of getLocales()) {
    if (languageCode === 'el' || languageCode === 'en') return languageCode;
  }
  return 'el';
}

type Translator = (key: StringKey, ...values: (string | number)[]) => string;

const LocaleContext = createContext<AppLocale>('el');

export function LocaleProvider({ locale, children }: { locale?: AppLocale; children: ReactNode }) {
  const resolved = useMemo(() => locale ?? deviceLocale(), [locale]);
  return <LocaleContext.Provider value={resolved}>{children}</LocaleContext.Provider>;
}

export function useLocale(): AppLocale {
  return useContext(LocaleContext);
}

export function useTranslation(): { t: Translator; locale: AppLocale } {
  const locale = useLocale();
  return useMemo(() => ({ locale, t: (key, ...values) => translate(locale, key, ...values) }), [locale]);
}
