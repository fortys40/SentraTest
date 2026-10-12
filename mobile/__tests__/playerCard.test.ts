import {
  cardTierStyle,
  photoGradingMatrix,
  playerCardAppearance,
  playerCardAppearances,
  showsOverall,
} from '@/core/components/PlayerCard/CardTierStyle';
import {
  automaticCrop,
  centerCrop,
  constrained,
  defaultViewport,
  displayedSize,
  estimatedEyesY,
  panned,
  photoCrop,
  portraitAspectRatio,
  projectedY,
  zoomed,
} from '@/core/components/PlayerCard/PhotoCrop';
import { PhotoCropFailure, preparePhoto } from '@/services/local/PhotoCropService';

const mockRender = jest.fn();
jest.mock('expo-image-manipulator', () => ({
  SaveFormat: { JPEG: 'jpeg' },
  ImageManipulator: { manipulate: () => ({ renderAsync: mockRender, resize: mockResize }) },
}));
const mockResize = jest.fn();

function image(width: number, height: number) {
  return { width, height, saveAsync: jest.fn(async () => ({ uri: 'file:///prepared.jpg', width, height })) };
}

describe('player card appearance', () => {
  test('free tier boundaries use overall', () => {
    const cases = [[50, 'bronze'], [64, 'bronze'], [65, 'silver'], [74, 'silver'], [75, 'gold'], [84, 'gold'], [85, 'elite'], [99, 'elite']] as const;
    for (const [overall, expected] of cases) expect(playerCardAppearance(overall, 3)).toBe(expected);
  });

  test('provisional hides overall until the third appearance', () => {
    for (const appearances of [0, 1, 2]) {
      const appearance = playerCardAppearance(99, appearances);
      expect(appearance).toBe('provisional');
      expect(showsOverall(appearance)).toBe(false);
    }
    expect(showsOverall(playerCardAppearance(65, 3))).toBe(true);
  });

  test('player of the week does not override provisional', () => {
    expect(playerCardAppearance(90, 2, true)).toBe('provisional');
    expect(playerCardAppearance(63, 3, true)).toBe('playerOfTheWeek');
    expect(playerCardAppearance(63, 3, false)).toBe('bronze');
  });

  test('photo grading keeps neutral grey neutral and only provisional is strongly muted', () => {
    for (const appearance of playerCardAppearances) {
      const style = cardTierStyle(appearance);
      const matrix = photoGradingMatrix(style);
      expect(matrix).toHaveLength(20);
      const grey = [0, 1, 2].map((row) => matrix.slice(row * 5, row * 5 + 3).reduce((sum, v) => sum + v * 0.5, matrix[row * 5 + 4]));
      for (const channel of grey) expect(channel).toBeCloseTo(0.5 + style.photoBrightness, 6);
    }
    expect(cardTierStyle('provisional').photoSaturation).toBeLessThan(0.6);
    expect(cardTierStyle('gold').hasMarbleTexture).toBe(true);
    expect(cardTierStyle('bronze').hasMarbleTexture).toBe(false);
  });
});

describe('photo crop geometry', () => {
  const portrait = { width: 1_200, height: 1_800 };
  const face = { x: 0.35, y: 0.22, width: 0.25, height: 0.2 };

  test('face crop places estimated eyes at forty percent', () => {
    const crop = automaticCrop(portrait, [face]);
    expect(crop.focusX).toBeCloseTo(0.475, 6);
    expect(crop.zoom).toBeCloseTo(1.777_777_778, 6);
    const position = projectedY(estimatedEyesY(face), crop, portrait);
    expect(position / defaultViewport.height).toBeCloseTo(0.4, 6);
  });

  test('no face uses center crop and the largest face wins', () => {
    expect(automaticCrop(portrait, [])).toEqual(centerCrop);
    const small = { x: 0.1, y: 0.1, width: 0.05, height: 0.05 };
    expect(automaticCrop(portrait, [small, face])).toEqual(automaticCrop(portrait, [face]));
  });

  test('pan and zoom cannot expose empty image edges', () => {
    const landscape = { width: 2_000, height: 1_000 };
    const crop = panned(centerCrop, 10_000, -10_000, landscape, defaultViewport);
    const size = displayedSize(landscape, defaultViewport, crop.zoom);
    expect(crop.focusX).toBeCloseTo(defaultViewport.width / (2 * size.width), 6);
    expect(crop.focusY).toBeCloseTo(0.5, 6);
    expect(zoomed(crop, 100, landscape).zoom).toBe(4);
    expect(zoomed(crop, 0.01, landscape).zoom).toBe(1);
  });

  test('invalid inputs and tiny faces stay bounded', () => {
    expect(photoCrop(NaN, Infinity, -Infinity)).toEqual(centerCrop);
    expect(automaticCrop({ width: 0, height: 1 }, [])).toEqual(centerCrop);
    expect(automaticCrop(portrait, [{ x: 0.45, y: 0.4, width: 0.01, height: 0.01 }]).zoom).toBe(4);
    expect(automaticCrop(portrait, [{ x: -1, y: 0, width: 1, height: 1 }])).toEqual(centerCrop);
    expect(constrained({ focusX: 5, focusY: -5, zoom: 99 }, portrait).zoom).toBe(4);
  });

  test('crop is independent of card display size', () => {
    const small = automaticCrop(portrait, [face], { width: 120, height: 120 / portraitAspectRatio });
    const large = automaticCrop(portrait, [face], { width: 360, height: 360 / portraitAspectRatio });
    expect(small.focusX).toBeCloseTo(large.focusX, 6);
    expect(small.focusY).toBeCloseTo(large.focusY, 6);
    expect(small.zoom).toBeCloseTo(large.zoom, 6);
  });
});

describe('photo preparation', () => {
  beforeEach(() => {
    mockRender.mockReset();
    mockResize.mockReset();
  });

  test('rejects missing, oversized and undecodable input', async () => {
    await expect(preparePhoto({ uri: '' })).rejects.toBeInstanceOf(PhotoCropFailure);
    await expect(preparePhoto({ uri: 'file:///big.jpg', fileSize: 26 * 1_024 * 1_024 })).rejects.toBeInstanceOf(PhotoCropFailure);
    mockRender.mockRejectedValueOnce(new Error('not an image'));
    await expect(preparePhoto({ uri: 'file:///broken.jpg' })).rejects.toBeInstanceOf(PhotoCropFailure);
    expect(mockRender).toHaveBeenCalledTimes(1);
  });

  test('re-encodes within the size limit and centres when no face is found', async () => {
    mockRender.mockResolvedValueOnce(image(320, 240));
    const photo = await preparePhoto({ uri: 'file:///small.jpg' });
    expect(mockResize).not.toHaveBeenCalled();
    expect(photo.dimensions).toEqual({ width: 320, height: 240 });
    expect(photo.crop).toEqual(centerCrop);
    expect(photo.uri).toBe('file:///prepared.jpg');
  });

  test('limits the longest side to 2048 px and uses an injected face detector', async () => {
    mockRender.mockResolvedValueOnce(image(4_096, 3_072)).mockResolvedValueOnce(image(2_048, 1_536));
    const detector = jest.fn(async () => [{ x: 0.4, y: 0.2, width: 0.2, height: 0.3 }]);
    const photo = await preparePhoto({ uri: 'file:///large.jpg' }, detector);
    expect(mockResize).toHaveBeenCalledWith({ width: 2_048, height: 1_536 });
    expect(detector).toHaveBeenCalledWith('file:///prepared.jpg', { width: 2_048, height: 1_536 });
    expect(photo.crop).toEqual(automaticCrop({ width: 2_048, height: 1_536 }, await detector()));
    expect(photo.crop).not.toEqual(centerCrop);
  });
});
