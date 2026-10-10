import { DeviceMotion } from 'expo-sensors';
import { useEffect, useMemo } from 'react';
import { Gesture } from 'react-native-gesture-handler';
import {
  cancelAnimation,
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSpring,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';

import { useAppIsActive, useReduceMotion } from '@/core/theme/accessibility';

/** `device` tilts with the phone, `preview` runs a sensor-free light sweep, `disabled` is static. */
export type CardMotionMode = 'device' | 'preview' | 'disabled';

interface Pose {
  horizontal: number;
  vertical: number;
  shine: number;
}

const clamp = (value: number, lower: number, upper: number) => Math.min(Math.max(value, lower), upper);
const standardGravity = 9.81;

// One motion subscription is shared by every visible device-mode card and is
// stopped as soon as the last one disappears.
const listeners = new Set<(pose: Pose) => void>();
let subscription: { remove: () => void } | null = null;
let starting = false;

async function startSensor() {
  if (subscription || starting) return;
  starting = true;
  const available = await DeviceMotion.isAvailableAsync().catch(() => false);
  starting = false;
  if (!available || listeners.size === 0 || subscription) return;
  DeviceMotion.setUpdateInterval(1000 / 30);
  subscription = DeviceMotion.addListener(({ accelerationIncludingGravity: gravity }) => {
    if (!gravity) return;
    const horizontal = clamp((gravity.x / standardGravity) * 8, -5, 5);
    const vertical = clamp((-gravity.z / standardGravity) * 8, -5, 5);
    const pose = { horizontal, vertical, shine: clamp(0.5 + horizontal / 12 + vertical / 20, 0, 1) };
    listeners.forEach((listener) => listener(pose));
  });
}

function subscribeToDeviceMotion(listener: (pose: Pose) => void): () => void {
  listeners.add(listener);
  void startSensor();
  return () => {
    listeners.delete(listener);
    if (listeners.size === 0) {
      subscription?.remove();
      subscription = null;
    }
  };
}

const staticShine = 0.45;

/**
 * Tilt, drag and shine for one card. Reduce Motion, the disabled mode and a
 * backgrounded app all leave a static pose with no sensor or animation running.
 */
export function useCardMotion(mode: CardMotionMode) {
  const reduceMotion = useReduceMotion();
  const active = useAppIsActive();
  const animates = !reduceMotion && mode !== 'disabled' && active;
  const usesSensor = animates && mode === 'device';

  const dragX = useSharedValue(0);
  const dragY = useSharedValue(0);
  const poseHorizontal = useSharedValue(0);
  const poseVertical = useSharedValue(0);
  const shine: SharedValue<number> = useSharedValue(staticShine);

  useEffect(() => {
    if (animates && mode === 'preview') {
      shine.value = 0;
      shine.value = withRepeat(withTiming(1, { duration: 9_000, easing: Easing.linear }), -1, false);
      return () => cancelAnimation(shine);
    }
    if (!usesSensor) shine.value = staticShine;
  }, [animates, mode, usesSensor, shine]);

  useEffect(() => {
    if (!usesSensor) {
      poseHorizontal.value = 0;
      poseVertical.value = 0;
      return;
    }
    return subscribeToDeviceMotion((pose) => {
      poseHorizontal.value = pose.horizontal;
      poseVertical.value = pose.vertical;
      shine.value = pose.shine;
    });
  }, [usesSensor, poseHorizontal, poseVertical, shine]);

  // Horizontal drags tilt the card; vertical drags are left to the scroll view.
  const gesture = useMemo(
    () =>
      Gesture.Pan()
        .enabled(animates)
        .activeOffsetX([-10, 10])
        .failOffsetY([-12, 12])
        .runOnJS(true)
        .onUpdate((event) => {
          dragX.value = event.translationX;
          dragY.value = event.translationY;
        })
        .onFinalize(() => {
          dragX.value = withSpring(0, { damping: 18, stiffness: 190 });
          dragY.value = withSpring(0, { damping: 18, stiffness: 190 });
        }),
    [animates, dragX, dragY],
  );

  const tiltStyle = useAnimatedStyle(() => {
    const horizontal = animates ? poseHorizontal.value + Math.min(Math.max(dragX.value / 18, -5), 5) : 0;
    const vertical = animates ? poseVertical.value - Math.min(Math.max(dragY.value / 18, -5), 5) : 0;
    return { transform: [{ perspective: 900 }, { rotateY: `${horizontal}deg` }, { rotateX: `${vertical}deg` }] };
  }, [animates]);

  return { gesture, tiltStyle, shine, reduceMotion };
}
