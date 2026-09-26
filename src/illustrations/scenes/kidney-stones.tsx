import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

/** chance a stone passes on its own, by size in mm (typical clinical figures) */
export const passChance = ({ mm }: Params) => (mm <= 4 ? 0.9 : mm <= 6 ? 0.6 : mm <= 8 ? 0.3 : 0.1);

const URETER = 'M 110 90 C 120 140, 150 170, 160 230';
const pointOn = (u: number) => {
  // cubic bezier (110,90) (120,140) (150,170) (160,230)
  const a = (1 - u) ** 3, b = 3 * u * (1 - u) ** 2, c = 3 * u * u * (1 - u), d = u ** 3;
  return { x: a * 110 + b * 120 + c * 150 + d * 160, y: a * 90 + b * 140 + c * 170 + d * 230 };
};

function KidneyStoneScene({ params, t }: SceneProps) {
  const chance = passChance(params);
  const stuckAt = 0.35 + chance * 0.6;
  const travel = params.moving > 0.5 ? Math.min(stuckAt, (t * 0.12) % 1.2) : 0;
  const stone = pointOn(travel);
  const r = 2 + params.mm * 0.9;
  const blocked = params.moving > 0.5 && travel >= stuckAt - 0.01 && chance < 0.5;
  return (
    <G>
      <Path d="M 80 40 C 40 40, 40 120, 90 110 C 110 105, 120 70, 110 55 C 105 45, 95 40, 80 40 Z" fill="#9E3A4A" />
      <Text x={30} y={30} fontSize={10} fill="#8A3B45">kidney 肾</Text>
      <Path d={URETER} stroke={blocked ? '#D8434B' : '#E0C35A'} strokeWidth={8} fill="none" strokeLinecap="round" />
      <Text x={170} y={150} fontSize={10} fill="#8A6A1B">ureter 输尿管 (3–4 mm wide)</Text>
      <Path d="M 140 230 C 140 290, 200 290, 200 230 C 200 215, 140 215, 140 230 Z" fill="#E0C35A" />
      <Text x={210} y={260} fontSize={10} fill="#8A6A1B">bladder 膀胱</Text>
      <Circle cx={stone.x} cy={stone.y} r={r} fill="#8A7A5A" stroke="#5A4A3A" />
      {blocked && <Text x={stone.x + 14} y={stone.y + 4} fontSize={11} fill="#D8434B">⚡ pain 剧痛</Text>}

      <Rect x={220} y={20} width={132} height={70} rx={8} fill="#FFFFFF" stroke={chance >= 0.5 ? '#2E9E5B' : '#D8434B'} strokeWidth={2} />
      <Text x={286} y={40} fontSize={11} fill="#555" textAnchor="middle">{`Stone 结石 ${params.mm.toFixed(0)} mm`}</Text>
      <Text x={286} y={66} fontSize={20} fontWeight="bold" fill={chance >= 0.5 ? '#2E9E5B' : '#D8434B'} textAnchor="middle">{`${Math.round(chance * 100)}%`}</Text>
      <Text x={286} y={82} fontSize={9} fill="#555" textAnchor="middle">pass on their own 自行排出</Text>
    </G>
  );
}

export const kidneyStones: Scenario = {
  id: 'kidney-stones',
  group: 'illness',
  title: { en: 'Kidney stones', zh: '肾结石' },
  params: { mm: 3, moving: 0 },
  Scene: KidneyStoneScene,
  sources: ['AUA / EAU urolithiasis guidelines (spontaneous passage by size)'],
  steps: [
    { kind: 'watch', caption: { en: 'Minerals in urine can crystallise into a stone inside the kidney.', zh: '尿液中的矿物质可在肾内结晶成结石。' }, set: { mm: 3, moving: 0 } },
    { kind: 'watch', caption: { en: 'When it moves into the narrow ureter it can cause severe, wave-like pain.', zh: '结石进入狭窄的输尿管时会引起剧烈的阵发性绞痛。' }, set: { moving: 1 } },
    {
      kind: 'try',
      caption: { en: 'Drag the size. Small stones usually pass; big ones get stuck.', zh: '试一试：拖动大小。小结石多能排出，大的易卡住。' },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'mm', label: 'Size 大小', min: 2, max: 12, unit: 'mm', digits: 0 }],
        success: (p) => p.mm >= 8,
        ok: { en: 'Over ~6 mm often needs shock-wave or laser treatment.', zh: '超过约 6 毫米常需碎石或激光治疗。' },
        demo: { mm: 9 },
      },
    },
    {
      kind: 'watch',
      caption: { en: 'Prevention: 2.5–3 L of water a day, less salt. Fever with the pain → hospital now.', zh: '预防：每天饮水 2.5–3 升，少盐。疼痛伴发热 → 立即就医。' },
    },
  ],
};
