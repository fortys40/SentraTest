import Slider from '@react-native-community/slider';
import * as ImagePicker from 'expo-image-picker';
import { useRef, useState } from 'react';
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useTranslation, type StringKey } from '@/core/i18n';
import { Layout, Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';
import type { PlayerCardExample } from '@/models';
import { preparePhoto, type PhotoSource } from '@/services/local/PhotoCropService';

import { SentraPrimaryButton, SentraSecondaryButton } from '../SentraButtons';
import { constrained, maximumZoom, photoCrop, zoomed, type CardPhoto, type PhotoCrop } from './PhotoCrop';
import { PlayerCardView } from './PlayerCardView';

/**
 * Local photo editor. Save hands the draft back to the caller in memory only:
 * nothing is uploaded, written to the library or saved to a profile.
 */
export function PhotoAdjustView({
  example,
  photo,
  onSave,
  onCancel,
}: {
  example: PlayerCardExample;
  photo: CardPhoto | null;
  onSave: (photo: CardPhoto) => void;
  onCancel: () => void;
}) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const [draft, setDraft] = useState(photo);
  const [source, setSource] = useState<PhotoSource | null>(photo ? { uri: photo.uri } : null);
  const [isLoading, setIsLoading] = useState(false);
  // Only the newest operation may change the draft; a stale result is dropped.
  const operation = useRef(0);

  const updateCrop = (crop: PhotoCrop) =>
    setDraft((current) => (current ? { ...current, crop: constrained(crop, current.dimensions) } : current));

  const prepare = async (next: PhotoSource) => {
    const id = ++operation.current;
    setIsLoading(true);
    try {
      const prepared = await preparePhoto(next);
      if (operation.current !== id) return;
      setSource(next);
      setDraft(prepared);
    } catch {
      // A failure keeps the last good draft.
      if (operation.current === id) Alert.alert(t('card.photo.error'), undefined, [{ text: t('card.photo.ok') }]);
    } finally {
      if (operation.current === id) setIsLoading(false);
    }
  };

  const choose = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 1, exif: false });
    const asset = result.canceled ? null : result.assets[0];
    if (asset) await prepare({ uri: asset.uri, fileSize: asset.fileSize });
  };

  const slider = (title: StringKey, value: number, minimum: number, maximum: number, change: (value: number) => void) => (
    <View style={styles.control}>
      <Text style={[Typography.caption, { color: colors.ink }]}>{t(title)}</Text>
      <Slider
        accessibilityLabel={t(title)}
        style={styles.slider}
        value={value}
        minimumValue={minimum}
        maximumValue={maximum}
        minimumTrackTintColor={colors.brand}
        maximumTrackTintColor={colors.border}
        onValueChange={change}
      />
    </View>
  );

  return (
    <SafeAreaView style={[styles.screen, { backgroundColor: colors.background }]}>
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <Pressable accessibilityRole="button" onPress={onCancel} style={styles.cancel}>
          <Text style={[Typography.body, { color: colors.primary }]}>{t('card.photo.cancel')}</Text>
        </Pressable>
        <Text accessibilityRole="header" style={[Typography.heading, styles.title, { color: colors.ink }]}>
          {t('card.photo.adjust')}
        </Text>
      </View>
      <ScrollView contentContainerStyle={styles.content}>
        <SentraSecondaryButton title="card.photo.choose" icon="photos" disabled={isLoading} onPress={() => void choose()} />
        <PlayerCardView
          example={example}
          photo={draft}
          size="large"
          motion="disabled"
          onCropChange={isLoading ? undefined : updateCrop}
        />
        {isLoading ? (
          <View accessible style={styles.processing}>
            <ActivityIndicator color={colors.primary} />
            <Text style={[Typography.body, { color: colors.ink }]}>{t('card.photo.processing')}</Text>
          </View>
        ) : null}
        {draft ? (
          <View pointerEvents={isLoading ? 'none' : 'auto'} style={[styles.controls, { opacity: isLoading ? 0.5 : 1 }]}>
            {slider('card.photo.zoom', draft.crop.zoom, 1, maximumZoom, (value) =>
              updateCrop(zoomed(draft.crop, value / draft.crop.zoom, draft.dimensions)),
            )}
            {slider('card.photo.horizontal', draft.crop.focusX, 0, 1, (value) =>
              updateCrop(photoCrop(value, draft.crop.focusY, draft.crop.zoom)),
            )}
            {slider('card.photo.vertical', draft.crop.focusY, 0, 1, (value) =>
              updateCrop(photoCrop(draft.crop.focusX, value, draft.crop.zoom)),
            )}
          </View>
        ) : null}
        <SentraSecondaryButton
          title="card.photo.reset"
          icon="reset"
          disabled={!source || isLoading}
          onPress={() => source && void prepare(source)}
        />
        <SentraPrimaryButton
          title="card.photo.save"
          icon="checkmark"
          disabled={!draft || isLoading}
          onPress={() => draft && onSave(draft)}
        />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: {
    minHeight: Layout.minimumTarget,
    justifyContent: 'center',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  cancel: {
    position: 'absolute',
    left: Spacing.large,
    zIndex: 1,
    minHeight: Layout.minimumTarget,
    justifyContent: 'center',
  },
  title: { textAlign: 'center', paddingHorizontal: 96 },
  content: { gap: Spacing.large, padding: Spacing.large, width: '100%', maxWidth: 440, alignSelf: 'center' },
  processing: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: Spacing.small },
  controls: { gap: Spacing.medium },
  control: { gap: Spacing.tiny },
  slider: { minHeight: Layout.minimumTarget },
});
