import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Scenario, SceneProps } from '../types';

const WOUND = { x: 190, y: 150 };
const wrap = (x: number, span: number) => ((x % span) + span) % span;

function BleedingScene({ params, t }: SceneProps) {
  const { pressure, clot, bandage } = params;
  const flow = Math.max(0, (1 - pressure * 0.85) * (1 - clot));
  const drops = Math.round(flow * 10);
  const lost = Math.min(1, params.lost);

  return (
    <G>
      <Rect x={20} y={120} width={320} height={64} rx={30} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
      <Text x={30} y={112} fontSize={10} fill="#8F7E63">forearm 前臂</Text>
      <Path d={`M ${WOUND.x - 22} ${WOUND.y} Q ${WOUND.x} ${WOUND.y - 6} ${WOUND.x + 22} ${WOUND.y}`} stroke="#8A1F2B" strokeWidth={5} fill="none" />
      {Array.from({ length: drops }, (_, i) => {
        const u = wrap(t * 1.4 + i / drops, 1);
        return <Circle key={i} cx={WOUND.x - 10 + (i % 3) * 10} cy={WOUND.y + 10 + u * 110} r={4 - u * 1.5} fill="#C8323C" opacity={1 - u * 0.4} />;
      })}
      <Path d={`M 150 262 Q 190 ${262 - lost * 20} 230 262 Z`} fill="#C8323C" opacity={0.8} />

      {pressure > 0.05 && bandage < 0.5 && (
        <G opacity={pressure}>
          <Rect x={WOUND.x - 36} y={WOUND.y - 30 + (1 - pressure) * -20} width={72} height={40} rx={6} fill="#FFFFFF" stroke="#BBB" />
          <Path d={`M ${WOUND.x - 30} ${WOUND.y - 40} q 30 -40 60 0`} stroke="#EBB98F" strokeWidth={22} fill="none" strokeLinecap="round" />
          <Text x={WOUND.x + 48} y={WOUND.y - 40} fontSize={10} fill="#555">firm pressure 用力按压</Text>
        </G>
      )}
      {bandage > 0.5 && (
        <G>
          {[0, 1, 2, 3].map((i) => (
            <Rect key={i} x={WOUND.x - 44 + i * 4} y={122} width={80} height={60} rx={4} fill="#FFFFFF" stroke="#DDD" opacity={0.9} />
          ))}
          <Text x={WOUND.x} y={200} fontSize={10} fill="#555" textAnchor="middle">bandage over the pad 加压包扎</Text>
        </G>
      )}

      <Rect x={8} y={6} width={344} height={50} rx={8} fill="#FFFFFF" stroke={flow > 0.3 ? '#D8434B' : '#2E9E5B'} strokeWidth={2} />
      <Text x={20} y={26} fontSize={12} fontWeight="bold" fill={flow > 0.3 ? '#D8434B' : '#2E9E5B'}>
        {`Bleeding 出血  ${Math.round(flow * 100)}%`}
      </Text>
      <Text x={20} y={44} fontSize={11} fill="#555">{`Clot forming 血凝块  ${Math.round(clot * 100)}%`}</Text>
      <Rect x={200} y={36} width={140} height={8} rx={4} fill="#EEE" />
      <Rect x={200} y={36} width={140 * clot} height={8} rx={4} fill="#2E9E5B" />
    </G>
  );
}

export const bleeding: Scenario = {
  id: 'severe-bleeding',
  group: 'first-aid',
  title: { en: 'Severe bleeding', zh: '大出血止血' },
  params: { pressure: 0, clot: 0, bandage: 0, lost: 0.3 },
  Scene: BleedingScene,
  sources: ['ILCOR / Red Cross first aid: direct pressure; tourniquet for life-threatening limb bleeding'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'A deep cut is bleeding heavily. Every minute counts.', zh: '深部伤口大量出血，分秒必争。' },
      set: { pressure: 0, clot: 0, bandage: 0, lost: 0.5 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Call 120/911. Protect your hands if you can (gloves or a plastic bag).',
        zh: '拨打 120。尽量保护双手（手套或塑料袋）。',
      },
    },
    {
      kind: 'try',
      caption: {
        en: 'Press firmly on the wound with a clean pad — and keep pressing. Don’t lift to peek.',
        zh: '试一试：用干净敷料用力按压伤口并持续按住，不要松开查看。',
      },
      try: {
        mode: 'hold',
        param: 'pressure',
        progress: 'clot',
        seconds: 8,
        label: 'HOLD 按住',
        success: (p) => p.clot >= 1,
        ok: { en: 'Steady pressure lets a clot form (in real life: at least 10 minutes).', zh: '持续按压让血凝块形成（实际至少 10 分钟）。' },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Soaked through? Add more pads on top — don’t remove the first. Then bandage firmly.',
        zh: '渗透了？在上面再加敷料，不要取下第一层。然后加压包扎。',
      },
      set: { pressure: 1, clot: 1, bandage: 1 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'If pressure can’t stop life-threatening bleeding on an arm or leg, a tourniquet goes 5–7 cm above the wound. Note the time.',
        zh: '四肢危及生命的出血按压无效时，在伤口上方 5–7 厘米处使用止血带，并记录时间。',
      },
    },
  ],
};
