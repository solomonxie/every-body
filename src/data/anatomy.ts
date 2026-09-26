import type { Vec3 } from '@/types/BodyPoint';

// Placeholder mannequin built from primitives, until the licensed model lands (IMPLEMENT_PLAN T3.6).
// Units: ~3.4 tall, feet at y≈-1.6, figure faces +z, its right side is -x.

export type BodyPartShape =
  | { kind: 'sphere'; radius: number }
  | { kind: 'capsule'; radius: number; length: number }
  | { kind: 'box'; size: Vec3 };

export interface BodyPart {
  id: string;
  shape: BodyPartShape;
  position: Vec3;
  rotationZ?: number;
  scale?: Vec3;
}

const mirrored = (part: BodyPart): BodyPart[] => [
  { ...part, id: `${part.id}-l` },
  {
    ...part,
    id: `${part.id}-r`,
    position: [-part.position[0], part.position[1], part.position[2]],
    rotationZ: part.rotationZ === undefined ? undefined : -part.rotationZ,
  },
];

export const BODY_PARTS: BodyPart[] = [
  { id: 'head', shape: { kind: 'sphere', radius: 0.22 }, position: [0, 1.42, 0], scale: [0.9, 1.05, 1] },
  { id: 'neck', shape: { kind: 'capsule', radius: 0.08, length: 0.12 }, position: [0, 1.16, 0] },
  { id: 'torso', shape: { kind: 'capsule', radius: 0.3, length: 0.5 }, position: [0, 0.72, 0], scale: [1.15, 1, 0.7] },
  { id: 'pelvis', shape: { kind: 'sphere', radius: 0.3 }, position: [0, 0.14, 0], scale: [1.1, 0.65, 0.72] },
  ...mirrored({ id: 'ear', shape: { kind: 'sphere', radius: 0.055 }, position: [0.2, 1.42, 0], scale: [0.5, 1, 0.8] }),
  ...mirrored({ id: 'upper-arm', shape: { kind: 'capsule', radius: 0.075, length: 0.42 }, position: [0.44, 0.9, 0], rotationZ: 0.12 }),
  ...mirrored({ id: 'forearm', shape: { kind: 'capsule', radius: 0.065, length: 0.4 }, position: [0.5, 0.38, 0], rotationZ: 0.06 }),
  ...mirrored({ id: 'hand', shape: { kind: 'sphere', radius: 0.1 }, position: [0.52, 0.02, 0], scale: [0.7, 1.15, 0.4] }),
  ...mirrored({ id: 'thigh', shape: { kind: 'capsule', radius: 0.12, length: 0.58 }, position: [0.16, -0.38, 0] }),
  ...mirrored({ id: 'shin', shape: { kind: 'capsule', radius: 0.09, length: 0.58 }, position: [0.16, -1.08, 0] }),
  ...mirrored({ id: 'foot', shape: { kind: 'box', size: [0.16, 0.08, 0.32] }, position: [0.16, -1.53, 0.08] }),
];

export type OrganId =
  | 'brain'
  | 'heart'
  | 'lung-l'
  | 'lung-r'
  | 'liver'
  | 'stomach'
  | 'kidney-l'
  | 'kidney-r'
  | 'intestines'
  | 'uterus'
  | 'shoulders';

export interface Organ {
  position: Vec3;
  radius: number;
  scale?: Vec3;
  color: string;
  /** a region rather than an organ: invisible until it lights up */
  region?: boolean;
}

export const ORGANS: Record<OrganId, Organ> = {
  brain: { position: [0, 1.47, 0], radius: 0.14, scale: [1, 0.8, 1.1], color: '#E8A0B4' },
  heart: { position: [0.06, 0.92, 0.1], radius: 0.075, color: '#C8323C' },
  'lung-l': { position: [0.15, 0.96, 0], radius: 0.1, scale: [0.9, 1.7, 0.9], color: '#E5868F' },
  'lung-r': { position: [-0.15, 0.96, 0], radius: 0.1, scale: [0.9, 1.7, 0.9], color: '#E5868F' },
  liver: { position: [-0.11, 0.68, 0.06], radius: 0.11, scale: [1.5, 0.7, 0.9], color: '#8C3B2E' },
  stomach: { position: [0.11, 0.62, 0.08], radius: 0.08, scale: [1.2, 0.9, 0.8], color: '#E39B4B' },
  'kidney-l': { position: [0.12, 0.45, -0.1], radius: 0.055, scale: [0.8, 1.3, 0.7], color: '#7E2130' },
  'kidney-r': { position: [-0.12, 0.45, -0.1], radius: 0.055, scale: [0.8, 1.3, 0.7], color: '#7E2130' },
  intestines: { position: [0, 0.3, 0.07], radius: 0.16, scale: [1.1, 0.8, 0.7], color: '#D9A77A' },
  uterus: { position: [0, 0.1, 0.06], radius: 0.06, color: '#C77DA0' },
  shoulders: { position: [0, 1.12, 0], radius: 0.2, scale: [2.6, 0.5, 0.9], color: '#FFD166', region: true },
};
