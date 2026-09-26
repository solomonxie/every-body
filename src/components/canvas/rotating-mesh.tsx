import { useRef, type ReactNode } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Group } from 'three';

export function RotatingMesh({ color, children }: { color: string; children?: ReactNode }) {
  const ref = useRef<Group>(null);

  useFrame((_, delta) => {
    if (!ref.current) return;
    ref.current.rotation.x += delta * 0.35;
    ref.current.rotation.y += delta * 0.55;
  });

  return (
    <group ref={ref}>
      <mesh>
        <sphereGeometry args={[1.1, 32, 32]} />
        <meshStandardMaterial color={color} roughness={0.4} metalness={0.1} />
      </mesh>
      {children}
    </group>
  );
}
