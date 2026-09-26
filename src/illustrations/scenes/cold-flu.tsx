import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Scenario, SceneProps } from '../types';

const SYMPTOMS: { label: string; cold: number; flu: number }[] = [
  { label: 'Fever 发热', cold: 0.1, flu: 0.9 },
  { label: 'Aches 肌肉酸痛', cold: 0.2, flu: 0.9 },
  { label: 'Exhaustion 乏力', cold: 0.3, flu: 0.95 },
  { label: 'Cough 咳嗽', cold: 0.4, flu: 0.7 },
  { label: 'Runny nose 流涕', cold: 0.9, flu: 0.3 },
  { label: 'Sore throat 咽痛', cold: 0.7, flu: 0.4 },
];

const wrap = (x: number, span: number) => ((x % span) + span) % span;

function ColdFluScene({ params, t }: SceneProps) {
  const f = params.flu;
  const deep = f;
  return (
    <G>
      <Circle cx={80} cy={60} r={36} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
      <Path d="M 84 70 L 90 110 L 90 150 M 90 150 L 60 200 M 90 150 L 120 200" stroke="#E8C4B0" strokeWidth={10} fill="none" strokeLinecap="round" />
      <Text x={20} y={228} fontSize={10} fill="#555">nose & throat 鼻咽 · airways · lungs 肺</Text>
      {Array.from({ length: 10 }, (_, i) => {
        const inLungs = i / 10 < deep * 0.7;
        const cx = inLungs ? 70 + (i % 2) * 40 + Math.sin(t * 2 + i) * 6 : 88 + Math.sin(t * 2 + i) * 8;
        const cy = inLungs ? 170 + (i % 3) * 10 : 70 + wrap(i * 13, 40);
        return <Circle key={i} cx={cx} cy={cy} r={4} fill="#7A3FA0" opacity={0.85} />;
      })}

      {SYMPTOMS.map((s, i) => {
        const v = s.cold + (s.flu - s.cold) * f;
        const y = 30 + i * 34;
        return (
          <G key={s.label}>
            <Text x={170} y={y} fontSize={10} fill="#555">{s.label}</Text>
            <Rect x={170} y={y + 5} width={170} height={10} rx={5} fill="#EEE" />
            <Rect x={170} y={y + 5} width={170 * v} height={10} rx={5} fill={v > 0.6 ? '#D8434B' : '#E39B4B'} />
          </G>
        );
      })}
      <Text x={20} y={256} fontSize={12} fontWeight="bold" fill="#6C4F9E">
        {f > 0.5 ? 'Flu 流感 — sudden, whole body 起病急、全身症状' : 'Cold 感冒 — gradual, nose & throat 起病缓、鼻咽症状'}
      </Text>
      <Text x={20} y={280} fontSize={10} fill="#555">virus 病毒 ● — antibiotics don’t kill viruses 抗生素对病毒无效</Text>
    </G>
  );
}

export const coldFlu: Scenario = {
  id: 'cold-vs-flu',
  group: 'illness',
  title: { en: 'Cold vs flu', zh: '感冒与流感' },
  params: { flu: 0 },
  Scene: ColdFluScene,
  sources: ['CDC “Cold versus flu”; WHO influenza fact sheet'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'A cold: viruses stay in the nose and throat. Comes on slowly, mild.', zh: '普通感冒：病毒停留在鼻咽部。起病缓慢，症状轻。' },
      set: { flu: 0 },
    },
    {
      kind: 'watch',
      caption: { en: 'Flu: reaches deeper airways, hits suddenly — high fever, aches, exhaustion.', zh: '流感：可侵入下呼吸道，起病急——高热、全身酸痛、极度乏力。' },
      set: { flu: 1 },
    },
    {
      kind: 'try',
      caption: { en: 'Switch between them and watch the symptoms change.', zh: '试一试：切换对比，观察症状变化。' },
      try: {
        mode: 'compare',
        param: 'flu',
        options: [
          { label: 'Cold 感冒', value: 0 },
          { label: 'Flu 流感', value: 1 },
        ],
        success: () => true,
        ok: { en: 'Fever + aches + sudden start points to flu.', zh: '发热 + 酸痛 + 起病急，提示流感。' },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Rest and fluids for both. Flu: antivirals work best within 48 h; yearly vaccine. See a doctor if breathless, chest pain, confused, or fever over 3 days.',
        zh: '两者均需休息、多饮水。流感：48 小时内用抗病毒药效果最好；每年接种疫苗。出现气促、胸痛、意识模糊或发热超过 3 天需就医。',
      },
    },
  ],
};
