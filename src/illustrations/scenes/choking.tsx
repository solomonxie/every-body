import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

// Side view: airway runs from the mouth (top) down to the lungs.
const AIRWAY = [
  { x: 150, y: 70 },
  { x: 160, y: 110 },
  { x: 162, y: 170 },
];

function objectAt(u: number) {
  // u = 0 lodged in the windpipe, u = 1 out of the mouth
  const a = AIRWAY[2];
  const b = AIRWAY[0];
  return { x: a.x + (b.x - a.x) * u - u * u * 40, y: a.y + (b.y - a.y) * u };
}

function ChokingScene({ params }: SceneProps) {
  const { stage, taps, press } = params;
  const s = Math.round(stage);
  const out = Math.min(1, params.dislodge);
  const obj = objectAt(out);
  const cleared = out >= 1;

  return (
    <G>
      <Circle cx={150} cy={60} r={34} fill="#F2C9A5" stroke="#C9A58A" strokeWidth={2} />
      <Rect x={110} y={96} width={100} height={170} rx={30} fill="#8FB3E0" stroke="#5F87B8" strokeWidth={2} />
      <Path d="M 150 72 L 160 110 L 162 176" stroke="#E8C4B0" strokeWidth={14} fill="none" strokeLinecap="round" />
      <Path d="M 162 176 L 140 200 M 162 176 L 184 200" stroke="#E8C4B0" strokeWidth={10} fill="none" strokeLinecap="round" />
      <Circle cx={obj.x} cy={obj.y} r={8} fill={cleared ? '#2E9E5B' : '#8A5A2B'} />
      <Text x={obj.x + 12} y={obj.y + 4} fontSize={10} fill="#555">{cleared ? 'out 排出' : 'food 异物'}</Text>

      {s === 0 && (
        <Text x={10} y={290} fontSize={11} fill="#D8434B">Can’t speak, cough or breathe 无法说话、咳嗽、呼吸</Text>
      )}
      {s === 1 && (
        <G>
          <Path d={`M ${250 - press * 12} 150 l 30 -10 l 6 20 l -30 10 Z`} fill="#EBB98F" stroke="#C9A58A" />
          <Text x={220} y={200} fontSize={10} fill="#555">heel of hand 掌根</Text>
          <Text x={220} y={214} fontSize={10} fill="#555">between shoulder blades</Text>
          <Text x={220} y={228} fontSize={10} fill="#555">两肩胛骨之间</Text>
        </G>
      )}
      {s === 2 && (
        <G>
          <Circle cx={100 + press * 10} cy={196} r={12} fill="#EBB98F" stroke="#C9A58A" />
          <Path d={`M ${70 + press * 10} 196 l 18 0`} stroke="#555" strokeWidth={2} />
          <Path d="M 116 186 l 10 -12" stroke="#D8434B" strokeWidth={3} />
          <Text x={10} y={230} fontSize={10} fill="#555">fist above the navel 肚脐上方</Text>
          <Text x={10} y={244} fontSize={10} fill="#555">pull in and up 向内向上冲击</Text>
        </G>
      )}

      <Rect x={220} y={6} width={132} height={44} rx={8} fill="#FFFFFF" stroke={cleared ? '#2E9E5B' : '#D8434B'} strokeWidth={2} />
      <Text x={286} y={26} fontSize={12} fontWeight="bold" fill={cleared ? '#2E9E5B' : '#D8434B'} textAnchor="middle">
        {cleared ? 'Airway clear 通畅' : 'Blocked 梗阻'}
      </Text>
      {s >= 1 && (
        <Text x={286} y={42} fontSize={10} fill="#555" textAnchor="middle">{`${Math.round(taps)} / 5`}</Text>
      )}
    </G>
  );
}

export const choking: Scenario = {
  id: 'choking',
  group: 'first-aid',
  title: { en: 'Choking (adult)', zh: '气道异物梗阻' },
  params: { stage: 0, taps: 0, rate: 0, press: 0, dislodge: 0 },
  Scene: ChokingScene,
  onTap: (p): Params => (Math.round(p.stage) === 2 ? { dislodge: Math.min(1, p.dislodge + 0.2) } : {}),
  sources: ['Red Cross / ERC adult choking: 5 back blows, 5 abdominal thrusts'],
  steps: [
    {
      kind: 'watch',
      caption: {
        en: 'Can they cough? Encourage coughing. If they can’t speak, cough or breathe — act now.',
        zh: '能咳嗽就鼓励咳嗽；若无法说话、咳嗽或呼吸——立即施救。',
      },
      set: { stage: 0, taps: 0, dislodge: 0 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Lean them forward. Give 5 firm back blows between the shoulder blades.',
        zh: '试一试：让其身体前倾，用掌根在两肩胛骨之间用力拍击 5 次。',
      },
      set: { stage: 1, taps: 0, dislodge: 0 },
      try: {
        mode: 'rhythm',
        target: 5,
        minRate: 0,
        maxRate: 9999,
        label: 'BLOW 拍背',
        success: (p) => p.taps >= 5,
        ok: { en: '5 back blows — still stuck? Move to abdominal thrusts.', zh: '拍背 5 次——仍未排出？改用腹部冲击。' },
      },
    },
    {
      kind: 'try',
      caption: {
        en: 'Stand behind, fist above the navel, pull sharply in and up — up to 5 times.',
        zh: '试一试：站其身后，拳头置于肚脐上方，快速向内向上冲击，最多 5 次。',
      },
      set: { stage: 2, taps: 0, dislodge: 0.2 },
      try: {
        mode: 'rhythm',
        target: 5,
        minRate: 0,
        maxRate: 9999,
        label: 'THRUST 冲击',
        success: (p) => p.dislodge >= 1,
        ok: { en: 'Out! Get them checked by a doctor after abdominal thrusts.', zh: '排出了！腹部冲击后仍需就医检查。' },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Still blocked? Keep alternating 5 blows / 5 thrusts. If they collapse: call 120 and start CPR.',
        zh: '仍未排出？交替进行 5 次拍背 / 5 次冲击。若失去意识：拨打 120 并开始心肺复苏。',
      },
      set: { stage: 2, dislodge: 1 },
    },
  ],
};
