import { bleeding } from './scenes/bleeding';
import { bloodFats } from './scenes/blood-fats';
import { bloodPressure } from './scenes/blood-pressure';
import { bloodSugar } from './scenes/blood-sugar';
import { burns } from './scenes/burns';
import { choking } from './scenes/choking';
import { coldFlu } from './scenes/cold-flu';
import { cpr } from './scenes/cpr';
import { fetalGrowth } from './scenes/fetal-growth';
import { fracture } from './scenes/fracture';
import { heartAttack } from './scenes/heart-attack';
import { labor } from './scenes/labor';
import { shoulder } from './scenes/shoulder';
import { stroke } from './scenes/stroke';
import type { Bilingual, IllustrationGroup, Scenario } from './types';

export const ILLUSTRATIONS: Scenario[] = [
  shoulder,
  fracture,
  cpr,
  choking,
  bleeding,
  burns,
  bloodSugar,
  bloodPressure,
  bloodFats,
  stroke,
  heartAttack,
  coldFlu,
  fetalGrowth,
  labor,
];

export const ILLUSTRATION_GROUPS: { id: IllustrationGroup; title: Bilingual; color: string }[] = [
  { id: 'bones', title: { en: 'Bones & setting', zh: '骨折与接骨' }, color: '#8F7E63' },
  { id: 'first-aid', title: { en: 'First aid', zh: '急救' }, color: '#D8434B' },
  { id: 'blood', title: { en: 'Blood sugar, pressure & fats', zh: '三高' }, color: '#E39B4B' },
  { id: 'illness', title: { en: 'Common illnesses', zh: '常见病' }, color: '#6C4F9E' },
  { id: 'pregnancy', title: { en: 'Pregnancy & birth', zh: '孕产' }, color: '#C77DA0' },
];

export const findIllustration = (id: string) => ILLUSTRATIONS.find((s) => s.id === id);
