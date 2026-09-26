import { Ellipse, G, Path, Rect, Text } from 'react-native-svg';

import type { Scenario, SceneProps } from '../types';

const GRADES = ['Stretched 拉伤 (I)', 'Partly torn 部分撕裂 (II)', 'Torn through 完全断裂 (III)'];

function AnkleScene({ params }: SceneProps) {
  const g = Math.round(params.grade);
  const swelling = Math.max(0, params.injured * (0.4 + g * 0.3) * (1 - 0.6 * params.rice));
  return (
    <G>
      <Rect x={120} y={20} width={50} height={150} rx={20} fill="#E9E2CF" stroke="#B8A58A" strokeWidth={2} />
      <Rect x={185} y={30} width={22} height={140} rx={10} fill="#E9E2CF" stroke="#B8A58A" strokeWidth={2} />
      <Text x={60} y={60} fontSize={10} fill="#8F7E63">shin bones 胫腓骨</Text>
      <Path d="M 100 190 C 100 170, 230 165, 240 190 L 330 230 C 340 250, 320 260, 300 255 L 110 250 C 90 240, 95 210, 100 190 Z" fill="#E9E2CF" stroke="#B8A58A" strokeWidth={2} />
      <Text x={250} y={275} fontSize={10} fill="#8F7E63">foot bones 足骨</Text>
      <Ellipse cx={210} cy={185} rx={40 + swelling * 30} ry={24 + swelling * 20} fill="#D8434B" opacity={0.25 * swelling} />
      {g === 0 && <Path d="M 198 165 L 240 205" stroke="#C1443C" strokeWidth={8} strokeLinecap="round" opacity={params.injured > 0.5 ? 0.7 : 1} />}
      {g === 1 && (
        <G>
          <Path d="M 198 165 L 215 182" stroke="#C1443C" strokeWidth={8} strokeLinecap="round" />
          <Path d="M 222 188 L 240 205" stroke="#C1443C" strokeWidth={5} strokeLinecap="round" />
        </G>
      )}
      {g === 2 && (
        <G>
          <Path d="M 198 165 L 210 177" stroke="#C1443C" strokeWidth={8} strokeLinecap="round" />
          <Path d="M 228 193 L 240 205" stroke="#C1443C" strokeWidth={8} strokeLinecap="round" />
        </G>
      )}
      <Text x={250} y={160} fontSize={10} fill="#C1443C">ligament 韧带</Text>
      <Rect x={8} y={6} width={200} height={30} rx={8} fill="#FFFFFF" stroke="#C1443C" strokeWidth={2} />
      <Text x={20} y={26} fontSize={11} fontWeight="bold" fill="#C1443C">{params.injured > 0.5 ? GRADES[g] : 'Healthy ligament 韧带正常'}</Text>
      {params.rice > 0.1 && <Text x={20} y={290} fontSize={11} fill="#3F95D6">{`RICE applied — swelling ${Math.round(swelling * 100)}%`}</Text>}
    </G>
  );
}

export const ankleSprain: Scenario = {
  id: 'ankle-sprain',
  group: 'first-aid',
  title: { en: 'Sprained ankle', zh: '踝关节扭伤' },
  params: { injured: 0, grade: 0, rice: 0 },
  Scene: AnkleScene,
  sources: ['BJSM / Red Cross acute ankle sprain management (RICE / PEACE & LOVE)'],
  steps: [
    { kind: 'watch', caption: { en: 'Ligaments are tough straps holding bone to bone.', zh: '韧带是连接骨与骨的坚韧纤维带。' }, set: { injured: 0, grade: 0, rice: 0 } },
    { kind: 'watch', caption: { en: 'Rolling the ankle inward over-stretches the outer ligament.', zh: '脚踝内翻使外侧韧带过度拉伸。' }, set: { injured: 1 } },
    {
      kind: 'try',
      caption: { en: 'Compare the three grades of sprain.', zh: '试一试：对比三种扭伤程度。' },
      try: {
        mode: 'compare',
        param: 'grade',
        options: [
          { label: 'I', value: 0 },
          { label: 'II', value: 1 },
          { label: 'III', value: 2 },
        ],
        success: (p) => p.grade > 1.5,
        ok: { en: 'Can’t take 4 steps, or bone tender? Get an X-ray.', zh: '无法行走 4 步或骨头压痛？需拍 X 光。' },
      },
    },
    {
      kind: 'try',
      caption: { en: 'First 48 h — Rest, Ice (20 min), Compression, Elevation. Apply RICE.', zh: '试一试：48 小时内——休息、冰敷（20 分钟）、加压、抬高。' },
      set: { grade: 1 },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'rice', label: 'RICE 处理', min: 0, max: 1 }],
        success: (p) => p.rice > 0.9,
        ok: { en: 'Swelling down. Then gentle movement as pain allows.', zh: '肿胀减轻。之后在疼痛允许下逐步活动。' },
        demo: { rice: 1 },
      },
    },
  ],
};
