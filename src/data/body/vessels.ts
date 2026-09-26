import type { Vec3 } from '@/types/BodyPoint';

import { mirrored, type SchematicPart } from './types';

const ARTERY = '#D23A3A';
const VEIN = '#3A5BD9';
const NERVE = '#E8B923';

const tube = (id: string, name: string, nameZh: string, layer: SchematicPart['layer'], color: string, points: Vec3[], radius: number): SchematicPart => ({
  id, name, nameZh, layer, color, shape: { kind: 'tube', points, radius },
});
/** vein running alongside an artery, a little behind and to the side */
const alongside = (points: Vec3[]): Vec3[] => points.map(([x, y, z]) => [x + Math.sign(x || 1) * 0.012, y, z - 0.02]);

const ARM: Vec3[] = [[0.03, 1.08, 0.0], [0.34, 1.14, 0.0], [0.46, 0.9, 0.045], [0.49, 0.62, 0.05], [0.52, 0.15, 0.05]];
const LEG: Vec3[] = [[0.0, 0.22, -0.05], [0.11, 0.06, 0.05], [0.17, -0.4, 0.075], [0.17, -0.82, -0.04], [0.17, -1.42, 0.0]];
const NECK: Vec3[] = [[0.03, 1.08, 0.02], [0.05, 1.22, 0.05], [0.06, 1.38, 0.04]];

export const VESSELS: SchematicPart[] = [
  tube('aorta', 'Aorta', '主动脉', 'circulatory', ARTERY, [[0.06, 0.93, 0.1], [0.06, 1.05, 0.06], [0.0, 1.08, -0.04], [0.0, 0.9, -0.1], [0.0, 0.5, -0.1], [0.0, 0.22, -0.05]], 0.022),
  tube('vena-cava', 'Vena cava', '腔静脉', 'circulatory', VEIN, [[-0.05, 1.08, 0.0], [-0.04, 0.93, 0.06], [-0.04, 0.7, -0.04], [-0.04, 0.22, -0.07]], 0.024),
  tube('pulmonary-trunk', 'Pulmonary arteries', '肺动脉', 'circulatory', VEIN, [[-0.14, 0.97, 0.02], [0.04, 0.96, 0.1], [0.15, 0.97, 0.02]], 0.014),
  ...mirrored(tube('carotid', 'Carotid artery', '颈动脉', 'circulatory', ARTERY, NECK, 0.011)),
  ...mirrored(tube('jugular', 'Jugular vein', '颈静脉', 'circulatory', VEIN, alongside(NECK), 0.012)),
  ...mirrored(tube('arm-artery', 'Arm arteries', '上肢动脉', 'circulatory', ARTERY, ARM, 0.01)),
  ...mirrored(tube('arm-vein', 'Arm veins', '上肢静脉', 'circulatory', VEIN, alongside(ARM), 0.01)),
  ...mirrored(tube('leg-artery', 'Leg arteries', '下肢动脉', 'circulatory', ARTERY, LEG, 0.013)),
  ...mirrored(tube('leg-vein', 'Leg veins', '下肢静脉', 'circulatory', VEIN, alongside(LEG), 0.013)),

  tube('spinal-cord', 'Spinal cord', '脊髓', 'nervous', NERVE, [[0, 1.3, -0.1], [0, 1.0, -0.15], [0, 0.6, -0.12], [0, 0.3, -0.13]], 0.014),
  ...mirrored(tube('arm-nerve', 'Brachial plexus & median nerve', '臂丛与正中神经', 'nervous', NERVE, [[0.03, 1.14, -0.1], [0.33, 1.1, -0.03], [0.47, 0.8, 0.03], [0.5, 0.4, 0.045], [0.52, 0.05, 0.045]], 0.007)),
  ...mirrored(tube('sciatic', 'Sciatic nerve', '坐骨神经', 'nervous', NERVE, [[0.05, 0.15, -0.14], [0.14, 0.0, -0.15], [0.16, -0.5, -0.1], [0.16, -0.8, -0.05], [0.17, -1.42, -0.03]], 0.01)),
  ...mirrored(tube('intercostal', 'Intercostal nerve', '肋间神经', 'nervous', NERVE, [[0.02, 0.85, -0.16], [0.2, 0.85, -0.12], [0.25, 0.84, 0.05], [0.1, 0.83, 0.17]], 0.005)),

  tube('esophagus', 'Esophagus', '食管', 'organs', '#E0A080', [[0, 1.2, -0.02], [0.01, 0.95, -0.06], [0.06, 0.72, 0.0], [0.1, 0.65, 0.06]], 0.016),
  tube('trachea', 'Trachea & bronchi', '气管与支气管', 'organs', '#E8C4B0', [[0, 1.22, 0.05], [0, 1.02, 0.04], [0.12, 0.96, 0.02]], 0.019),
  tube('bronchus-r', 'Bronchi', '支气管', 'organs', '#E8C4B0', [[0, 1.02, 0.04], [-0.12, 0.96, 0.02]], 0.016),
];
