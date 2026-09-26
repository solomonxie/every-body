import type { Vec3 } from '@/types/BodyPoint';

import { mirrored, type SchematicPart } from './types';

const BONE = '#E9E2CF';
const bone = (id: string, name: string, nameZh: string, shape: SchematicPart['shape']): SchematicPart => ({
  id, name, nameZh, layer: 'skeletal', color: BONE, shape,
});

// Spine: 24 vertebrae from C1 (y 1.24) to L5 (y 0.22), gentle S-curve in z.
const SPINE_TOP = 1.24;
const SPINE_BOTTOM = 0.22;
export const spineZ = (y: number) => -0.14 + 0.025 * Math.sin((Math.PI * (y - SPINE_BOTTOM)) / 0.52);

const REGIONS: { prefix: string; zh: string; count: number; size: Vec3 }[] = [
  { prefix: 'C', zh: '颈椎', count: 7, size: [0.06, 0.028, 0.05] },
  { prefix: 'T', zh: '胸椎', count: 12, size: [0.07, 0.034, 0.06] },
  { prefix: 'L', zh: '腰椎', count: 5, size: [0.085, 0.04, 0.07] },
];

const vertebrae: SchematicPart[] = [];
{
  let i = 0;
  for (const region of REGIONS) {
    for (let n = 1; n <= region.count; n++, i++) {
      const y = SPINE_TOP - (i / 23) * (SPINE_TOP - SPINE_BOTTOM);
      vertebrae.push(
        bone(`vertebra-${region.prefix}${n}`, `${region.prefix}${n} vertebra`, `第${n}${region.zh}`, {
          kind: 'box', center: [0, y, spineZ(y)], size: region.size,
        }),
      );
    }
  }
}

// Ribs 1–12: flat arcs from the spine round to the front; 11–12 float (short).
const RIB_RADII = [0.13, 0.17, 0.2, 0.22, 0.235, 0.245, 0.25, 0.25, 0.245, 0.235, 0.22, 0.2];
const ribs: SchematicPart[] = RIB_RADII.flatMap((radius, i) => {
  const y = 1.14 - i * 0.05;
  const floating = i >= 10;
  return mirrored(
    bone(`rib-${i + 1}`, `Rib ${i + 1}`, `第${i + 1}肋`, {
      kind: 'arc', center: [0, y, -0.02], radius, tube: 0.012,
      start: -1.62, sweep: floating ? 1.6 : 3.0, depth: 0.75,
    }),
  );
});

export const SKELETON: SchematicPart[] = [
  bone('skull', 'Skull', '颅骨', { kind: 'sphere', center: [0, 1.47, -0.01], radius: 0.17, scale: [0.88, 1, 1.05] }),
  bone('mandible', 'Mandible', '下颌骨', { kind: 'segment', from: [-0.07, 1.3, 0.06], to: [0.07, 1.3, 0.06], radius: 0.03 }),
  ...vertebrae,
  bone('sacrum', 'Sacrum', '骶骨', { kind: 'box', center: [0, 0.12, -0.13], size: [0.12, 0.14, 0.05], rotation: [0.4, 0, 0] }),
  bone('coccyx', 'Coccyx', '尾骨', { kind: 'segment', from: [0, 0.05, -0.11], to: [0, 0.0, -0.07], radius: 0.012 }),
  bone('sternum', 'Sternum', '胸骨', { kind: 'box', center: [0, 0.93, 0.18], size: [0.05, 0.3, 0.02], rotation: [-0.15, 0, 0] }),
  ...ribs,
  ...mirrored(bone('clavicle', 'Clavicle', '锁骨', { kind: 'segment', from: [0.03, 1.19, 0.14], to: [0.3, 1.21, 0.0], radius: 0.014 })),
  ...mirrored(bone('scapula', 'Scapula', '肩胛骨', { kind: 'box', center: [0.2, 0.98, -0.17], size: [0.14, 0.19, 0.015], rotation: [0, 0.45, 0] })),
  ...mirrored(bone('humerus', 'Humerus', '肱骨', { kind: 'segment', from: [0.42, 1.14, 0], to: [0.48, 0.65, 0.01], radius: 0.026 })),
  ...mirrored(bone('humeral-head', 'Humeral head', '肱骨头', { kind: 'sphere', center: [0.4, 1.15, 0], radius: 0.042 })),
  ...mirrored(bone('radius', 'Radius', '桡骨', { kind: 'segment', from: [0.49, 0.62, 0.025], to: [0.53, 0.14, 0.035], radius: 0.016 })),
  ...mirrored(bone('ulna', 'Ulna', '尺骨', { kind: 'segment', from: [0.49, 0.64, -0.02], to: [0.5, 0.13, -0.01], radius: 0.015 })),
  ...mirrored(bone('hand-bones', 'Hand bones', '手骨', { kind: 'box', center: [0.52, 0.02, 0.01], size: [0.02, 0.2, 0.08] })),
  bone('pelvis', 'Pelvis', '骨盆', { kind: 'arc', center: [0, 0.15, -0.01], radius: 0.17, tube: 0.04, start: 0, sweep: Math.PI * 2, depth: 0.7 }),
  ...mirrored(bone('femoral-head', 'Femoral head', '股骨头', { kind: 'sphere', center: [0.1, 0.07, 0.0], radius: 0.042 })),
  ...mirrored(bone('femur', 'Femur', '股骨', { kind: 'segment', from: [0.14, 0.04, 0], to: [0.17, -0.77, 0.01], radius: 0.032 })),
  ...mirrored(bone('patella', 'Patella', '髌骨', { kind: 'sphere', center: [0.17, -0.8, 0.08], radius: 0.034, scale: [1, 1.2, 0.5] })),
  ...mirrored(bone('tibia', 'Tibia', '胫骨', { kind: 'segment', from: [0.17, -0.83, 0.02], to: [0.16, -1.46, 0.02], radius: 0.028 })),
  ...mirrored(bone('fibula', 'Fibula', '腓骨', { kind: 'segment', from: [0.23, -0.85, -0.01], to: [0.21, -1.45, -0.01], radius: 0.014 })),
  ...mirrored(bone('foot-bones', 'Foot bones', '足骨', { kind: 'box', center: [0.16, -1.53, 0.07], size: [0.1, 0.05, 0.28] })),
];
