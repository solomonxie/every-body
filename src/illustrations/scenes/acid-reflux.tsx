import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

/** how high acid climbs the oesophagus (0..1) */
export const refluxOf = ({ valveWeak, lying, antacid }: Params) =>
  Math.max(0, Math.min(1, valveWeak * (0.3 + 0.7 * lying) * (1 - 0.8 * antacid)));

function RefluxScene({ params, t }: SceneProps) {
  const reflux = refluxOf(params);
  const slosh = Math.sin(t * 2) * 3;
  return (
    <G>
      <G>
        <Rect x={170} y={20} width={20} height={150} rx={8} fill="#F4D3C4" stroke="#C98A7A" strokeWidth={2} />
        <Path d="M 170 170 C 110 170, 100 260, 170 270 C 250 280, 270 200, 190 170 Z" fill="#F4D3C4" stroke="#C98A7A" strokeWidth={2} />
        <Path d={`M 118 ${240 + slosh} C 140 ${230 - slosh}, 210 ${230 + slosh}, 250 ${238 - slosh} L 240 262 C 210 280, 140 280, 118 250 Z`} fill="#E3C23A" opacity={0.85} />
        <Rect x={172} y={166} width={16} height={8} fill={params.valveWeak > 0.5 ? '#E39B4B' : '#8A3B45'} />
        {reflux > 0.02 && <Rect x={173} y={170 - reflux * 140} width={14} height={reflux * 140} fill="#E3C23A" opacity={0.85} />}
        <Text x={196} y={60} fontSize={10} fill="#8A6A5A">oesophagus 食管</Text>
        <Text x={196} y={176} fontSize={10} fill="#8A6A5A">valve 贲门括约肌</Text>
        <Text x={150} y={292} fontSize={10} fill="#8A6A5A">stomach acid 胃酸 pH 1.5–3.5</Text>
      </G>
      <G transform="translate(300 70)">
        {params.lying > 0.5 ? (
          <G>
            <Circle cx={-30} cy={20} r={8} fill="#6C4F9E" />
            <Path d="M -20 20 L 30 20 M -5 20 L -10 32 M 15 20 L 20 32" stroke="#6C4F9E" strokeWidth={5} strokeLinecap="round" />
          </G>
        ) : (
          <G>
            <Circle cx={0} cy={-20} r={8} fill="#6C4F9E" />
            <Path d="M 0 -10 L 0 25 M 0 25 L -10 45 M 0 25 L 10 45 M 0 0 L -12 12 M 0 0 L 12 12" stroke="#6C4F9E" strokeWidth={5} strokeLinecap="round" />
          </G>
        )}
        <Text x={0} y={62} fontSize={10} fill="#6C4F9E" textAnchor="middle">{params.lying > 0.5 ? 'lying flat 平躺' : 'upright 直立'}</Text>
      </G>
      {Array.from({ length: Math.round(reflux * 6) }, (_, i) => (
        <Circle key={i} cx={60 + i * 8} cy={40 + ((t * 30 + i * 9) % 20)} r={3} fill="#E0503C" />
      ))}
      <Rect x={8} y={6} width={150} height={44} rx={8} fill="#FFFFFF" stroke={reflux > 0.3 ? '#D8434B' : '#2E9E5B'} strokeWidth={2} />
      <Text x={20} y={26} fontSize={12} fontWeight="bold" fill={reflux > 0.3 ? '#D8434B' : '#2E9E5B'}>{`Reflux 反流 ${Math.round(reflux * 100)}%`}</Text>
      <Text x={20} y={42} fontSize={10} fill="#555">{reflux > 0.3 ? 'heartburn 烧心' : 'comfortable 无不适'}</Text>
    </G>
  );
}

export const acidReflux: Scenario = {
  id: 'acid-reflux',
  group: 'illness',
  title: { en: 'Acid reflux & heartburn', zh: '胃食管反流' },
  params: { valveWeak: 0, lying: 0, antacid: 0 },
  Scene: RefluxScene,
  sources: ['ACG 2022 GERD guideline'],
  steps: [
    { kind: 'watch', caption: { en: 'A ring of muscle at the stomach’s top keeps acid down.', zh: '胃入口的括约肌环把胃酸挡在胃里。' }, set: { valveWeak: 0, lying: 0, antacid: 0 } },
    { kind: 'watch', caption: { en: 'When it relaxes too often, acid splashes up and burns — heartburn.', zh: '括约肌松弛时，胃酸反流灼伤食管——烧心。' }, set: { valveWeak: 1 } },
    { kind: 'watch', caption: { en: 'Lying flat after a big meal makes it worse — gravity stops helping.', zh: '饱餐后平躺会加重——重力不再帮忙。' }, set: { lying: 1 } },
    {
      kind: 'try',
      caption: { en: 'Compare: lying flat vs. head of the bed raised.', zh: '对比：平躺 vs. 抬高床头。' },
      try: {
        mode: 'compare',
        param: 'lying',
        options: [
          { label: 'Flat 平躺', value: 1 },
          { label: 'Raised 抬高', value: 0.3 },
        ],
        success: (p) => p.lying < 0.5,
        ok: { en: 'Raise the head 15–20 cm, don’t eat 3 h before bed, smaller meals.', zh: '床头抬高 15–20 厘米，睡前 3 小时不进食，少食多餐。' },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'See a doctor if it’s weekly, food sticks, you lose weight or vomit blood.',
        zh: '每周发作、吞咽梗阻、体重下降或呕血时应就医。',
      },
    },
  ],
};
