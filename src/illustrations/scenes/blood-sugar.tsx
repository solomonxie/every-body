import { Circle, G, Line, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

const CELLS = [60, 140, 220, 300];
const VESSEL_TOP = 40;
const VESSEL_BOTTOM = 130;

/** mmol/L — absorbed from the meal, cleared by insulin-opened cells and by exercising muscle */
export function glucose({ meal, insulin, resistance, exercise }: Params) {
  const absorbed = meal * 6;
  const cleared = absorbed * insulin * (1 - resistance) * 0.85 + exercise * 2.5 * (1 - 0.3 * resistance);
  return Math.max(3.2, Math.min(20, 5 + absorbed - cleared));
}

const level = (g: number) => (g < 3.9 ? '#3F95D6' : g <= 7.8 ? '#2E9E5B' : g <= 11 ? '#E39B4B' : '#D8434B');
const wrap = (x: number, span: number) => ((x % span) + span) % span;

function BloodSugarScene({ params, t }: SceneProps) {
  const g = glucose(params);
  const doorOpen = params.insulin * (1 - params.resistance) + params.exercise * 0.5;
  const sugarDots = Math.round(g * 4);
  const keys = Math.round(params.insulin * 8);
  const flowing = doorOpen > 0.15 && g > 4.5;

  return (
    <G>
      <Rect x={0} y={VESSEL_TOP} width={360} height={VESSEL_BOTTOM - VESSEL_TOP} fill="#F7DADA" />
      <Line x1={0} y1={VESSEL_TOP} x2={360} y2={VESSEL_TOP} stroke="#C0555F" strokeWidth={3} />
      <Line x1={0} y1={VESSEL_BOTTOM} x2={360} y2={VESSEL_BOTTOM} stroke="#C0555F" strokeWidth={3} />
      <Text x={8} y={VESSEL_TOP - 8} fontSize={11} fill="#8A3B45">Blood 血液 →</Text>

      {Array.from({ length: sugarDots }, (_, i) => (
        <Circle
          key={`g${i}`}
          cx={wrap(i * 73.3 + t * 28 * (0.7 + (i % 5) * 0.1), 380) - 10}
          cy={VESSEL_TOP + 10 + wrap(i * 37.7, 70)}
          r={3.5}
          fill="#F2B233"
        />
      ))}
      {Array.from({ length: keys }, (_, i) => {
        const x = wrap(i * 47 + t * 22, 380) - 10;
        const y = VESSEL_TOP + 20 + wrap(i * 29, 50);
        return <Path key={`k${i}`} d={`M ${x} ${y - 5} L ${x + 5} ${y} L ${x} ${y + 5} L ${x - 5} ${y} Z`} fill="#3F7FD6" />;
      })}

      {CELLS.map((cx) => {
        const gap = 6 + doorOpen * 16;
        const inside = Math.round(Math.min(10, (1 - Math.min(1, (g - 4) / 12)) * 10 * Math.min(1, doorOpen + 0.2)));
        return (
          <G key={cx}>
            <Path
              d={`M ${cx - gap} 170 A 34 34 0 1 0 ${cx + gap} 170`}
              fill="#E7F2DA"
              stroke="#6E9E4F"
              strokeWidth={3}
              transform={`rotate(0 ${cx} 204)`}
            />
            {flowing &&
              [0, 1, 2].map((j) => (
                <Circle key={j} cx={cx} cy={VESSEL_BOTTOM + wrap(t * 30 + j * 14, 42)} r={3} fill="#F2B233" />
              ))}
            {Array.from({ length: inside }, (_, j) => (
              <Circle key={`in${j}`} cx={cx - 14 + (j % 4) * 9} cy={196 + Math.floor(j / 4) * 9} r={3} fill="#F2B233" />
            ))}
          </G>
        );
      })}
      <Text x={8} y={262} fontSize={11} fill="#4F7A38">Body cells 细胞 (doors open with insulin 胰岛素)</Text>

      <Rect x={214} y={4} width={142} height={30} rx={8} fill="#FFFFFF" stroke={level(g)} strokeWidth={2} />
      <Text x={285} y={24} fontSize={14} fontWeight="bold" fill={level(g)} textAnchor="middle">
        {`血糖 ${g.toFixed(1)} mmol/L`}
      </Text>
      <Circle cx={20} cy={284} r={4} fill="#F2B233" />
      <Text x={28} y={288} fontSize={10} fill="#555">glucose 葡萄糖</Text>
      <Path d="M 120 279 L 125 284 L 120 289 L 115 284 Z" fill="#3F7FD6" />
      <Text x={130} y={288} fontSize={10} fill="#555">insulin 胰岛素</Text>
    </G>
  );
}

export const bloodSugar: Scenario = {
  id: 'blood-sugar',
  group: 'blood',
  title: { en: 'Blood sugar', zh: '血糖' },
  params: { meal: 0, insulin: 0.3, resistance: 0, exercise: 0 },
  Scene: BloodSugarScene,
  sources: ['WHO diabetes fact sheet; ADA Standards of Care (glucose targets)'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'Fasting: blood sugar sits near 5 mmol/L.', zh: '空腹时，血糖约 5 mmol/L。' },
      set: { meal: 0, insulin: 0.3, resistance: 0, exercise: 0 },
    },
    {
      kind: 'watch',
      caption: { en: 'A meal is digested into glucose, which floods the blood.', zh: '进餐后，食物分解为葡萄糖，进入血液，血糖升高。' },
      set: { meal: 1, insulin: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'The pancreas releases insulin — keys that open the cells. Glucose moves in and blood sugar falls.',
        zh: '胰腺分泌胰岛素——像钥匙打开细胞，葡萄糖进入细胞，血糖回落。',
      },
      set: { insulin: 1 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Type 2 diabetes: cells resist insulin. Doors barely open, so sugar stays high.',
        zh: '2型糖尿病：细胞对胰岛素抵抗，门几乎打不开，血糖居高不下。',
      },
      set: { resistance: 0.7 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Your turn: add exercise — working muscles take up sugar even with little insulin. Get it under 7.8.',
        zh: '试一试：增加运动——肌肉运动时即使胰岛素不足也能摄取葡萄糖。把血糖降到 7.8 以下。',
      },
      set: { exercise: 0 },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'exercise', label: 'Exercise 运动', min: 0, max: 1 }],
        success: (p) => glucose(p) < 7.8,
        ok: { en: 'Under 7.8 — exercise works alongside insulin.', zh: '低于 7.8——运动与胰岛素协同降糖。' },
        demo: { exercise: 1 },
      },
    },
    {
      kind: 'try',
      caption: { en: 'Free play: change the meal, insulin, resistance and exercise.', zh: '自由探索：调节进食、胰岛素、抵抗和运动。' },
      try: {
        mode: 'scrub',
        scrubs: [
          { param: 'meal', label: 'Meal 进食', min: 0, max: 1 },
          { param: 'insulin', label: 'Insulin 胰岛素', min: 0, max: 1 },
          { param: 'resistance', label: 'Resistance 抵抗', min: 0, max: 1 },
          { param: 'exercise', label: 'Exercise 运动', min: 0, max: 1 },
        ],
        success: () => true,
        ok: { en: 'Normal range after meals: under 7.8 mmol/L.', zh: '餐后正常：低于 7.8 mmol/L。' },
      },
    },
  ],
};
