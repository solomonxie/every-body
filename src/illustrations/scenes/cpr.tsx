import { Circle, G, Line, Path, Rect, Text } from 'react-native-svg';

import type { Scenario, SceneProps } from '../types';

const FLOOR = 250;
const TARGET = 30;
const MIN_RATE = 100;
const MAX_RATE = 120;

const rateColor = (rate: number) => (rate === 0 ? '#777' : rate < MIN_RATE ? '#E39B4B' : rate > MAX_RATE ? '#D8434B' : '#2E9E5B');
const wrap = (x: number, span: number) => ((x % span) + span) % span;

function CprScene({ params, t }: SceneProps) {
  const { stage, press, taps, rate } = params;
  const s = Math.round(stage);
  const dip = press * 14;
  const breath = s === 3 ? Math.max(0, Math.sin(t * 2.2)) : 0;
  const lift = breath * 6;
  const perfusion = s >= 2 && taps > 0 ? Math.min(1, rate / 110) * (rate > 130 ? 0.8 : 1) : 0;

  return (
    <G>
      <Line x1={0} y1={FLOOR} x2={360} y2={FLOOR} stroke="#BBB" strokeWidth={2} />
      <Circle cx={58} cy={224} r={20} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
      <Path
        d={`M 80 ${212 - lift} L 122 ${212 - lift} Q 155 ${212 + dip * 2 - lift} 188 ${212 - lift} L 270 214 L 270 246 L 80 246 Z`}
        fill="#8FB3E0"
        stroke="#5F87B8"
        strokeWidth={2}
      />
      <Rect x={270} y={224} width={82} height={20} rx={8} fill="#5B6B8C" />
      <Circle cx={152} cy={230} r={9 * (1 - 0.35 * press)} fill="#C8323C" />

      {s >= 2 &&
        perfusion > 0 &&
        [0, 1, 2, 3].map((i) => {
          const u = wrap(t * (0.4 + perfusion) + i / 4, 1);
          return <Circle key={i} cx={152 - u * 90} cy={230 - Math.sin(u * Math.PI) * 14} r={3} fill="#C8323C" opacity={perfusion} />;
        })}

      {s >= 1 && s !== 3 && (
        <G>
          <Circle cx={160} cy={70} r={16} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
          <Path d={`M 160 86 L 172 130 L 196 ${FLOOR - 4}`} stroke="#6E6E80" strokeWidth={10} fill="none" strokeLinecap="round" />
          <Line x1={158} y1={100} x2={153} y2={150 + dip} stroke="#F2C9A5" strokeWidth={8} strokeLinecap="round" />
          <Rect x={138} y={150 + dip} width={30} height={14} rx={6} fill="#F2C9A5" stroke="#C9A58A" />
          <Rect x={140} y={160 + dip} width={28} height={12} rx={6} fill="#EBB98F" stroke="#C9A58A" />
          <Line x1={155} y1={120} x2={155} y2={140} stroke="#999" strokeDasharray="3 3" />
          <Text x={176} y={150} fontSize={10} fill="#555">arms straight 手臂伸直</Text>
          <Text x={176} y={164} fontSize={10} fill="#555">center of chest 胸部正中</Text>
        </G>
      )}

      {s === 0 && (
        <G>
          <Text x={30} y={180} fontSize={12} fill="#D8434B">! Tap shoulders, shout 拍肩呼叫</Text>
          <Text x={30} y={198} fontSize={11} fill="#555">Breathing normally? Look ≤ 10 s 观察呼吸</Text>
          <Rect x={210} y={20} width={140} height={60} rx={10} fill="#FFF3F3" stroke="#D8434B" strokeWidth={2} />
          <Text x={280} y={46} fontSize={18} fontWeight="bold" fill="#D8434B" textAnchor="middle">☎ 120 / 911</Text>
          <Text x={280} y={66} fontSize={10} fill="#D8434B" textAnchor="middle">call · speaker on 开免提</Text>
        </G>
      )}

      {s === 3 && (
        <G>
          <Circle cx={30} cy={196} r={16} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
          <Path d="M 44 204 Q 52 214 56 214" stroke="#3F95D6" strokeWidth={3} fill="none" opacity={breath} />
          <Text x={80} y={180} fontSize={11} fill="#3F95D6">2 breaths, 1 s each 人工呼吸2次</Text>
          <Text x={80} y={196} fontSize={10} fill="#555">tilt head, lift chin — watch the chest rise</Text>
        </G>
      )}

      {s === 4 && (
        <G>
          <Rect x={284} y={150} width={56} height={40} rx={6} fill="#2E9E5B" />
          <Text x={312} y={176} fontSize={14} fontWeight="bold" fill="#FFFFFF" textAnchor="middle">AED</Text>
          <Line x1={290} y1={190} x2={140} y2={214} stroke="#2E9E5B" strokeWidth={2} />
          <Line x1={296} y1={190} x2={210} y2={222} stroke="#2E9E5B" strokeWidth={2} />
          <Text x={200} y={130} fontSize={11} fill="#2E9E5B">Use the AED as soon as it arrives</Text>
        </G>
      )}

      {s >= 2 && (
        <G>
          <Rect x={8} y={6} width={200} height={46} rx={8} fill="#FFFFFF" stroke={rateColor(rate)} strokeWidth={2} />
          <Text x={18} y={24} fontSize={12} fill="#333">{`Compressions 按压 ${Math.round(taps)}/${TARGET}`}</Text>
          <Text x={18} y={42} fontSize={12} fontWeight="bold" fill={rateColor(rate)}>
            {rate > 0 ? `${Math.round(rate)} /min (target 100–120)` : 'target 100–120 /min'}
          </Text>
          <Text x={224} y={24} fontSize={10} fill="#555">Blood to brain 脑供血</Text>
          <Rect x={224} y={32} width={124} height={10} rx={5} fill="#EEE" />
          <Rect x={224} y={32} width={124 * perfusion} height={10} rx={5} fill="#C8323C" />
        </G>
      )}
    </G>
  );
}

export const cpr: Scenario = {
  id: 'cpr',
  group: 'first-aid',
  title: { en: 'CPR', zh: '心肺复苏' },
  params: { stage: 0, press: 0, taps: 0, rate: 0 },
  Scene: CprScene,
  sources: ['ILCOR 2025 CoSTR / AHA & Red Cross adult BLS: 100–120/min, 5–6 cm, 30:2'],
  steps: [
    {
      kind: 'watch',
      caption: {
        en: 'Someone collapses. Tap and shout. Not breathing normally? Call 120/911 on speaker and start CPR.',
        zh: '有人倒地：拍肩呼叫。无正常呼吸？立即拨打 120（开免提），开始心肺复苏。',
      },
      set: { stage: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Heel of the hand on the center of the chest, other hand on top. Arms straight, shoulders over the hands.',
        zh: '掌根放在胸部正中，另一手叠放其上。手臂伸直，肩在手的正上方。',
      },
      set: { stage: 1 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Your turn: tap the button for each compression — 30 of them, 100–120 per minute, 5–6 cm deep.',
        zh: '试一试：每按一次点击按钮——共 30 次，频率每分钟 100–120 次，深度 5–6 厘米。',
      },
      set: { stage: 2, taps: 0, rate: 0 },
      try: {
        mode: 'rhythm',
        target: TARGET,
        minRate: MIN_RATE,
        maxRate: MAX_RATE,
        success: (p) => p.taps >= TARGET && p.rate >= MIN_RATE && p.rate <= MAX_RATE,
        ok: { en: '30 at the right pace — that keeps blood reaching the brain.', zh: '30 次，节奏正确——保证大脑供血。' },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'If trained, give 2 rescue breaths. If not, keep doing compressions only.',
        zh: '受过培训可给予 2 次人工呼吸；未受培训则持续胸外按压。',
      },
      set: { stage: 3 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Keep going 30:2 without pausing until help or an AED arrives. Switch the AED on and follow its voice.',
        zh: '按 30:2 持续进行，直到急救人员或 AED 到达。打开 AED，按语音提示操作。',
      },
      set: { stage: 4 },
    },
  ],
};
