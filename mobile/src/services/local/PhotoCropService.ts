import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';

import {
  automaticCrop,
  type CardPhoto,
  type NormalizedFaceRectangle,
  type PhotoDimensions,
} from '@/core/components/PlayerCard/PhotoCrop';

export class PhotoCropFailure extends Error {
  constructor() {
    super('invalidImage');
    this.name = 'PhotoCropFailure';
  }
}

export interface PhotoSource {
  readonly uri: string;
  readonly fileSize?: number | null;
}

/**
 * Finds faces in an upright image as normalized top-left rectangles.
 *
 * No detector ships yet: on-device face detection needs a native module that is
 * not part of Expo Go, so the default finds nothing and photos are centred.
 * Inject a detector here once the app moves to a development build.
 */
export type FaceDetector = (uri: string, dimensions: PhotoDimensions) => Promise<NormalizedFaceRectangle[]>;

const noFaces: FaceDetector = async () => [];

const maximumBytes = 25 * 1_024 * 1_024;
const maximumPixelSize = 2_048;
let nextPhotoID = 0;

/**
 * Prepares a picked photo entirely on the device: rejects oversized input,
 * limits the longest side to 2048 px and re-encodes as JPEG. Re-encoding bakes in
 * the EXIF orientation and drops the source metadata, including location.
 */
export async function preparePhoto(source: PhotoSource, detectFaces: FaceDetector = noFaces): Promise<CardPhoto> {
  if (!source.uri || (source.fileSize ?? 0) > maximumBytes) throw new PhotoCropFailure();
  try {
    const context = ImageManipulator.manipulate(source.uri);
    let image = await context.renderAsync();
    const longestSide = Math.max(image.width, image.height);
    if (longestSide > maximumPixelSize) {
      const scale = maximumPixelSize / longestSide;
      context.resize({ width: Math.round(image.width * scale), height: Math.round(image.height * scale) });
      image = await context.renderAsync();
    }
    const saved = await image.saveAsync({ compress: 0.92, format: SaveFormat.JPEG });
    const dimensions = { width: saved.width, height: saved.height };
    if (!(dimensions.width > 0 && dimensions.height > 0)) throw new PhotoCropFailure();
    const crop = automaticCrop(dimensions, await detectFaces(saved.uri, dimensions));
    nextPhotoID += 1;
    return { id: `photo-${nextPhotoID}`, uri: saved.uri, dimensions, automaticCrop: crop, crop };
  } catch {
    throw new PhotoCropFailure();
  }
}
