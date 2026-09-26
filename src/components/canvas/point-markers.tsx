import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Group } from 'three';

import type { BodyPoint } from '@/types/BodyPoint';

const HIT_RADIUS = 0.09;

/** Tappable dots on the body; the active one breathes. Hit spheres carry `userData.pointId` for picking. */
export function PointMarkers({ points, activeId }: { points: BodyPoint[]; activeId?: string }) {
  const activeRef = useRef<Group>(null);

  useFrame(({ clock }) => {
    activeRef.current?.scale.setScalar(1 + Math.sin(clock.getElapsedTime() * 5) * 0.25);
  });

  return (
    <group>
      {points.map((point) => {
        const active = point.id === activeId;
        return (
          <group key={point.id} position={point.position} ref={active ? activeRef : undefined}>
            <mesh renderOrder={2}>
              <sphereGeometry args={[active ? 0.045 : 0.03, 14, 14]} />
              <meshBasicMaterial color={active ? '#FFD166' : '#6C4F9E'} depthTest={false} />
            </mesh>
            <mesh userData={{ pointId: point.id }} visible={false}>
              <sphereGeometry args={[HIT_RADIUS, 8, 8]} />
            </mesh>
          </group>
        );
      })}
    </group>
  );
}
