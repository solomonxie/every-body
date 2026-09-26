import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

export const stageOf = ({ cm, descent, placenta }: Params) =>
  placenta > 0.5 ? 3 : descent > 0.05 ? 2 : cm < 6 ? 1 : 1.5;

const STAGE_TEXT: Record<number, string> = {
  1: 'Stage 1 · early (latent) 第一产程 潜伏期',
  1.5: 'Stage 1 · active 第一产程 活跃期',
  2: 'Stage 2 · pushing & birth 第二产程',
  3: 'Stage 3 · placenta 第三产程',
};

function LaborScene({ params, t }: SceneProps) {
  const { cm, descent, placenta } = params;
  const period = cm < 6 ? 6 : 2.5;
  const squeeze = Math.max(0, Math.sin((t / period) * Math.PI * 2)) ** 3;
  const gap = (cm / 10) * 44;
  const headY = 150 + descent * 120;
  const stage = stageOf(params);
  return (
    <G>
      <Path
        d={`M ${100 - squeeze * 6} 40 C ${40 - squeeze * 6} 60, ${40 - squeeze * 6} 200, ${150 - gap / 2} 230 L ${150 + gap / 2} 230 C ${260 + squeeze * 6} 200, ${260 + squeeze * 6} 60, ${200 + squeeze * 6} 40 C 170 20, 130 20, ${100 - squeeze * 6} 40 Z`}
        fill="#F2B8C0"
        stroke="#C9788A"
        strokeWidth={8 + squeeze * 8}
      />
      {placenta < 0.5 && <Circle cx={150} cy={Math.min(headY, 250)} r={40} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />}
      <Path d={`M ${150 - gap / 2 - 30} 230 L ${150 - gap / 2} 236 M ${150 + gap / 2 + 30} 230 L ${150 + gap / 2} 236`} stroke="#8A3B45" strokeWidth={6} strokeLinecap="round" />
      <Text x={150} y={262} fontSize={10} fill="#8A3B45" textAnchor="middle">{`cervix 宫颈 ${cm.toFixed(0)} cm`}</Text>
      {placenta > 0.5 && <Path d="M 120 90 q 30 -30 60 0 q 10 30 -30 40 q -40 -5 -30 -40 Z" fill="#A83248" />}
      {squeeze > 0.3 && <Text x={270} y={120} fontSize={11} fill="#C9788A">contraction 宫缩</Text>}

      <Rect x={8} y={272} width={344} height={24} rx={8} fill="#FFFFFF" stroke="#6C4F9E" strokeWidth={2} />
      <Text x={20} y={288} fontSize={11} fontWeight="bold" fill="#6C4F9E">{STAGE_TEXT[stage]}</Text>
      <Text x={330} y={30} fontSize={10} fill="#555" textAnchor="end">{`every ${period === 6 ? '5–20' : '2–3'} min`}</Text>
    </G>
  );
}

export const labor: Scenario = {
  id: 'labor',
  group: 'pregnancy',
  title: { en: 'Labour & birth', zh: '分娩过程' },
  params: { cm: 1, descent: 0, placenta: 0 },
  Scene: LaborScene,
  sources: ['WHO intrapartum care 2018 (active phase from 5–6 cm)'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'Early labour: irregular contractions slowly soften and open the cervix.', zh: '潜伏期：不规律宫缩使宫颈逐渐变软、扩张。' },
      set: { cm: 2, descent: 0, placenta: 0 },
    },
    {
      kind: 'watch',
      caption: { en: 'Active labour (from ~6 cm): strong contractions every 2–3 minutes.', zh: '活跃期（约 6 厘米起）：强宫缩，每 2–3 分钟一次。' },
      set: { cm: 7 },
    },
    {
      kind: 'try',
      caption: { en: 'Open the cervix to full dilation — 10 cm.', zh: '试一试：宫口开全——10 厘米。' },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'cm', label: 'Dilation 宫口', min: 0, max: 10, unit: 'cm', digits: 0 }],
        success: (p) => p.cm >= 9.8,
        ok: { en: 'Fully dilated — time to push.', zh: '宫口开全——开始用力。' },
        demo: { cm: 10 },
      },
    },
    {
      kind: 'try',
      caption: { en: 'Stage 2: with each push the baby moves down and out.', zh: '试一试：第二产程：每次用力，胎儿下降娩出。' },
      set: { cm: 10 },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'descent', label: 'Descent 下降', min: 0, max: 1 }],
        success: (p) => p.descent >= 0.95,
        ok: { en: 'Born! 出生了！', zh: '宝宝出生。' },
        demo: { descent: 1 },
      },
    },
    {
      kind: 'watch',
      caption: { en: 'Stage 3: the placenta follows, usually within 30 minutes.', zh: '第三产程：胎盘娩出，通常在 30 分钟内。' },
      set: { descent: 1, placenta: 1 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Go to hospital: contractions regular ~5 min apart (first baby), waters break, bleeding, or fewer movements.',
        zh: '何时去医院：宫缩规律约 5 分钟一次（初产）、破水、出血或胎动减少。',
      },
    },
  ],
};
