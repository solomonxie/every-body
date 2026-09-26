import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { QuadraticBezierCurve3, Vector3, type Group } from 'three';

import { REFLEX_TRAVEL_MS } from '@/constants/reflex';
import { ORGANS } from '@/data/anatomy';
import type { BodyPoint } from '@/types/BodyPoint';

import type { SceneBusRef } from './scene-bus';

const TRAVEL_SECONDS = REFLEX_TRAVEL_MS / 1000;
const TRAIL = 5;
const TRAIL_GAP = 0.035;
const BULGE = 0.35;

function pathTo(from: Vector3, to: Vector3) {
  const mid = from.clone().lerp(to, 0.5);
  mid.z += BULGE;
  return new QuadraticBezierCurve3(from, mid, to);
}

/** Pulses travel from a pressed point to each organ it reflexively affects, then light them up. */
export function ReflexPulse({ point, triggerKey, busRef }: { point?: BodyPoint; triggerKey: number; busRef: SceneBusRef }) {
  const groupRef = useRef<Group>(null);
  const startTime = useRef(-1);
  const needsRestart = useRef(false);

  const curves = useMemo(() => {
    if (!point?.target) return [];
    const from = new Vector3(...point.position);
    return point.target.organIds.map((id) => pathTo(from, new Vector3(...ORGANS[id].position)));
  }, [point]);

  useEffect(() => {
    needsRestart.current = true;
  }, [triggerKey]);

  useFrame(({ clock }) => {
    const group = groupRef.current;
    if (!group || curves.length === 0) return;
    const now = clock.getElapsedTime();
    if (needsRestart.current) {
      startTime.current = now;
      needsRestart.current = false;
    }

    const progress = (now - startTime.current) / TRAVEL_SECONDS;
    if (progress >= 1 && busRef.current.flashStart < 0) busRef.current.flashStart = now;

    group.children.forEach((dot, index) => {
      const curve = curves[Math.floor(index / TRAIL)];
      const u = progress - (index % TRAIL) * TRAIL_GAP;
      dot.visible = u > 0 && u < 1;
      if (dot.visible) curve.getPoint(u, dot.position);
    });
  });

  return (
    <group ref={groupRef}>
      {curves.flatMap((_, curveIndex) =>
        Array.from({ length: TRAIL }, (__, i) => (
          <mesh key={`${curveIndex}-${i}`} visible={false} scale={1 - i * 0.16}>
            <sphereGeometry args={[0.035, 10, 10]} />
            <meshBasicMaterial color="#FFD166" transparent opacity={1 - i * 0.17} />
          </mesh>
        )),
      )}
    </group>
  );
}
