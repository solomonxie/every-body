import type { RefObject } from 'react';
import { Gesture } from 'react-native-gesture-handler';

import {
  FOCUS,
  MAX_DISTANCE,
  MIN_DISTANCE,
  faceFront,
  setFocus,
  type SceneBus,
  type SceneBusRef,
} from '@/components/canvas/scene-bus';
import type { Pick, Picker } from '@/components/canvas/tap-picker';

const ROTATE_PER_PX = 0.008;
const MAX_PITCH = 0.9;

export function resetView(bus: SceneBus) {
  bus.pitch = 0;
  faceFront(bus);
  setFocus(bus, FOCUS.all);
}

type Refs = {
  busRef: SceneBusRef;
  pickerRef: RefObject<Picker | null>;
  onPickRef: RefObject<((pick: Pick) => void) | undefined>;
  onFirstTouch: () => void;
};

/** Drag = spin, pinch = zoom, tap = pick a point, double-tap = reset. */
export function createOrbitGesture({ busRef, pickerRef, onPickRef, onFirstTouch }: Refs) {
  const firstTouch = () => {
    busRef.current.touched = true;
    onFirstTouch();
  };

  const pan = Gesture.Pan()
    .runOnJS(true)
    .onBegin(firstTouch)
    .onChange((e) => {
      const b = busRef.current;
      b.goalYaw = null;
      b.yaw += e.changeX * ROTATE_PER_PX;
      b.pitch = Math.max(-MAX_PITCH, Math.min(MAX_PITCH, b.pitch + e.changeY * ROTATE_PER_PX));
    });

  const pinch = Gesture.Pinch()
    .runOnJS(true)
    .onBegin(firstTouch)
    .onChange((e) => {
      const b = busRef.current;
      const next = Math.max(MIN_DISTANCE, Math.min(MAX_DISTANCE, b.goalDistance / e.scaleChange));
      b.goalDistance = next;
      b.distance = next;
    });

  const tap = Gesture.Tap()
    .runOnJS(true)
    .onEnd((e, success) => {
      firstTouch();
      if (!success) return;
      const pick = pickerRef.current?.(e.x, e.y);
      if (pick) onPickRef.current?.(pick);
    });

  const doubleTap = Gesture.Tap()
    .numberOfTaps(2)
    .runOnJS(true)
    .onEnd(() => resetView(busRef.current));

  return Gesture.Race(Gesture.Simultaneous(pan, pinch), Gesture.Exclusive(doubleTap, tap));
}
