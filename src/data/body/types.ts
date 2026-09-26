import type { Vec3 } from '@/types/BodyPoint';

export type LayerId = 'skin' | 'muscular' | 'skeletal' | 'circulatory' | 'nervous' | 'organs';

export type PartShape =
  | { kind: 'sphere'; center: Vec3; radius: number; scale?: Vec3 }
  | { kind: 'box'; center: Vec3; size: Vec3; rotation?: Vec3 }
  /** capsule between two points */
  | { kind: 'segment'; from: Vec3; to: Vec3; radius: number }
  /** ellipsoid stretched between two points — muscle bellies */
  | { kind: 'spindle'; from: Vec3; to: Vec3; radius: number }
  /** tube along a smooth curve through the points — vessels, nerves, gut */
  | { kind: 'tube'; points: Vec3[]; radius: number }
  /** part of a torus lying flat (ribs); angles in radians, 0 = figure's left, π/2 = front */
  | { kind: 'arc'; center: Vec3; radius: number; tube: number; start: number; sweep: number; depth: number };

export interface SchematicPart {
  id: string;
  name: string;
  nameZh: string;
  layer: LayerId;
  color: string;
  shape: PartShape;
}

/** x → -x copy for the figure's right side (ids get -l / -r) */
export function mirrored(part: SchematicPart): SchematicPart[] {
  const flip = ([x, y, z]: Vec3): Vec3 => [-x, y, z];
  const s = part.shape;
  const shape: PartShape =
    s.kind === 'sphere' ? { ...s, center: flip(s.center) } :
    s.kind === 'box' ? { ...s, center: flip(s.center), rotation: s.rotation && [s.rotation[0], -s.rotation[1], -s.rotation[2]] } :
    s.kind === 'segment' || s.kind === 'spindle' ? { ...s, from: flip(s.from), to: flip(s.to) } :
    s.kind === 'tube' ? { ...s, points: s.points.map(flip) } :
    { ...s, center: flip(s.center), start: Math.PI - s.start - s.sweep };
  return [
    { ...part, id: `${part.id}-l`, name: `${part.name} (L)`, nameZh: `左${part.nameZh}` },
    { ...part, id: `${part.id}-r`, name: `${part.name} (R)`, nameZh: `右${part.nameZh}`, shape },
  ];
}
