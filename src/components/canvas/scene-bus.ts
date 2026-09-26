import type { RefObject } from 'react';

import type { OrganId } from '@/data/anatomy';
import type { PointRegion } from '@/types/BodyPoint';

/** Mutable state shared between gestures, React UI and useFrame loops — no re-renders per frame. */
export interface SceneBus {
  yaw: number;
  pitch: number;
  distance: number;
  focusY: number;
  panX: number;
  goalDistance: number;
  goalFocusY: number;
  goalYaw: number | null;
  touched: boolean;
  /** organs lit by the latest reflex press; flashStart < 0 = not yet arrived */
  litOrgans: OrganId[];
  flashStart: number;
  bpm: number;
}

export type SceneBusRef = RefObject<SceneBus>;

export const DEFAULT_BPM = 72;

type Focus = { y: number; distance: number };

export const FOCUS: Record<PointRegion | 'all', Focus> = {
  all: { y: 0, distance: 5.8 },
  body: { y: 0, distance: 5.8 },
  foot: { y: -1.35, distance: 2.1 },
  hand: { y: 0.2, distance: 2.4 },
  ear: { y: 1.42, distance: 1.5 },
};

export const MIN_DISTANCE = 1.2;
export const MAX_DISTANCE = 9;

/** `litOrgans` pre-lights a pressed zone opened from search (the pulse then plays on mount) */
export function createSceneBus(litOrgans: OrganId[] = []): SceneBus {
  return {
    yaw: 0,
    pitch: 0,
    distance: FOCUS.all.distance,
    focusY: FOCUS.all.y,
    panX: 0,
    goalDistance: FOCUS.all.distance,
    goalFocusY: FOCUS.all.y,
    goalYaw: null,
    touched: false,
    litOrgans,
    flashStart: -1,
    bpm: DEFAULT_BPM,
  };
}

export function setFocus(bus: SceneBus, focus: Focus) {
  bus.goalFocusY = focus.y;
  bus.goalDistance = focus.distance;
}

/** Turn the figure to face the camera by the shortest way round. */
export function faceFront(bus: SceneBus) {
  const turns = Math.round(bus.yaw / (Math.PI * 2));
  bus.goalYaw = turns * Math.PI * 2;
}
