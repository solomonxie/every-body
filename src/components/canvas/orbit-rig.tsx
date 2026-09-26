import { useRef, type ReactNode } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Group } from 'three';

import type { SceneBusRef } from './scene-bus';

const AUTO_ROTATE_SPEED = 0.35;
const EASE = 6;

/** Applies the bus's yaw/pitch to the model and eases the camera toward its focus. */
export function OrbitRig({ busRef, children }: { busRef: SceneBusRef; children: ReactNode }) {
  const ref = useRef<Group>(null);

  useFrame(({ camera }, delta) => {
    const b = busRef.current;
    const k = 1 - Math.exp(-EASE * delta);
    if (!b.touched) b.yaw += delta * AUTO_ROTATE_SPEED;
    if (b.goalYaw !== null) {
      b.yaw += (b.goalYaw - b.yaw) * k;
      if (Math.abs(b.goalYaw - b.yaw) < 0.001) b.goalYaw = null;
    }
    b.distance += (b.goalDistance - b.distance) * k;
    b.focusY += (b.goalFocusY - b.focusY) * k;

    camera.position.set(b.panX, b.focusY, b.distance);
    camera.lookAt(b.panX, b.focusY, 0);
    if (ref.current) {
      ref.current.rotation.y = b.yaw;
      ref.current.rotation.x = b.pitch;
    }
  });

  return <group ref={ref}>{children}</group>;
}
