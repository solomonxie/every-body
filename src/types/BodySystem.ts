export interface BodySystem {
  id: string;
  name: string;
  color: string;
}

export const BODY_SYSTEMS: BodySystem[] = [
  { id: 'acupoint-reflex-map', name: 'Reflex Map 穴位反射图', color: '#6C4F9E' },
  { id: 'skeletal', name: 'Skeletal', color: '#E4DECB' },
  { id: 'muscular', name: 'Muscular', color: '#C1443C' },
  { id: 'circulatory', name: 'Circulatory', color: '#A11F2B' },
  { id: 'nervous', name: 'Nervous', color: '#F0C93D' },
  { id: 'organs', name: 'Organs', color: '#8E3B54' },
  { id: 'digestive', name: 'Digestive', color: '#D98C3D' },
];
