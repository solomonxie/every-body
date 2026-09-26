import { Circle, G, Line, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

/** systolic / diastolic mmHg from heart rate, arterial stiffness and blood volume */
export function pressures({ hr, stiffness, volume }: Params) {
  const systolic = 100 + 0.25 * (hr - 70) + 45 * stiffness + 20 * volume;
  const diastolic = 65 + 0.2 * (hr - 70) + 15 * stiffness + 10 * volume;
  return { systolic, diastolic };
}

/** 0..1 over one beat: sharp upstroke, then exponential run-off */
function wave(phase: number) {
  return phase < 0.15 ? Math.sin((phase / 0.15) * (Math.PI / 2)) : Math.exp(-(phase - 0.15) * 4.5);
}

const category = (s: number, d: number) =>
  s >= 140 || d >= 90 ? { label: 'High 高血压', color: '#D8434B' } :
  s >= 130 || d >= 80 ? { label: 'Raised 偏高', color: '#E39B4B' } :
  { label: 'Normal 正常', color: '#2E9E5B' };

const PLOT = { x0: 170, x1: 352, y0: 60, y1: 230, min: 40, max: 200 };
const yOf = (mmHg: number) => PLOT.y1 - ((mmHg - PLOT.min) / (PLOT.max - PLOT.min)) * (PLOT.y1 - PLOT.y0);
const WINDOW_S = 3;

function BloodPressureScene({ params, t }: SceneProps) {
  const { systolic, diastolic } = pressures(params);
  const at = (time: number) => diastolic + (systolic - diastolic) * wave(((time * params.hr) / 60) % 1);
  const now = at(t);
  const stretch = (now - diastolic) / Math.max(1, systolic - diastolic);
  const radius = 42 + stretch * (12 * (1 - params.stiffness) + 2);
  const wall = 6 + 8 * params.stiffness;
  const cat = category(systolic, diastolic);

  const samples = 90;
  const d = Array.from({ length: samples + 1 }, (_, i) => {
    const x = PLOT.x0 + (i / samples) * (PLOT.x1 - PLOT.x0);
    const y = yOf(at(t - WINDOW_S + (i / samples) * WINDOW_S));
    return `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`;
  }).join(' ');

  return (
    <G>
      <Circle cx={85} cy={145} r={radius + wall / 2} fill="#E8B4B8" />
      <Circle cx={85} cy={145} r={radius - wall / 2} fill="#C8323C" />
      <Text x={85} y={150} fontSize={11} fill="#FFFFFF" textAnchor="middle">blood 血</Text>
      <Text x={85} y={222} fontSize={10} fill="#8A3B45" textAnchor="middle">Artery cross-section</Text>
      <Text x={85} y={236} fontSize={10} fill="#8A3B45" textAnchor="middle">动脉横截面 · wall 管壁</Text>

      <Rect x={PLOT.x0} y={PLOT.y0} width={PLOT.x1 - PLOT.x0} height={PLOT.y1 - PLOT.y0} fill="#FAFAFC" stroke="#DDD" />
      {[80, 120, 140].map((mm) => (
        <G key={mm}>
          <Line x1={PLOT.x0} y1={yOf(mm)} x2={PLOT.x1} y2={yOf(mm)} stroke={mm === 120 || mm === 80 ? '#9CC9A8' : '#E8A7A7'} strokeDasharray="4 3" />
          <Text x={PLOT.x0 - 4} y={yOf(mm) + 3} fontSize={9} fill="#777" textAnchor="end">{mm}</Text>
        </G>
      ))}
      <Path d={d} stroke="#C8323C" strokeWidth={2.5} fill="none" />
      <Text x={PLOT.x0} y={PLOT.y1 + 14} fontSize={9} fill="#777">last 3 s · mmHg</Text>

      <Rect x={170} y={6} width={182} height={44} rx={8} fill="#FFFFFF" stroke={cat.color} strokeWidth={2} />
      <Text x={261} y={26} fontSize={16} fontWeight="bold" fill={cat.color} textAnchor="middle">
        {`${Math.round(systolic)}/${Math.round(diastolic)} mmHg`}
      </Text>
      <Text x={261} y={42} fontSize={10} fill={cat.color} textAnchor="middle">
        {`${cat.label} · ${Math.round(params.hr)} bpm`}
      </Text>
      <Text x={8} y={20} fontSize={10} fill="#555">systolic 收缩压 = peak</Text>
      <Text x={8} y={34} fontSize={10} fill="#555">diastolic 舒张压 = trough</Text>
    </G>
  );
}

export const bloodPressure: Scenario = {
  id: 'blood-pressure',
  group: 'blood',
  title: { en: 'Blood pressure', zh: '血压' },
  params: { hr: 70, stiffness: 0, volume: 0.1 },
  Scene: BloodPressureScene,
  sources: ['2017 ACC/AHA and 2018 Chinese hypertension guideline categories'],
  steps: [
    {
      kind: 'watch',
      caption: {
        en: 'Each heartbeat pushes blood into the artery: pressure peaks (systolic), then falls (diastolic).',
        zh: '每次心跳把血液泵入动脉：压力先达峰值（收缩压），再回落（舒张压）。',
      },
      set: { hr: 70, stiffness: 0, volume: 0.1 },
    },
    {
      kind: 'watch',
      caption: { en: 'A faster heart raises pressure a little.', zh: '心率加快，血压略升。' },
      set: { hr: 110 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'With age and long-term high pressure, arteries stiffen. They can’t stretch, so the peak shoots up.',
        zh: '随年龄增长和长期高压，动脉变硬，无法扩张，收缩压明显升高。',
      },
      set: { hr: 70, stiffness: 0.8 },
    },
    {
      kind: 'watch',
      caption: { en: 'Salt and extra fluid add volume — higher still.', zh: '高盐和体液增多使血容量增加——血压更高。' },
      set: { volume: 0.9 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Bring it below 130/80: less salt (volume) and softer arteries (exercise, medicine).',
        zh: '试一试：降到 130/80 以下——少盐（容量）、改善血管弹性（运动、药物）。',
      },
      try: {
        mode: 'scrub',
        scrubs: [
          { param: 'volume', label: 'Volume 血容量', min: 0, max: 1 },
          { param: 'stiffness', label: 'Stiffness 血管硬化', min: 0, max: 1 },
        ],
        success: (p) => {
          const { systolic, diastolic } = pressures(p);
          return systolic < 130 && diastolic < 80;
        },
        ok: { en: 'Below 130/80 — the normal range.', zh: '低于 130/80——正常范围。' },
        demo: { volume: 0.2, stiffness: 0.3 },
      },
    },
    {
      kind: 'try',
      caption: { en: 'Free play: heart rate, stiffness, volume.', zh: '自由探索：心率、血管硬化、血容量。' },
      try: {
        mode: 'scrub',
        scrubs: [
          { param: 'hr', label: 'Heart rate 心率', min: 40, max: 180, unit: 'bpm', digits: 0 },
          { param: 'stiffness', label: 'Stiffness 血管硬化', min: 0, max: 1 },
          { param: 'volume', label: 'Volume 血容量', min: 0, max: 1 },
        ],
        success: () => true,
        ok: { en: 'Normal: under 120/80. High: 140/90 or more.', zh: '正常：低于 120/80；高血压：≥ 140/90。' },
      },
    },
  ],
};
