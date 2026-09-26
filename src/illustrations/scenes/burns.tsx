import { G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

const LAYERS = [
  { name: 'Epidermis 表皮', y: 90, h: 30, color: '#F5D7BF' },
  { name: 'Dermis 真皮', y: 120, h: 70, color: '#EFC1A8' },
  { name: 'Fat 皮下脂肪', y: 190, h: 60, color: '#F7E3A1' },
];

/** how deep the heat reaches (px below the surface) after `minutes` of cooling */
export const heatDepth = ({ minutes, cooling }: Params) => Math.max(0, 110 * (1 - (cooling * minutes) / 20));

function BurnsScene({ params, t }: SceneProps) {
  const depth = heatDepth(params);
  const cooled = depth < 8;
  return (
    <G>
      {LAYERS.map((layer) => (
        <G key={layer.name}>
          <Rect x={40} y={layer.y} width={280} height={layer.h} fill={layer.color} />
          <Text x={326} y={layer.y + layer.h / 2 + 4} fontSize={9} fill="#8F7E63" textAnchor="end">{layer.name}</Text>
        </G>
      ))}
      <Path d={`M 120 90 Q 180 ${90 + depth * 2} 240 90 Z`} fill="#E0503C" opacity={0.75} />
      {params.cooling > 0.5 &&
        [0, 1, 2, 3, 4, 5].map((i) => (
          <Path key={i} d={`M ${110 + i * 26} ${((t * 60 + i * 13) % 50) + 20} l 0 12`} stroke="#3F95D6" strokeWidth={3} strokeLinecap="round" />
        ))}
      <Rect x={8} y={256} width={344} height={38} rx={8} fill="#FFFFFF" stroke={cooled ? '#2E9E5B' : '#E0503C'} strokeWidth={2} />
      <Text x={20} y={272} fontSize={11} fill="#555">{`Cool running water 流动冷水  ${Math.round(params.minutes * params.cooling)} / 20 min`}</Text>
      <Text x={20} y={287} fontSize={11} fontWeight="bold" fill={cooled ? '#2E9E5B' : '#E0503C'}>
        {cooled ? 'Heat drawn out 热量已散出' : 'Heat still spreading inward 热量仍在向深层扩散'}
      </Text>
    </G>
  );
}

export const burns: Scenario = {
  id: 'burns',
  group: 'first-aid',
  title: { en: 'Burns', zh: '烧烫伤' },
  params: { minutes: 0, cooling: 0 },
  Scene: BurnsScene,
  sources: ['ILCOR / Red Cross burns first aid: cool with running water for 20 minutes'],
  steps: [
    {
      kind: 'watch',
      caption: {
        en: 'Heat keeps travelling into the skin after the burn — the damage deepens for minutes.',
        zh: '烫伤后热量仍会持续向皮肤深层传导——损伤在几分钟内继续加深。',
      },
      set: { minutes: 0, cooling: 0 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Cool it under cool running water. Drag the time — aim for the full 20 minutes.',
        zh: '试一试：用流动冷水冲洗。拖动时间——目标 20 分钟。',
      },
      set: { cooling: 1 },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'minutes', label: 'Minutes 分钟', min: 0, max: 20, digits: 0 }],
        success: (p) => p.minutes >= 19.5,
        ok: { en: '20 minutes — even up to 3 hours after the burn it still helps.', zh: '20 分钟——即使烫伤 3 小时内冲洗仍有帮助。' },
        demo: { minutes: 20 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'No ice, butter or toothpaste. Remove rings and watches. Cover loosely with cling film.',
        zh: '不要用冰、黄油或牙膏。取下戒指手表。用保鲜膜松松覆盖。',
      },
      set: { minutes: 20 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'See a doctor if it’s bigger than their palm, on the face, hands, feet or genitals, or looks deep.',
        zh: '面积大于伤者手掌，或位于面部、手足、会阴，或看起来较深——需就医。',
      },
    },
  ],
};
