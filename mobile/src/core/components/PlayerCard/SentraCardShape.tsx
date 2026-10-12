import { Ellipse, G, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

import { metalStops, type CardTierStyle } from './CardTierStyle';

// The original Sentra silhouette: angled shoulders, a central top notch and a
// chevron base. Vertices are fractions of the bounding box.
const cardVertices: readonly (readonly [number, number])[] = [
  [0.04, 0.065], [0.19, 0.025], [0.41, 0.025], [0.5, 0.049], [0.59, 0.025], [0.81, 0.025],
  [0.96, 0.065], [0.94, 0.855], [0.83, 0.92], [0.5, 0.987], [0.17, 0.92], [0.06, 0.855],
];

/** SVG polygon points for the card outline, optionally inset on every side. */
export function cardShapePoints(width: number, height: number, inset = 0): string {
  const w = width - inset * 2;
  const h = height - inset * 2;
  return cardVertices.map(([x, y]) => `${inset + x * w},${inset + y * h}`).join(' ');
}

/** SVG path for the matching portrait shield, optionally inset on every side. */
export function portraitFramePath(width: number, height: number, inset = 0): string {
  const w = width - inset * 2;
  const h = height - inset * 2;
  const p = (x: number, y: number) => `${inset + x * w} ${inset + y * h}`;
  return [
    `M ${p(0.06, 0.08)}`,
    `L ${p(0.21, 0.025)}`,
    `Q ${p(0.5, 0)} ${p(0.79, 0.025)}`,
    `L ${p(0.94, 0.08)}`,
    `L ${p(0.89, 0.73)}`,
    `Q ${p(0.84, 0.865)} ${p(0.5, 0.985)}`,
    `Q ${p(0.16, 0.865)} ${p(0.11, 0.73)}`,
    'Z',
  ].join(' ');
}

/** Gradient definitions shared by every card surface. Place inside `<Defs>`. */
export function CardGradients({ style }: { style: CardTierStyle }) {
  return (
    <>
      <LinearGradient id="material" x1="0" y1="0" x2="1" y2="1">
        <Stop offset="0" stopColor={style.top} />
        <Stop offset="0.5" stopColor={style.middle} />
        <Stop offset="1" stopColor={style.bottom} />
      </LinearGradient>
      <LinearGradient id="metal" x1="0" y1="0" x2="1" y2="1">
        {metalStops(style).map((stop) => (
          <Stop key={stop.offset} offset={stop.offset} stopColor={stop.color} />
        ))}
      </LinearGradient>
    </>
  );
}

/**
 * The tier material: gradient plus deterministic brushed or marble grain and
 * faint chevrons. Requires `CardGradients` in the same SVG.
 */
export function CardMaterial({ style, width, height }: { style: CardTierStyle; width: number; height: number }) {
  let fine = '';
  let bold = '';
  for (let index = 0; index < 56; index += 1) {
    const offset = index / 55;
    const line = style.hasMarbleTexture
      ? `M ${-width * 0.2} ${offset * height} C ${width * 0.33} ${(offset - 0.07) * height} ` +
        `${width * 0.68} ${(offset + 0.16) * height} ${width * 1.2} ${(offset + 0.1) * height} `
      : `M 0 ${offset * height} L ${width} ${(offset + 0.035) * height} `;
    if (index % 5 === 0) bold += line;
    else fine += line;
  }
  let chevrons = '';
  for (let index = 0; index < 7; index += 1) {
    const level = index * height * 0.15;
    chevrons += `M 0 ${level} L ${width / 2} ${level + height * 0.13} L ${width} ${level} `;
  }
  return (
    <G>
      <Rect x={0} y={0} width={width} height={height} fill="url(#material)" />
      <Path d={fine} fill="none" stroke={style.accent} strokeOpacity={0.035} strokeWidth={0.35} />
      <Path d={bold} fill="none" stroke={style.accent} strokeOpacity={0.1} strokeWidth={0.65} />
      <Path d={chevrons} fill="none" stroke={style.accent} strokeOpacity={0.09} strokeWidth={0.7} />
    </G>
  );
}

/** One laurel branch for the crest, drawn as leaves along an arc. */
export function LaurelBranch({ color, mirrored = false }: { color: string; mirrored?: boolean }) {
  const leaves = [85, 120, 155, 190, 225].map((degrees) => {
    const angle = (degrees * Math.PI) / 180;
    return { x: 14 + Math.cos(angle) * 10.5, y: 15 + Math.sin(angle) * 10.5, rotation: degrees + 55 };
  });
  return (
    <G transform={mirrored ? 'translate(28 0) scale(-1 1)' : undefined}>
      {leaves.map((leaf) => (
        <Ellipse
          key={leaf.rotation}
          cx={leaf.x}
          cy={leaf.y}
          rx={4.2}
          ry={1.7}
          fill={color}
          transform={`rotate(${leaf.rotation} ${leaf.x} ${leaf.y})`}
        />
      ))}
    </G>
  );
}
