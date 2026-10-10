import { Redirect, Stack } from 'expo-router';

import { useTranslation } from '@/core/i18n';
import { CardGallery } from '@/features/preview/CardGallery';

export default function CardGalleryScreen() {
  const { t } = useTranslation();
  if (!__DEV__) return <Redirect href="/" />;
  return (
    <>
      <Stack.Screen options={{ title: t('preview.cards') }} />
      <CardGallery />
    </>
  );
}
