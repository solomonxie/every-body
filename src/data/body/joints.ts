import type { Vec3 } from '@/types/BodyPoint';

export interface Joint {
  id: string;
  name: string;
  nameZh: string;
  pivot: Vec3;
  /** rotation axis; positive angle = the movement named */
  axis: Vec3;
  maxDeg: number;
  parent?: string;
  /** part ids (schematic parts and skin parts) that move with this joint */
  parts: string[];
  /** muscles that shorten and bulge during the movement */
  movers: string[];
}

type Side = 'l' | 'r';
const x = (side: Side, v: number) => (side === 'l' ? v : -v);
const ids = (side: Side, names: string[]) => names.map((n) => `${n}-${side}`);

const forSide = (side: Side): Joint[] => [
  {
    id: `shoulder-${side}`,
    name: 'Shoulder — raise arm',
    nameZh: '肩关节 外展',
    pivot: [x(side, 0.41), 1.15, 0],
    axis: [0, 0, side === 'l' ? 1 : -1],
    maxDeg: 160,
    parts: ids(side, ['humerus', 'humeral-head', 'biceps', 'triceps', 'upper-arm']),
    movers: ids(side, ['deltoid']),
  },
  {
    id: `elbow-${side}`,
    name: 'Elbow — bend',
    nameZh: '肘关节 屈曲',
    pivot: [x(side, 0.485), 0.635, 0],
    axis: [-1, 0, 0],
    maxDeg: 145,
    parent: `shoulder-${side}`,
    parts: ids(side, ['radius', 'ulna', 'hand-bones', 'forearm-flexors', 'forearm', 'hand']),
    movers: ids(side, ['biceps']),
  },
  {
    id: `knee-${side}`,
    name: 'Knee — bend',
    nameZh: '膝关节 屈曲',
    pivot: [x(side, 0.17), -0.8, 0],
    axis: [1, 0, 0],
    maxDeg: 135,
    parts: ids(side, ['tibia', 'fibula', 'foot-bones', 'gastrocnemius', 'tibialis', 'shin', 'foot']),
    movers: ids(side, ['hamstrings']),
  },
];

export const JOINTS: Joint[] = [...forSide('l'), ...forSide('r')];

export const jointOfPart = (partId: string) => JOINTS.find((j) => j.parts.includes(partId) || j.movers.includes(partId));

/** the joint to offer for a tapped part: its own joint, or the one it drives */
export function jointForTry(partId: string) {
  return JOINTS.find((j) => j.movers.includes(partId)) ?? JOINTS.find((j) => j.parts.includes(partId));
}
