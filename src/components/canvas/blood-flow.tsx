import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { CatmullRomCurve3, Vector3, type Group, type Mesh, type MeshBasicMaterial } from 'three';

import type { BodyPoint } from '@/types/BodyPoint';

import type { SceneBusRef } from './scene-bus';

const PARTICLES = 18;
const ARTERIAL = '#E03A3E';
const VENOUS = '#3A5BD9';
/** loop lengths per heartbeat — faster heart, faster blood */
const LOOPS_PER_BEAT = 0.06;

/**
 * Blood cells looping through the flow stops. Oxygen-rich (red) from the lungs through the
 * arteries to the capillaries, oxygen-poor (blue) back through the veins to the lungs.
 */
export function BloodFlow({ stops, busRef }: { stops: BodyPoint[]; busRef: SceneBusRef }) {
  const groupRef = useRef<Group>(null);
  const phase = useRef(0);

  const curve = useMemo(
    () => new CatmullRomCurve3(stops.map((stop) => new Vector3(...stop.position)), true, 'centripetal'),
    [stops],
  );
  const capillaryAt = stops.findIndex((stop) => stop.id === 'capillaries') / stops.length;
  const lungsAt = stops.findIndex((stop) => stop.id === 'lungs') / stops.length;

  useFrame((_, delta) => {
    phase.current = (phase.current + delta * (busRef.current.bpm / 60) * LOOPS_PER_BEAT) % 1;
    groupRef.current?.children.forEach((child, i) => {
      const u = (phase.current + i / PARTICLES) % 1;
      curve.getPointAt(u, child.position);
      const venous = u > capillaryAt && u < lungsAt;
      ((child as Mesh).material as MeshBasicMaterial).color.set(venous ? VENOUS : ARTERIAL);
    });
  });

  return (
    <group ref={groupRef}>
      {Array.from({ length: PARTICLES }, (_, i) => (
        <mesh key={i} renderOrder={2}>
          <sphereGeometry args={[0.03, 10, 10]} />
          <meshBasicMaterial color={ARTERIAL} depthTest={false} />
        </mesh>
      ))}
    </group>
  );
}
