import { mirrored, type SchematicPart } from './types';

const MUSCLE = '#C1443C';
const muscle = (id: string, name: string, nameZh: string, from: [number, number, number], to: [number, number, number], radius: number) =>
  mirrored({ id, name, nameZh, layer: 'muscular', color: MUSCLE, shape: { kind: 'spindle', from, to, radius } });

export const MUSCLES: SchematicPart[] = [
  ...muscle('sternocleidomastoid', 'Sternocleidomastoid', '胸锁乳突肌', [0.07, 1.34, 0.0], [0.03, 1.19, 0.12], 0.025),
  ...muscle('trapezius', 'Trapezius', '斜方肌', [0.05, 1.3, -0.12], [0.36, 1.17, -0.06], 0.06),
  ...muscle('deltoid', 'Deltoid', '三角肌', [0.38, 1.2, 0.02], [0.47, 0.94, 0.02], 0.07),
  ...muscle('pectoralis', 'Pectoralis major', '胸大肌', [0.04, 1.0, 0.19], [0.36, 1.1, 0.1], 0.075),
  ...muscle('biceps', 'Biceps', '肱二头肌', [0.45, 1.02, 0.06], [0.49, 0.66, 0.06], 0.045),
  ...muscle('triceps', 'Triceps', '肱三头肌', [0.44, 1.05, -0.05], [0.48, 0.66, -0.05], 0.045),
  ...muscle('forearm-flexors', 'Forearm flexors', '前臂屈肌', [0.5, 0.6, 0.04], [0.52, 0.2, 0.04], 0.04),
  ...muscle('latissimus', 'Latissimus dorsi', '背阔肌', [0.12, 0.9, -0.19], [0.3, 0.55, -0.12], 0.08),
  ...muscle('rectus-abdominis', 'Rectus abdominis', '腹直肌', [0.055, 0.85, 0.2], [0.055, 0.2, 0.2], 0.05),
  ...muscle('oblique', 'External oblique', '腹外斜肌', [0.26, 0.8, 0.1], [0.2, 0.25, 0.13], 0.06),
  ...muscle('gluteus', 'Gluteus maximus', '臀大肌', [0.12, 0.2, -0.19], [0.2, -0.04, -0.15], 0.1),
  ...muscle('quadriceps', 'Quadriceps', '股四头肌', [0.16, -0.04, 0.07], [0.17, -0.72, 0.07], 0.085),
  ...muscle('hamstrings', 'Hamstrings', '腘绳肌', [0.15, -0.06, -0.08], [0.16, -0.72, -0.07], 0.07),
  ...muscle('gastrocnemius', 'Calf (gastrocnemius)', '腓肠肌', [0.17, -0.84, -0.07], [0.16, -1.22, -0.05], 0.065),
  ...muscle('tibialis', 'Tibialis anterior', '胫骨前肌', [0.19, -0.86, 0.06], [0.17, -1.38, 0.07], 0.035),
];
