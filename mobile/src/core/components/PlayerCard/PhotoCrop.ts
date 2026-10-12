// Crop geometry shared by the card renderer and the photo editor. Focus x/y are
// normalized 0...1 in the upright full image (origin top-left) and name the point
// shown at the viewport centre. Zoom 1...4 multiplies the aspect-fill base scale.

export interface PhotoDimensions {
  readonly width: number;
  readonly height: number;
}

export interface NormalizedFaceRectangle {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

export interface PhotoCrop {
  readonly focusX: number;
  readonly focusY: number;
  readonly zoom: number;
}

export interface CardPhoto {
  readonly id: string;
  readonly uri: string;
  readonly dimensions: PhotoDimensions;
  readonly automaticCrop: PhotoCrop;
  readonly crop: PhotoCrop;
}

export const maximumZoom = 4;
export const portraitAspectRatio = 0.9;
export const defaultViewport: PhotoDimensions = { width: 240, height: 240 / portraitAspectRatio };

const clamp = (value: number, lower: number, upper: number) => Math.min(Math.max(value, lower), upper);

function isValidDimensions(size: PhotoDimensions): boolean {
  return Number.isFinite(size.width) && Number.isFinite(size.height) && size.width > 0 && size.height > 0;
}

function isValidFace(face: NormalizedFaceRectangle): boolean {
  return (
    [face.x, face.y, face.width, face.height].every(Number.isFinite) &&
    face.x >= 0 && face.y >= 0 && face.width > 0 && face.height > 0 &&
    face.x + face.width <= 1 && face.y + face.height <= 1
  );
}

/** Eyes sit roughly 38% down a detected face rectangle. */
export function estimatedEyesY(face: NormalizedFaceRectangle): number {
  return face.y + face.height * 0.38;
}

/** Builds a crop whose values are always finite and in range. */
export function photoCrop(focusX: number, focusY: number, zoom: number): PhotoCrop {
  return {
    focusX: Number.isFinite(focusX) ? clamp(focusX, 0, 1) : 0.5,
    focusY: Number.isFinite(focusY) ? clamp(focusY, 0, 1) : 0.5,
    zoom: Number.isFinite(zoom) ? clamp(zoom, 1, maximumZoom) : 1,
  };
}

export const centerCrop: PhotoCrop = { focusX: 0.5, focusY: 0.5, zoom: 1 };

export function displayedSize(image: PhotoDimensions, viewport: PhotoDimensions, zoom: number): PhotoDimensions {
  if (!isValidDimensions(image) || !isValidDimensions(viewport)) return { width: 1, height: 1 };
  const safeZoom = Number.isFinite(zoom) ? clamp(zoom, 1, maximumZoom) : 1;
  const scale = Math.max(viewport.width / image.width, viewport.height / image.height) * safeZoom;
  return { width: image.width * scale, height: image.height * scale };
}

/** Clamps the focus so the image always covers the whole viewport. */
export function constrained(
  crop: PhotoCrop,
  image: PhotoDimensions,
  viewport: PhotoDimensions = defaultViewport,
): PhotoCrop {
  if (!isValidDimensions(image) || !isValidDimensions(viewport)) return centerCrop;
  const safe = photoCrop(crop.focusX, crop.focusY, crop.zoom);
  const size = displayedSize(image, viewport, safe.zoom);
  const horizontalMargin = Math.min(viewport.width / (2 * size.width), 0.5);
  const verticalMargin = Math.min(viewport.height / (2 * size.height), 0.5);
  return photoCrop(
    clamp(safe.focusX, horizontalMargin, 1 - horizontalMargin),
    clamp(safe.focusY, verticalMargin, 1 - verticalMargin),
    safe.zoom,
  );
}

/**
 * Frames the largest valid face with its eyes at 40% of the viewport height and
 * the face filling 48% of it. Without a face the image is centred.
 */
export function automaticCrop(
  image: PhotoDimensions,
  faces: readonly NormalizedFaceRectangle[],
  viewport: PhotoDimensions = defaultViewport,
): PhotoCrop {
  const face = faces
    .filter(isValidFace)
    .reduce<NormalizedFaceRectangle | null>(
      (largest, candidate) =>
        !largest || candidate.width * candidate.height > largest.width * largest.height ? candidate : largest,
      null,
    );
  if (!isValidDimensions(image) || !isValidDimensions(viewport) || !face) {
    return constrained(centerCrop, image, viewport);
  }
  const base = displayedSize(image, viewport, 1);
  const zoom = clamp((viewport.height * 0.48) / (face.height * base.height), 1, maximumZoom);
  const size = displayedSize(image, viewport, zoom);
  const focusY = estimatedEyesY(face) + ((0.5 - 0.4) * viewport.height) / size.height;
  return constrained(photoCrop(face.x + face.width / 2, focusY, zoom), image, viewport);
}

export function panned(
  crop: PhotoCrop,
  horizontal: number,
  vertical: number,
  image: PhotoDimensions,
  viewport: PhotoDimensions,
): PhotoCrop {
  if (!Number.isFinite(horizontal) || !Number.isFinite(vertical)) return constrained(crop, image, viewport);
  const size = displayedSize(image, viewport, crop.zoom);
  return constrained(
    photoCrop(crop.focusX - horizontal / size.width, crop.focusY - vertical / size.height, crop.zoom),
    image,
    viewport,
  );
}

export function zoomed(
  crop: PhotoCrop,
  magnification: number,
  image: PhotoDimensions,
  viewport: PhotoDimensions = defaultViewport,
): PhotoCrop {
  if (!Number.isFinite(magnification) || magnification <= 0) return constrained(crop, image, viewport);
  return constrained(photoCrop(crop.focusX, crop.focusY, crop.zoom * magnification), image, viewport);
}

/** The viewport y coordinate at which a normalized image y is drawn. */
export function projectedY(
  normalizedY: number,
  crop: PhotoCrop,
  image: PhotoDimensions,
  viewport: PhotoDimensions = defaultViewport,
): number {
  const safe = constrained(crop, image, viewport);
  const size = displayedSize(image, viewport, safe.zoom);
  return viewport.height / 2 + (normalizedY - safe.focusY) * size.height;
}
