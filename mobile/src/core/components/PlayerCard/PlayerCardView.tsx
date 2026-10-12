import { useState } from 'react';
import { StyleSheet, Text, View, type LayoutChangeEvent } from 'react-native';
import { GestureDetector } from 'react-native-gesture-handler';
import Animated, { useAnimatedProps, type SharedValue } from 'react-native-reanimated';
import Svg, { ClipPath, Defs, G, LinearGradient, Path, Polygon, Rect, Stop } from 'react-native-svg';

import { useTranslation, type StringKey } from '@/core/i18n';
import { playerTitleLabel, positionLabel, positionShortLabel } from '@/core/theme/labels';
import { themeColors, useAccessibilityTextSize } from '@/core/theme/SentraTheme';
import type { PlayerCardExample } from '@/models';

import { Icon } from '../Icon';
import { initials } from '../SentraPrimitives';
import { useCardMotion, type CardMotionMode } from './CardMotion';
import { CardPortraitView } from './CardPortraitView';
import { cardTierStyle, playerCardAppearance, showsOverall, type CardTierStyle } from './CardTierStyle';
import { portraitAspectRatio, type CardPhoto, type PhotoCrop } from './PhotoCrop';
import { CardGradients, CardMaterial, cardShapePoints, portraitFramePath } from './SentraCardShape';

export type PlayerCardSize = 'small' | 'medium' | 'large';
export const playerCardWidths: Record<PlayerCardSize, number> = { small: 240, medium: 320, large: 400 };

const AnimatedRect = Animated.createAnimatedComponent(Rect);

function CardBackground({
  style,
  width,
  height,
  shine,
  shineOpacity,
}: {
  style: CardTierStyle;
  width: number;
  height: number;
  shine: SharedValue<number>;
  shineOpacity: number;
}) {
  const outline = cardShapePoints(width, height);
  const shineProps = useAnimatedProps(() => ({ x: width * (2.4 * shine.value - 0.6) }), [width]);
  return (
    <Svg width={width} height={height} style={StyleSheet.absoluteFill} pointerEvents="none">
      <Defs>
        <CardGradients style={style} />
        <LinearGradient id="bevel" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={style.highlight} stopOpacity={0.7} />
          <Stop offset="0.5" stopColor={style.highlight} stopOpacity={0} />
          <Stop offset="1" stopColor={style.highlight} stopOpacity={0} />
        </LinearGradient>
        <LinearGradient id="shine" x1="0" y1="0" x2="1" y2="0">
          <Stop offset="0" stopColor={style.highlight} stopOpacity={0} />
          <Stop offset="0.48" stopColor={style.highlight} stopOpacity={1} />
          <Stop offset="1" stopColor={style.highlight} stopOpacity={0} />
        </LinearGradient>
        <ClipPath id="card">
          <Polygon points={outline} />
        </ClipPath>
      </Defs>
      <G clipPath="url(#card)">
        <CardMaterial style={style} width={width} height={height} />
        {/* The shine stays behind the content so text contrast is unaffected. */}
        <G transform="skewX(-22)">
          <AnimatedRect
            animatedProps={shineProps}
            y={0}
            width={width * 0.45}
            height={height}
            fill="url(#shine)"
            opacity={shineOpacity}
          />
        </G>
        {/* Strokes are doubled and clipped so they sit inside the silhouette. */}
        <Polygon points={outline} fill="none" stroke="url(#metal)" strokeWidth={3.4} />
        <Polygon points={outline} fill="none" stroke="url(#bevel)" strokeWidth={2} />
      </G>
      <Polygon points={cardShapePoints(width, height, 5)} fill="none" stroke="url(#metal)" strokeWidth={0.75} />
    </Svg>
  );
}

function flag(countryCode: string): string | null {
  const code = countryCode.toUpperCase();
  if (!/^[A-Z]{2}$/.test(code)) return null;
  return String.fromCodePoint(...Array.from(code).map((letter) => 127_397 + letter.charCodeAt(0)));
}

export function PlayerCardView({
  example,
  photo = null,
  size = 'medium',
  isPlayerOfTheWeek = false,
  reliability = null,
  countryCode,
  groupColor = themeColors('light').brand,
  motion = 'device',
  onCropChange,
}: {
  example: PlayerCardExample;
  photo?: CardPhoto | null;
  size?: PlayerCardSize;
  isPlayerOfTheWeek?: boolean;
  /** 0...1. Not part of the deployed stats view, so live callers pass nothing. */
  reliability?: number | null;
  countryCode?: string;
  groupColor?: string;
  motion?: CardMotionMode;
  onCropChange?: (crop: PhotoCrop) => void;
}) {
  const { t, locale } = useTranslation();
  const largeText = useAccessibilityTextSize();
  const [layout, setLayout] = useState({ width: playerCardWidths[size], height: playerCardWidths[size] * 1.5 });
  const { gesture, tiltStyle, shine, reduceMotion } = useCardMotion(motion);

  const appearance = playerCardAppearance(example.overall, example.stats.appearances, isPlayerOfTheWeek);
  const style = cardTierStyle(appearance);
  const small = size === 'small';
  const horizontalPadding = small ? 18 : 24;
  const contentWidth = Math.max(layout.width - horizontalPadding * 2, 0);
  const portraitWidth = contentWidth * 0.68;
  const portraitHeight = portraitWidth / portraitAspectRatio;
  const ink = { color: style.ink };
  const countryFlag = countryCode ? flag(countryCode) : null;

  const onLayout = ({ nativeEvent }: LayoutChangeEvent) => {
    const { width, height } = nativeEvent.layout;
    if (Math.abs(width - layout.width) > 0.5 || Math.abs(height - layout.height) > 0.5) setLayout({ width, height });
  };

  const rating = (
    <View style={styles.rating}>
      {showsOverall(appearance) ? (
        <Text
          accessibilityLabel={t('card.overall', example.overall)}
          numberOfLines={1}
          adjustsFontSizeToFit
          minimumFontScale={0.65}
          style={[styles.numeric, ink, { fontSize: small ? 39 : 52 }]}
        >
          {example.overall}
        </Text>
      ) : null}
      <Text accessibilityLabel={t(positionLabel[example.profile.position])} style={[styles.position, ink]}>
        {t(positionShortLabel[example.profile.position])}
      </Text>
      {countryFlag ? (
        <Text accessibilityLabel={countryCode?.toUpperCase()} style={styles.flag}>
          {countryFlag}
        </Text>
      ) : null}
    </View>
  );

  const percent = (value: number) => `${Math.round(value)}%`;
  const statistics: [StringKey, StringKey, string | null][] = [
    ['card.appearances', 'card.appearances.full', String(example.stats.appearances)],
    ['card.winPercentage', 'card.winPercentage.full',
      example.stats.winPercentage ? percent(example.stats.winPercentage.toNumber()) : null],
    ['card.mvp', 'card.mvp.full', String(example.stats.mvpCount)],
    ['card.goals', 'card.goals.full', String(example.stats.goals)],
  ];
  if (!small) {
    statistics.push(
      ['card.streak.short', 'card.streak.full', String(example.stats.currentStreak)],
      ['card.reliability.short', 'card.reliability.full',
        reliability !== null && reliability >= 0 && reliability <= 1 ? percent(reliability * 100) : null],
    );
  }
  const columns = largeText ? 2 : small ? 4 : 6;

  return (
    <View style={[styles.sizing, { maxWidth: playerCardWidths[size] }]}>
      <GestureDetector gesture={gesture}>
        <Animated.View onLayout={onLayout} style={[styles.card, { minHeight: layout.width * 1.5 }, tiltStyle]}>
          <CardBackground
            style={style}
            width={layout.width}
            height={layout.height}
            shine={shine}
            shineOpacity={reduceMotion ? 0.06 : appearance === 'playerOfTheWeek' ? 0.18 : 0.12}
          />
          <View style={[styles.content, { paddingHorizontal: horizontalPadding }]}>
            {largeText ? rating : null}
            <View style={{ height: contentWidth / 1.18 }}>
              <View style={styles.portrait}>
                <CardPortraitView
                  key={photo?.id ?? 'initials'}
                  name={example.profile.displayName}
                  photo={photo}
                  style={style}
                  width={portraitWidth}
                  height={portraitHeight}
                  onCropChange={onCropChange}
                />
              </View>
              {largeText ? null : <View style={[styles.ratingSlot, { width: contentWidth * 0.17 }]}>{rating}</View>}
            </View>
            <View style={styles.identity}>
              <Text
                accessibilityLabel={example.profile.displayName}
                style={[styles.name, ink, { fontSize: small ? 17 : 20 }]}
              >
                {example.profile.displayName.toLocaleUpperCase(locale)}
              </Text>
              {small ? null : <Text style={[styles.label, ink]}>{t(playerTitleLabel[example.title])}</Text>}
              {appearance === 'provisional' ? (
                <Text style={[styles.label, styles.emphasis, ink]}>{t('card.provisional')}</Text>
              ) : appearance === 'playerOfTheWeek' ? (
                <Text style={[styles.label, styles.emphasis, ink]}>{t('card.playerOfTheWeek')}</Text>
              ) : null}
            </View>
            <View style={[styles.rule, { backgroundColor: style.accent }]} />
            <View style={styles.statistics}>
              {statistics.map(([title, fullTitle, value]) => (
                <View
                  key={title}
                  accessible
                  accessibilityLabel={t(fullTitle)}
                  accessibilityValue={{ text: value ?? t('card.statUnavailable') }}
                  style={[styles.statistic, { width: `${100 / columns}%` }]}
                >
                  <Text numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.8} style={[styles.label, ink]}>
                    {t(title)}
                  </Text>
                  <Text
                    numberOfLines={1}
                    adjustsFontSizeToFit
                    minimumFontScale={0.8}
                    style={[styles.numeric, ink, { fontSize: small ? 17 : 20 }]}
                  >
                    {value ?? t('card.noResult.short')}
                  </Text>
                </View>
              ))}
            </View>
            <View style={styles.footer}>
              {example.badges.slice(0, 3).map((badge) => (
                <Text key={badge.id} accessibilityLabel={badge.nameEL} style={{ fontSize: small ? 16 : 18 }}>
                  {badge.emoji}
                </Text>
              ))}
              <View accessible accessibilityLabel={example.groupName} style={styles.groupShield}>
                <Svg width={25} height={29} style={StyleSheet.absoluteFill}>
                  <Defs>
                    <CardGradients style={style} />
                  </Defs>
                  <Path d={portraitFramePath(25, 29, 0.75)} fill="url(#material)" stroke={groupColor} strokeWidth={1.5} />
                </Svg>
                <Text allowFontScaling={false} style={[styles.groupInitials, ink]}>
                  {initials(example.groupName)}
                </Text>
              </View>
              <View style={styles.brand}>
                <Icon name="football" size={13} color={style.ink} />
                <Text style={[styles.label, styles.brandName, ink]}>{t('app.name')}</Text>
              </View>
            </View>
          </View>
        </Animated.View>
      </GestureDetector>
    </View>
  );
}

const styles = StyleSheet.create({
  sizing: { width: '100%', alignSelf: 'center' },
  card: {
    justifyContent: 'center',
    shadowColor: '#000000',
    shadowOpacity: 0.16,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
  },
  content: { gap: 8, paddingTop: 30, paddingBottom: 46 },
  portrait: { alignItems: 'center', paddingTop: 18 },
  ratingSlot: { position: 'absolute', left: 0, top: 24 },
  rating: { alignItems: 'center', gap: 2 },
  numeric: { fontWeight: '800', fontVariant: ['tabular-nums'], textAlign: 'center' },
  position: { fontSize: 12, fontWeight: '800' },
  flag: { fontSize: 18 },
  identity: { alignItems: 'center', gap: 3 },
  name: { fontWeight: '800', textAlign: 'center' },
  label: { fontSize: 12, fontWeight: '500', textAlign: 'center' },
  emphasis: { fontWeight: '600' },
  rule: { height: 0.75, opacity: 0.55 },
  statistics: { flexDirection: 'row', flexWrap: 'wrap', rowGap: 10 },
  statistic: { alignItems: 'center', gap: 3, paddingHorizontal: 2 },
  footer: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8 },
  groupShield: { width: 25, height: 29, alignItems: 'center', justifyContent: 'center' },
  groupInitials: { fontSize: 9, fontWeight: '700' },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  brandName: { fontWeight: '700' },
});
