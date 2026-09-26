import { bloodFats } from './scenes/blood-fats';
import { bloodPressure } from './scenes/blood-pressure';
import { bloodSugar } from './scenes/blood-sugar';
import { cpr } from './scenes/cpr';
import { shoulder } from './scenes/shoulder';
import type { Bilingual, IllustrationGroup, Scenario } from './types';

export const ILLUSTRATIONS: Scenario[] = [shoulder, cpr, bloodSugar, bloodPressure, bloodFats];

export const ILLUSTRATION_GROUPS: { id: IllustrationGroup; title: Bilingual; color: string }[] = [
  { id: 'bones', title: { en: 'Bones & setting', zh: '骨折与接骨' }, color: '#8F7E63' },
  { id: 'first-aid', title: { en: 'First aid', zh: '急救' }, color: '#D8434B' },
  { id: 'blood', title: { en: 'Blood sugar, pressure & fats', zh: '三高' }, color: '#E39B4B' },
];

export const findIllustration = (id: string) => ILLUSTRATIONS.find((s) => s.id === id);
