import { useMemo } from 'react';
import { CatmullRomCurve3, Quaternion, Vector3 } from 'three';

import { JOINTS, SCHEMATIC_PARTS, type LayerId, type SchematicPart } from '@/data/body';
import type { Vec3 } from '@/types/BodyPoint';

import { isVisible, type PartState } from '@/components/viewer/part-state';

import { Articulated, type JointAngles } from './articulated';

const UP = new Vector3(0, 1, 0);

/** position, length and orientation of a capsule/ellipsoid spanning two points */
function span(from: Vec3, to: Vec3) {
  const a = new Vector3(...from);
  const b = new Vector3(...to);
  const dir = b.clone().sub(a);
  const length = dir.length();
  return {
    position: a.clone().add(b).multiplyScalar(0.5),
    length,
    quaternion: new Quaternion().setFromUnitVectors(UP, dir.normalize()),
  };
}

function PartMesh({ part, selected, opacity, bulge = 1 }: { part: SchematicPart; selected: boolean; opacity: number; bulge?: number }) {
  const s = part.shape;
  const geometry = useMemo(() => {
    if (s.kind === 'segment' || s.kind === 'spindle') return span(s.from, s.to);
    if (s.kind === 'tube') return { curve: new CatmullRomCurve3(s.points.map((p) => new Vector3(...p))) };
    return undefined;
  }, [s]);

  const material = (
    <meshStandardMaterial
      color={part.color}
      emissive="#FFD166"
      emissiveIntensity={selected ? 0.7 : 0}
      transparent={opacity < 1}
      opacity={opacity}
      roughness={0.55}
    />
  );
  const userData = { partId: part.id };

  switch (s.kind) {
    case 'sphere':
      return (
        <mesh position={s.center} scale={s.scale ?? [1, 1, 1]} userData={userData}>
          <sphereGeometry args={[s.radius, 20, 16]} />
          {material}
        </mesh>
      );
    case 'box':
      return (
        <mesh position={s.center} rotation={s.rotation ?? [0, 0, 0]} userData={userData}>
          <boxGeometry args={s.size} />
          {material}
        </mesh>
      );
    case 'segment': {
      const g = geometry as ReturnType<typeof span>;
      return (
        <mesh position={g.position} quaternion={g.quaternion} userData={userData}>
          <capsuleGeometry args={[s.radius, Math.max(0.001, g.length), 4, 10]} />
          {material}
        </mesh>
      );
    }
    case 'spindle': {
      const g = geometry as ReturnType<typeof span>;
      return (
        <mesh position={g.position} quaternion={g.quaternion} scale={[s.radius * bulge, (g.length / 2) * (2 - bulge) ** 0.5, s.radius * 0.8 * bulge]} userData={userData}>
          <sphereGeometry args={[1, 16, 12]} />
          {material}
        </mesh>
      );
    }
    case 'tube':
      return (
        <mesh userData={userData}>
          <tubeGeometry args={[(geometry as { curve: CatmullRomCurve3 }).curve, 40, s.radius, 8, false]} />
          {material}
        </mesh>
      );
    case 'arc':
      return (
        <mesh position={s.center} rotation={[Math.PI / 2, 0, s.start]} scale={[1, s.depth, 1]} userData={userData}>
          <torusGeometry args={[s.radius, s.tube, 6, 36, s.sweep]} />
          {material}
        </mesh>
      );
  }
}

type Props = { layers: LayerId[]; parts: PartState; selectedId?: string; angles?: JointAngles };

/** how much a muscle bulges: 1 at rest, up to 1.6 at the joint's full range */
function bulgeOf(partId: string, angles: JointAngles) {
  const joint = JOINTS.find((j) => j.movers.includes(partId));
  return joint ? 1 + 0.6 * Math.min(1, (angles[joint.id] ?? 0) / joint.maxDeg) : 1;
}

/** Bones, muscles, vessels and nerves as math-built primitives, filtered by visible layer. */
export function SchematicBody({ layers, parts, selectedId, angles = {} }: Props) {
  const muscleOpacity = layers.includes('skeletal') ? 0.55 : 0.95;
  return (
    <Articulated
      angles={angles}
      items={SCHEMATIC_PARTS.filter((part) => layers.includes(part.layer) && isVisible(parts, part.id)).map((part) => ({
        id: part.id,
        node: (
          <PartMesh
            key={part.id}
            part={part}
            selected={part.id === selectedId}
            opacity={parts.faded.includes(part.id) ? 0.18 : part.layer === 'muscular' ? muscleOpacity : 1}
            bulge={bulgeOf(part.id, angles)}
          />
        ),
      }))}
    />
  );
}
