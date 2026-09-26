import type { RefObject } from 'react';
import { Gesture } from 'react-native-gesture-handler';

export type PointHandler = (x: number, y: number) => void;

/** Pan that forwards finger positions (view coords) to whatever handler the ref holds now. */
export function createDragGesture(handlerRef: RefObject<PointHandler | null>) {
  return Gesture.Pan()
    .runOnJS(true)
    .minDistance(0)
    .onBegin((e) => handlerRef.current?.(e.x, e.y))
    .onUpdate((e) => handlerRef.current?.(e.x, e.y));
}
