import { useEffect, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Vector3, type Mesh } from 'three';

import { REFLEX_RESPONSE_MS, REFLEX_TRAVEL_MS } from '@/constants/reflex';
import type { BodyPoint } from '@/types/BodyPoint';

const RADIUS = 1.15;
const TRAVEL_SECONDS = REFLEX_TRAVEL_MS / 1000;
const RESPONSE_SECONDS = REFLEX_RESPONSE_MS / 1000;

function toVector3(lat: number, lon: number) {
  return new Vector3(
    RADIUS * Math.cos(lat) * Math.sin(lon),
    RADIUS * Math.sin(lat),
    RADIUS * Math.cos(lat) * Math.cos(lon),
  );
}

/** Animates a pulse traveling from a pressed point to the body part it reflexively affects. */
export function ReflexPulse({ point, triggerKey }: { point?: BodyPoint; triggerKey: number }) {
  const pulseRef = useRef<Mesh>(null);
  const targetRef = useRef<Mesh>(null);
  const startTime = useRef(0);
  const needsRestart = useRef(false);

  useEffect(() => {
    needsRestart.current = true;
  }, [triggerKey]);

  useFrame(({ clock }) => {
    if (!point?.target || !pulseRef.current || !targetRef.current) return;

    if (needsRestart.current) {
      startTime.current = clock.getElapsedTime();
      needsRestart.current = false;
    }

    const elapsed = clock.getElapsedTime() - startTime.current;
    const from = toVector3(point.lat, point.lon);
    const to = toVector3(point.target.lat, point.target.lon);

    if (elapsed < TRAVEL_SECONDS) {
      pulseRef.current.visible = true;
      pulseRef.current.position.lerpVectors(from, to, elapsed / TRAVEL_SECONDS);
      targetRef.current.scale.setScalar(1);
    } else if (elapsed < TRAVEL_SECONDS + RESPONSE_SECONDS) {
      pulseRef.current.visible = false;
      const responseT = (elapsed - TRAVEL_SECONDS) / RESPONSE_SECONDS;
      targetRef.current.scale.setScalar(1 + Math.sin(responseT * Math.PI) * 0.6);
    } else {
      pulseRef.current.visible = false;
      targetRef.current.scale.setScalar(1);
    }
  });

  if (!point?.target) return null;
  const { target } = point;

  return (
    <group>
      <mesh position={toVector3(point.lat, point.lon)}>
        <sphereGeometry args={[0.05, 12, 12]} />
        <meshStandardMaterial color="#FFD166" emissive="#FFD166" emissiveIntensity={0.6} />
      </mesh>
      <mesh ref={targetRef} position={toVector3(target.lat, target.lon)}>
        <sphereGeometry args={[0.07, 12, 12]} />
        <meshStandardMaterial color="#4ECB71" emissive="#4ECB71" emissiveIntensity={0.5} />
      </mesh>
      <mesh ref={pulseRef} visible={false}>
        <sphereGeometry args={[0.04, 10, 10]} />
        <meshStandardMaterial color="#FF6B6B" emissive="#FF6B6B" emissiveIntensity={1} />
      </mesh>
    </group>
  );
}
