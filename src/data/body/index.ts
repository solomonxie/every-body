import type { LayerId, SchematicPart } from './types';
import { MUSCLES } from './muscles';
import { SKELETON } from './skeleton';
import { VESSELS } from './vessels';

export type { LayerId, SchematicPart } from './types';

export const SCHEMATIC_PARTS: SchematicPart[] = [...SKELETON, ...MUSCLES, ...VESSELS];

export const LAYERS: { id: LayerId; label: string; labelZh: string }[] = [
  { id: 'skin', label: 'Skin', labelZh: '皮肤' },
  { id: 'muscular', label: 'Muscles', labelZh: '肌肉' },
  { id: 'skeletal', label: 'Bones', labelZh: '骨骼' },
  { id: 'circulatory', label: 'Vessels', labelZh: '血管' },
  { id: 'nervous', label: 'Nerves', labelZh: '神经' },
  { id: 'organs', label: 'Organs', labelZh: '器官' },
];

/** which layers a system opens with */
export const DEFAULT_LAYERS: Record<string, LayerId[]> = {
  skeletal: ['skin', 'skeletal'],
  muscular: ['skin', 'muscular'],
  circulatory: ['skin', 'circulatory', 'organs'],
  nervous: ['skin', 'nervous', 'organs'],
  organs: ['skin', 'organs'],
  digestive: ['skin', 'organs'],
  'acupoint-reflex-map': ['skin', 'organs'],
};
