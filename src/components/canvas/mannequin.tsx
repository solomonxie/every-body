import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Mesh, MeshStandardMaterial } from 'three';

import { REFLEX_RESPONSE_MS } from '@/constants/reflex';
import { BODY_PARTS, ORGANS, type BodyPart, type OrganId } from '@/data/anatomy';

import type { SceneBusRef } from './scene-bus';

const RESPONSE_SECONDS = REFLEX_RESPONSE_MS / 1000;

function PartGeometry({ shape }: Pick<BodyPart, 'shape'>) {
  switch (shape.kind) {
    case 'sphere':
      return <sphereGeometry args={[shape.radius, 24, 24]} />;
    case 'capsule':
      return <capsuleGeometry args={[shape.radius, shape.length, 8, 16]} />;
    case 'box':
      return <boxGeometry args={shape.size} />;
  }
}

function OrganMesh({ id, busRef }: { id: OrganId; busRef: SceneBusRef }) {
  const ref = useRef<Mesh>(null);
  const organ = ORGANS[id];
  const base = organ.scale ?? [1, 1, 1];

  useFrame(({ clock }) => {
    const mesh = ref.current;
    if (!mesh) return;
    const material = mesh.material as MeshStandardMaterial;
    const { litOrgans, flashStart, bpm } = busRef.current;
    const lit = litOrgans.includes(id) && flashStart >= 0;
    const t = clock.getElapsedTime();

    let pulse = 0;
    if (lit) {
      const sinceFlash = t - flashStart;
      pulse = sinceFlash < RESPONSE_SECONDS ? Math.sin((sinceFlash / RESPONSE_SECONDS) * Math.PI) * 0.6 : 0;
    }
    if (id === 'heart') {
      const beat = (t * bpm) / 60;
      pulse += Math.max(0, Math.sin(beat * Math.PI * 2)) ** 4 * 0.18;
    }
    mesh.scale.set(base[0] * (1 + pulse), base[1] * (1 + pulse), base[2] * (1 + pulse));
    material.emissiveIntensity = lit ? 0.55 + pulse : 0;
    mesh.visible = !organ.region || lit;
  });

  return (
    <mesh ref={ref} position={organ.position} scale={base}>
      <sphereGeometry args={[organ.radius, 20, 20]} />
      <meshStandardMaterial
        color={organ.color}
        emissive={organ.region ? organ.color : '#4ECB71'}
        emissiveIntensity={0}
        transparent={organ.region}
        opacity={organ.region ? 0.45 : 1}
        roughness={0.5}
      />
    </mesh>
  );
}

/** Translucent primitive figure with the organs visible inside. */
export function Mannequin({ skinColor, busRef }: { skinColor: string; busRef: SceneBusRef }) {
  return (
    <group>
      {BODY_PARTS.map((part) => (
        <mesh key={part.id} position={part.position} rotation={[0, 0, part.rotationZ ?? 0]} scale={part.scale ?? [1, 1, 1]} renderOrder={1}>
          <PartGeometry shape={part.shape} />
          <meshStandardMaterial color={skinColor} transparent opacity={0.32} depthWrite={false} roughness={0.6} />
        </mesh>
      ))}
      {(Object.keys(ORGANS) as OrganId[]).map((id) => (
        <OrganMesh key={id} id={id} busRef={busRef} />
      ))}
    </group>
  );
}
