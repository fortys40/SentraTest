import { useMemo, useRef } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Svg, {
  ClipPath,
  Defs,
  FeColorMatrix,
  Filter,
  G,
  Image as SvgImage,
  LinearGradient,
  Mask,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';

import { Icon } from '../Icon';
import { initials } from '../SentraPrimitives';
import { photoGradingMatrix, type CardTierStyle } from './CardTierStyle';
import { constrained, displayedSize, panned, zoomed, type CardPhoto, type PhotoCrop } from './PhotoCrop';
import { CardGradients, CardMaterial, LaurelBranch, portraitFramePath } from './SentraCardShape';

const crestWidth = 76;
const crestHeight = 34;

export function CardPortraitView({
  name,
  photo,
  style,
  width,
  height,
  onCropChange,
}: {
  name: string;
  photo: CardPhoto | null;
  style: CardTierStyle;
  width: number;
  height: number;
  /** When set, the photo can be panned and pinched inside the shield. */
  onCropChange?: (crop: PhotoCrop) => void;
}) {
  const frame = portraitFramePath(width, height);
  const viewport = { width, height };

  let image = null;
  if (photo) {
    const crop = constrained(photo.crop, photo.dimensions, viewport);
    const displayed = displayedSize(photo.dimensions, viewport, crop.zoom);
    image = {
      x: width / 2 - crop.focusX * displayed.width,
      y: height / 2 - crop.focusY * displayed.height,
      ...displayed,
    };
  }

  // Both gestures read the latest photo through a ref so a drag in progress
  // keeps measuring from the crop it started with.
  const latest = useRef({ photo, onCropChange, viewport });
  latest.current = { photo, onCropChange, viewport };
  const session = useRef<{ base: PhotoCrop; x: number; y: number; scale: number; active: number } | null>(null);
  const gesture = useMemo(() => {
    const begin = () => {
      const current = latest.current.photo;
      if (!current) return;
      if (!session.current) session.current = { base: current.crop, x: 0, y: 0, scale: 1, active: 0 };
      session.current.active += 1;
    };
    const emit = () => {
      const { photo: current, onCropChange: notify, viewport: size } = latest.current;
      if (!current || !notify || !session.current) return;
      const { base, x, y, scale } = session.current;
      notify(panned(zoomed(base, scale, current.dimensions, size), x, y, current.dimensions, size));
    };
    const finish = () => {
      if (session.current && (session.current.active -= 1) <= 0) session.current = null;
    };
    const pan = Gesture.Pan()
      .minDistance(1)
      .runOnJS(true)
      .onBegin(begin)
      .onUpdate((event) => {
        if (!session.current) return;
        session.current.x = event.translationX;
        session.current.y = event.translationY;
        emit();
      })
      .onFinalize(finish);
    const pinch = Gesture.Pinch()
      .runOnJS(true)
      .onBegin(begin)
      .onUpdate((event) => {
        if (!session.current) return;
        session.current.scale = event.scale;
        emit();
      })
      .onFinalize(finish);
    return Gesture.Simultaneous(pan, pinch);
  }, []);

  return (
    <View style={{ width, height }} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Svg width={width} height={height}>
        <Defs>
          <CardGradients style={style} />
          <LinearGradient id="fade" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor="#FFFFFF" stopOpacity={1} />
            <Stop offset="0.78" stopColor="#FFFFFF" stopOpacity={1} />
            <Stop offset="1" stopColor="#FFFFFF" stopOpacity={0} />
          </LinearGradient>
          <RadialGradient
            id="vignette"
            gradientUnits="userSpaceOnUse"
            cx={width * 0.5}
            cy={height * 0.4}
            r={Math.max(width, height) * 0.75}
          >
            <Stop offset="0" stopColor="#000000" stopOpacity={0} />
            <Stop offset="0.5" stopColor="#000000" stopOpacity={0} />
            <Stop offset="1" stopColor="#000000" stopOpacity={0.22} />
          </RadialGradient>
          <Mask id="shield" maskUnits="userSpaceOnUse" x={0} y={0} width={width} height={height}>
            <Path d={frame} fill="url(#fade)" />
          </Mask>
          <ClipPath id="frame">
            <Path d={frame} />
          </ClipPath>
          <Filter id="grading">
            <FeColorMatrix type="matrix" values={photoGradingMatrix(style).join(' ')} />
          </Filter>
        </Defs>
        <G mask="url(#shield)">
          <CardMaterial style={style} width={width} height={height} />
          {photo && image ? (
            <>
              <SvgImage
                href={{ uri: photo.uri }}
                x={image.x}
                y={image.y}
                width={image.width}
                height={image.height}
                preserveAspectRatio="none"
                filter="url(#grading)"
              />
              <Rect width={width} height={height} fill={style.photoTint} fillOpacity={style.photoTintOpacity} />
              <Rect width={width} height={height} fill="url(#vignette)" />
            </>
          ) : null}
        </G>
        <G clipPath="url(#frame)">
          {/* Soft inner shadow, then the outer metal rule drawn inside the edge. */}
          <Path d={frame} fill="none" stroke={style.ink} strokeOpacity={0.1} strokeWidth={10} transform="translate(0 3)" />
          {photo && style.appearance === 'playerOfTheWeek' ? (
            <Path d={frame} fill="none" stroke={style.highlight} strokeOpacity={0.3} strokeWidth={8} />
          ) : null}
          <Path d={frame} fill="none" stroke="url(#metal)" strokeWidth={3.6} />
        </G>
        <Path d={portraitFramePath(width, height, 4)} fill="none" stroke="url(#metal)" strokeWidth={0.65} />
      </Svg>
      {photo ? null : (
        <View style={[StyleSheet.absoluteFill, styles.centered]}>
          <Text allowFontScaling={false} style={{ fontSize: width * 0.26, fontWeight: '800', color: style.ink }}>
            {initials(name)}
          </Text>
        </View>
      )}
      {photo && onCropChange ? (
        <GestureDetector gesture={gesture}>
          <View style={StyleSheet.absoluteFill} />
        </GestureDetector>
      ) : null}
      <View pointerEvents="none" style={[styles.crest, { left: (width - crestWidth) / 2 }]}>
        <Svg width={crestWidth} height={crestHeight} style={StyleSheet.absoluteFill}>
          <Defs>
            <CardGradients style={style} />
          </Defs>
          <Path d={portraitFramePath(crestWidth, crestHeight, 0.5)} fill="url(#material)" stroke="url(#metal)" strokeWidth={1} />
          <G transform="translate(6 1)">
            <LaurelBranch color={style.ink} />
          </G>
          <G transform={`translate(${crestWidth - 34} 1)`}>
            <LaurelBranch color={style.ink} mirrored />
          </G>
        </Svg>
        <Icon name="football" size={17} color={style.ink} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { alignItems: 'center', justifyContent: 'center' },
  crest: {
    position: 'absolute',
    top: -18,
    width: crestWidth,
    height: crestHeight,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
