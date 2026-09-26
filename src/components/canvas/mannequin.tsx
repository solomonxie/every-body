import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import type { Mesh, MeshStandardMaterial } from 'three';

import { REFLEX_RESPONSE_MS } from '@/constants/reflex';
import { BODY_PARTS, ORGAN_NAMES, ORGANS, type BodyPart, type OrganId } from '@/data/anatomy';

import { Articulated, type JointAngles } from './articulated';
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

function OrganMesh({ id, busRef, selected }: { id: OrganId; busRef: SceneBusRef; selected: boolean }) {
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
    material.emissiveIntensity = lit ? 0.55 + pulse : selected ? 0.5 : 0;
    mesh.visible = !organ.region || lit;
  });

  return (
    <mesh ref={ref} position={organ.position} scale={base} userData={ORGAN_NAMES[id] ? { partId: id } : {}}>
      <sphereGeometry args={[organ.radius, 20, 20]} />
      <meshStandardMaterial
        color={organ.color}
        emissive={organ.region ? organ.color : selected ? '#FFD166' : '#4ECB71'}
        emissiveIntensity={0}
        transparent={organ.region}
        opacity={organ.region ? 0.45 : 1}
        roughness={0.5}
      />
    </mesh>
  );
}

/** Translucent primitive figure with the organs visible inside. */
type Props = {
  skinColor: string;
  busRef: SceneBusRef;
  skinOpacity?: number;
  showOrgans?: boolean;
  selectedId?: string;
  angles?: JointAngles;
};

export function Mannequin({ skinColor, busRef, skinOpacity = 0.32, showOrgans = true, selectedId, angles = {} }: Props) {
  return (
    <group>
      {skinOpacity > 0 && (
        <Articulated
          angles={angles}
          items={BODY_PARTS.map((part) => ({
            id: part.id,
            node: (
              <mesh key={part.id} position={part.position} rotation={[0, 0, part.rotationZ ?? 0]} scale={part.scale ?? [1, 1, 1]} renderOrder={1}>
                <PartGeometry shape={part.shape} />
                <meshStandardMaterial color={skinColor} transparent opacity={skinOpacity} depthWrite={false} roughness={0.6} />
              </mesh>
            ),
          }))}
        />
      )}
      {(Object.keys(ORGANS) as OrganId[])
        .filter((id) => showOrgans || ORGANS[id].region)
        .map((id) => (
          <OrganMesh key={id} id={id} busRef={busRef} selected={id === selectedId} />
        ))}
    </group>
  );
}
