import { Circle, Ellipse, G, Line, Path, Text } from 'react-native-svg';

import type { Scenario, SceneProps } from '../types';

// Typical size by gestational week (crown–rump before 20 w, crown–heel after), weight in grams.
const TABLE: { week: number; cm: number; g: number; like: string }[] = [
  { week: 6, cm: 0.6, g: 0.1, like: 'lentil 扁豆' },
  { week: 8, cm: 1.6, g: 1, like: 'raspberry 树莓' },
  { week: 12, cm: 5.4, g: 14, like: 'lime 青柠' },
  { week: 16, cm: 11.6, g: 100, like: 'avocado 牛油果' },
  { week: 20, cm: 25.6, g: 300, like: 'banana 香蕉' },
  { week: 24, cm: 30, g: 600, like: 'corn 玉米' },
  { week: 28, cm: 37.6, g: 1000, like: 'aubergine 茄子' },
  { week: 32, cm: 42.4, g: 1700, like: 'squash 南瓜' },
  { week: 36, cm: 47.4, g: 2600, like: 'papaya 木瓜' },
  { week: 40, cm: 51.2, g: 3400, like: 'watermelon 西瓜' },
];

export function sizeAt(week: number) {
  const i = Math.max(0, TABLE.findIndex((row) => row.week >= week) - 1);
  const a = TABLE[i];
  const b = TABLE[Math.min(TABLE.length - 1, i + 1)];
  const u = b.week === a.week ? 0 : Math.max(0, Math.min(1, (week - a.week) / (b.week - a.week)));
  return { cm: a.cm + (b.cm - a.cm) * u, g: a.g + (b.g - a.g) * u, like: u < 0.5 ? a.like : b.like };
}

function FetalGrowthScene({ params, t }: SceneProps) {
  const { cm, g, like } = sizeAt(params.week);
  const s = Math.max(0.08, cm / 51.2);
  const uterus = 40 + 90 * Math.min(1, params.week / 40);
  const kick = params.week >= 20 ? Math.max(0, Math.sin(t * 3)) ** 8 * 6 : 0;
  return (
    <G>
      <Path d="M 70 20 C 60 90, 60 160, 90 280" stroke="#C9A58A" strokeWidth={3} fill="none" />
      <Path d={`M 110 30 C ${120 + uterus} 60, ${130 + uterus * 1.1} 200, 120 280`} stroke="#C9A58A" strokeWidth={3} fill="#F7E0D0" />
      <Ellipse cx={120 + uterus * 0.35} cy={200 - uterus * 0.2} rx={uterus * 0.5} ry={uterus * 0.62} fill="#F2B8C0" opacity={0.6} />
      <G transform={`translate(${120 + uterus * 0.35} ${200 - uterus * 0.2}) scale(${s})`}>
        <Circle cx={-10} cy={-45} r={34} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2 / s} />
        <Ellipse cx={8} cy={20} rx={38} ry={50} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2 / s} />
        <Line x1={30} y1={50} x2={10 + kick} y2={70} stroke="#EBB98F" strokeWidth={14} strokeLinecap="round" />
        <Line x1={-20} y1={0} x2={-40} y2={30} stroke="#EBB98F" strokeWidth={12} strokeLinecap="round" />
      </G>
      <Line x1={260} y1={40} x2={260} y2={40 + cm * 4} stroke="#6C4F9E" strokeWidth={4} strokeLinecap="round" />
      <Text x={270} y={50} fontSize={11} fill="#6C4F9E">{`${cm.toFixed(1)} cm`}</Text>
      <Text x={270} y={66} fontSize={11} fill="#6C4F9E">{g < 10 ? `${g.toFixed(1)} g` : `${Math.round(g)} g`}</Text>
      <Text x={20} y={290} fontSize={13} fontWeight="bold" fill="#6C4F9E">{`Week 第 ${Math.round(params.week)} 周 · about a ${like}`}</Text>
    </G>
  );
}

export const fetalGrowth: Scenario = {
  id: 'fetal-growth',
  group: 'pregnancy',
  title: { en: 'Pregnancy week by week', zh: '孕期胎儿发育' },
  params: { week: 8 },
  Scene: FetalGrowthScene,
  sources: ['Typical fetal length/weight by gestational age (ACOG, Hadlock)'],
  steps: [
    { kind: 'watch', caption: { en: 'Week 8: the heart is beating; about the size of a raspberry.', zh: '第 8 周：心脏已开始跳动，约树莓大小。' }, set: { week: 8 } },
    { kind: 'watch', caption: { en: 'Week 12: all organs formed; the first-trimester scan.', zh: '第 12 周：器官基本形成，孕早期超声检查。' }, set: { week: 12 } },
    { kind: 'watch', caption: { en: 'Week 20: halfway. Movements (quickening) are felt.', zh: '第 20 周：孕期过半，开始感到胎动。' }, set: { week: 20 } },
    { kind: 'watch', caption: { en: 'Week 28: eyes open; a baby born now often survives with care.', zh: '第 28 周：眼睛睁开；此时早产经救治多可存活。' }, set: { week: 28 } },
    { kind: 'watch', caption: { en: 'Week 40: full term — about 50 cm and 3.4 kg.', zh: '第 40 周：足月——约 50 厘米、3.4 公斤。' }, set: { week: 40 } },
    {
      kind: 'try',
      caption: { en: 'Drag through the weeks.', zh: '试一试：拖动孕周。' },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'week', label: 'Week 孕周', min: 6, max: 40, digits: 0 }],
        success: () => true,
        ok: { en: 'Fundal height in cm ≈ weeks, from about week 20.', zh: '约 20 周后，宫高（厘米）≈ 孕周数。' },
      },
    },
  ],
};
