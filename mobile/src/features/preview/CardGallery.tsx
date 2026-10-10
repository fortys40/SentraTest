import { Asset } from 'expo-asset';
import { useEffect, useState, type ReactNode } from 'react';
import { Modal, ScrollView, StyleSheet, Text, View } from 'react-native';
import Svg, { Defs, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

import { playerCardAppearances, type PlayerCardAppearance } from '@/core/components/PlayerCard/CardTierStyle';
import { PhotoAdjustView } from '@/core/components/PlayerCard/PhotoAdjustView';
import type { CardPhoto } from '@/core/components/PlayerCard/PhotoCrop';
import { PlayerCardView, playerCardWidths, type PlayerCardSize } from '@/core/components/PlayerCard/PlayerCardView';
import { SentraPrimaryButton } from '@/core/components/SentraButtons';
import { useTranslation, type StringKey } from '@/core/i18n';
import { tierLabel } from '@/core/theme/labels';
import { Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';
import { cardTier, type PlayerCardExample } from '@/models';
import { preparePhoto } from '@/services/local/PhotoCropService';
import { makeMockDataset } from '@/services/mock/MockDataFactory';

// Development-only gallery covering the card matrix: six appearances, four
// sample photos and initials, three sizes, the share backdrop and the editor.

const samplePhotos = {
  closeUp: require('../../../assets/images/card-photo-closeup.jpg'),
  outdoor: require('../../../assets/images/card-photo-outdoor.jpg'),
  busy: require('../../../assets/images/card-photo-busy.jpg'),
  lowLight: require('../../../assets/images/card-photo-lowlight.jpg'),
} as const;
type SamplePhoto = keyof typeof samplePhotos;
const sampleNames = Object.keys(samplePhotos) as SamplePhoto[];

const dataset = makeMockDataset();
const overalls: Record<PlayerCardAppearance, number> = {
  bronze: 63, silver: 71, gold: 82, elite: 90, playerOfTheWeek: 92, provisional: 64,
};

function example(appearance: PlayerCardAppearance = 'gold'): PlayerCardExample {
  const source = dataset.cardExamples[2];
  const overall = overalls[appearance];
  const provisional = appearance === 'provisional';
  return {
    ...source,
    overall,
    stats: provisional
      ? { ...source.stats, appearances: 2, wins: 1, losses: 0, draws: 0, goals: 1, mvpCount: 0, currentStreak: 2 }
      : source.stats,
    design: { id: `sample.${appearance}`, tier: cardTier(overall) },
    badges: provisional ? [] : dataset.badgeDefinitions,
  };
}

function appearanceLabel(appearance: PlayerCardAppearance): StringKey {
  if (appearance === 'playerOfTheWeek') return 'card.playerOfTheWeek';
  if (appearance === 'provisional') return 'card.sample.provisional';
  return tierLabel[appearance];
}

async function loadSample(name: SamplePhoto): Promise<CardPhoto> {
  const asset = Asset.fromModule(samplePhotos[name]);
  await asset.downloadAsync();
  return preparePhoto({ uri: asset.localUri ?? asset.uri });
}

/** Night-stadium backdrop for the share composition. No export or share flow exists yet. */
export function StadiumCardBackdrop({ width, height }: { width: number; height: number }) {
  let terraces = '';
  for (let index = 0; index < 12; index += 1) {
    const baseline = height * (0.69 + index * 0.025);
    terraces += `M 0 ${baseline} L ${width} ${baseline} `;
  }
  const top = height * 0.12;
  return (
    <Svg width={width} height={height} style={StyleSheet.absoluteFill}>
      <Defs>
        <LinearGradient id="night" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#060F11" />
          <Stop offset="1" stopColor="#0A261B" />
        </LinearGradient>
        <LinearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#FFFFFF" stopOpacity={0.15} />
          <Stop offset="0.75" stopColor="#FFFFFF" stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Rect width={width} height={height} fill="url(#night)" />
      <Path d={terraces} stroke="#FFFFFF" strokeOpacity={0.035} strokeWidth={1} />
      {[0.08, 0.92].map((side) => {
        const x = width * side;
        return (
          <Path
            key={side}
            d={`M ${x - 14} ${top} L ${x + 14} ${top} L ${width * 0.75} ${height * 0.9} L ${width * 0.25} ${height * 0.9} Z`}
            fill="url(#beam)"
          />
        );
      })}
      {[0.08, 0.92].map((side) => (
        <Rect key={side} x={width * side - 15} y={top - 3} width={30} height={6} rx={1} fill="#FFFFFF" fillOpacity={0.8} />
      ))}
      <Path
        d={`M ${width * 0.32} ${height * 0.8} L ${width * 0.68} ${height * 0.8} L ${width * 1.2} ${height * 1.08} L ${width * -0.2} ${height * 1.08} Z`}
        fill="none"
        stroke="#FFFFFF"
        strokeOpacity={0.18}
        strokeWidth={1.5}
      />
    </Svg>
  );
}

function Shelf({ title, children }: { title: string; children: ReactNode }) {
  const { colors } = useTheme();
  return (
    <View style={styles.shelf}>
      <Text accessibilityRole="header" style={[Typography.heading, styles.inset, { color: colors.ink }]}>
        {title}
      </Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.shelfContent}>
        {children}
      </ScrollView>
    </View>
  );
}

function Labeled({ label, width, children }: { label: string; width: number; children: ReactNode }) {
  const { colors } = useTheme();
  return (
    <View style={[styles.labeled, { width }]}>
      <Text style={[Typography.caption, { color: colors.mutedInk }]}>{label}</Text>
      {children}
    </View>
  );
}

export function CardGallery() {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const [photos, setPhotos] = useState<Partial<Record<SamplePhoto, CardPhoto>>>({});
  const [failed, setFailed] = useState(false);
  const [editorPhoto, setEditorPhoto] = useState<CardPhoto | null>(null);
  const [showsEditor, setShowsEditor] = useState(false);

  useEffect(() => {
    let mounted = true;
    void (async () => {
      try {
        for (const name of sampleNames) {
          const photo = await loadSample(name);
          if (!mounted) return;
          setPhotos((current) => ({ ...current, [name]: photo }));
          if (name === 'outdoor') setEditorPhoto(photo);
        }
      } catch {
        if (mounted) setFailed(true);
      }
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const medium = playerCardWidths.medium;
  const stadium = { width: 360, height: 640 };
  return (
    <ScrollView style={{ backgroundColor: colors.background }} contentContainerStyle={styles.screen}>
      {failed ? <Text style={[Typography.body, styles.inset, { color: colors.danger }]}>{t('card.sample.error')}</Text> : null}

      <Shelf title={t('preview.cards')}>
        {playerCardAppearances.map((appearance) => (
          <Labeled key={appearance} label={t(appearanceLabel(appearance))} width={medium}>
            <PlayerCardView
              example={example(appearance)}
              photo={photos.closeUp}
              isPlayerOfTheWeek={appearance === 'playerOfTheWeek'}
              reliability={0.92}
              countryCode="GR"
              motion="preview"
            />
          </Labeled>
        ))}
      </Shelf>

      <Shelf title={t('card.photo.choose')}>
        {sampleNames.map((name) => (
          <Labeled key={name} label={t(`card.sample.${name}`)} width={medium}>
            <PlayerCardView example={example()} photo={photos[name]} reliability={0.92} motion="disabled" />
          </Labeled>
        ))}
        <Labeled label={t('card.sample.noPhoto')} width={medium}>
          <PlayerCardView example={example()} motion="disabled" />
        </Labeled>
      </Shelf>

      <Shelf title="240 · 320 · 400">
        {(Object.keys(playerCardWidths) as PlayerCardSize[]).map((size) => (
          <Labeled key={size} label={String(playerCardWidths[size])} width={playerCardWidths[size]}>
            <PlayerCardView example={example()} photo={photos.closeUp} size={size} reliability={0.92} motion="disabled" />
          </Labeled>
        ))}
      </Shelf>

      <View style={styles.shelf}>
        <Text accessibilityRole="header" style={[Typography.heading, styles.inset, { color: colors.ink }]}>
          {t('card.playerOfTheWeek')}
        </Text>
        <View style={[styles.stadium, stadium]}>
          <StadiumCardBackdrop {...stadium} />
          <View style={styles.stadiumCard}>
            <PlayerCardView
              example={example('playerOfTheWeek')}
              photo={photos.closeUp}
              size="large"
              isPlayerOfTheWeek
              reliability={0.92}
              countryCode="GR"
              motion="preview"
            />
          </View>
        </View>
      </View>

      <View style={[styles.shelf, styles.inset]}>
        <Text accessibilityRole="header" style={[Typography.heading, { color: colors.ink }]}>
          {t('card.photo.adjust')}
        </Text>
        <PlayerCardView example={example()} photo={editorPhoto} motion="disabled" />
        <SentraPrimaryButton title="card.photo.adjust" icon="adjust" onPress={() => setShowsEditor(true)} />
      </View>

      <Modal visible={showsEditor} animationType="slide" presentationStyle="pageSheet" onRequestClose={() => setShowsEditor(false)}>
        <PhotoAdjustView
          example={example()}
          photo={editorPhoto}
          onCancel={() => setShowsEditor(false)}
          onSave={(photo) => {
            setEditorPhoto(photo);
            setShowsEditor(false);
          }}
        />
      </Modal>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { gap: Spacing.xxLarge, paddingVertical: Spacing.xLarge },
  shelf: { gap: Spacing.medium },
  shelfContent: { gap: Spacing.large, paddingHorizontal: Spacing.large, paddingTop: Spacing.small, paddingBottom: Spacing.xLarge },
  inset: { paddingHorizontal: Spacing.large },
  labeled: { gap: Spacing.medium, alignItems: 'center' },
  stadium: { alignSelf: 'center', overflow: 'hidden', justifyContent: 'center' },
  stadiumCard: { paddingHorizontal: 28 },
});
