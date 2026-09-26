import { Circle, G, Line, Path, Rect, Text } from 'react-native-svg';

import type { DragHandler, Scenario, SceneProps } from '../types';

const SOCKET = { x: 150, y: 120, r: 36 };
const IN_PLACE = { x: 158, y: 120 };
const OUT = { x: 190, y: 196 };
const BEND = { x: 222, y: 138 };
const HEAD_R = 30;

/** reduction path: quadratic curve from in-place (u = 0) to dislocated (u = 1) */
function headAt(u: number) {
  const a = (1 - u) * (1 - u);
  const b = 2 * u * (1 - u);
  const c = u * u;
  return { x: a * IN_PLACE.x + b * BEND.x + c * OUT.x, y: a * IN_PLACE.y + b * BEND.y + c * OUT.y };
}

const pathD = Array.from({ length: 21 }, (_, i) => {
  const { x, y } = headAt(i / 20);
  return `${i === 0 ? 'M' : 'L'} ${x.toFixed(1)} ${y.toFixed(1)}`;
}).join(' ');

/** nearest point on the path to the finger */
const dragShoulder: DragHandler = ({ x, y }) => {
  let best = 0;
  let bestD = Infinity;
  for (let i = 0; i <= 60; i++) {
    const p = headAt(i / 60);
    const d = (p.x - x) ** 2 + (p.y - y) ** 2;
    if (d < bestD) {
      bestD = d;
      best = i / 60;
    }
  }
  return { disloc: best };
};

function ShoulderScene({ params }: SceneProps) {
  const head = headAt(params.disloc);
  const inPlace = params.disloc < 0.08;
  const shaftEnd = { x: head.x + 60, y: head.y + 150 };

  return (
    <G>
      <Path d="M 60 40 L 130 70 L 128 190 L 70 250" stroke="#D9CBB0" strokeWidth={22} fill="none" strokeLinejoin="round" />
      <Text x={20} y={30} fontSize={10} fill="#8F7E63">shoulder blade 肩胛骨</Text>
      <Path
        d={`M ${SOCKET.x - 4} ${SOCKET.y - SOCKET.r} A ${SOCKET.r} ${SOCKET.r} 0 0 1 ${SOCKET.x - 4} ${SOCKET.y + SOCKET.r}`}
        stroke="#8F7E63"
        strokeWidth={8}
        fill="none"
        transform={`translate(-8 0)`}
      />
      <Text x={86} y={172} fontSize={10} fill="#8F7E63">socket 关节盂</Text>
      <Path d="M 118 60 Q 170 40 205 70" stroke="#D9CBB0" strokeWidth={12} fill="none" strokeLinecap="round" />
      <Text x={180} y={52} fontSize={10} fill="#8F7E63">collarbone 锁骨</Text>

      {params.showPath > 0.5 && (
        <G>
          <Path d={pathD} stroke="#3F95D6" strokeWidth={2} strokeDasharray="5 4" fill="none" />
          <Circle cx={IN_PLACE.x} cy={IN_PLACE.y} r={HEAD_R} stroke="#2E9E5B" strokeWidth={2} strokeDasharray="4 4" fill="none" />
        </G>
      )}

      <Line x1={head.x} y1={head.y} x2={shaftEnd.x} y2={shaftEnd.y} stroke="#E4DECB" strokeWidth={26} strokeLinecap="round" />
      <Circle cx={head.x} cy={head.y} r={HEAD_R} fill={inPlace ? '#E4DECB' : '#F1D08A'} stroke={inPlace ? '#8F7E63' : '#D8434B'} strokeWidth={3} />
      <Text x={shaftEnd.x - 6} y={shaftEnd.y - 30} fontSize={10} fill="#8F7E63" textAnchor="end">upper arm 肱骨</Text>

      {params.sling > 0.5 && (
        <Path d={`M 110 60 Q 250 150 ${shaftEnd.x + 10} ${shaftEnd.y}`} stroke="#3F95D6" strokeWidth={16} fill="none" opacity={0.7} />
      )}

      <Rect x={220} y={6} width={132} height={30} rx={8} fill="#FFFFFF" stroke={inPlace ? '#2E9E5B' : '#D8434B'} strokeWidth={2} />
      <Text x={286} y={26} fontSize={12} fontWeight="bold" fill={inPlace ? '#2E9E5B' : '#D8434B'} textAnchor="middle">
        {inPlace ? 'In place 复位' : 'Dislocated 脱位'}
      </Text>
    </G>
  );
}

export const shoulder: Scenario = {
  id: 'shoulder-dislocation',
  group: 'bones',
  title: { en: 'Shoulder dislocation', zh: '肩关节脱位与复位' },
  warning: {
    en: 'This shows what a clinician does — don’t try it on someone yourself.',
    zh: '此演示为医生操作——请勿自行复位。',
  },
  params: { disloc: 0, showPath: 0, sling: 0 },
  Scene: ShoulderScene,
  onDrag: dragShoulder,
  sources: ['Orthopaedic references on anterior shoulder dislocation (≈95% anterior)'],
  steps: [
    {
      kind: 'watch',
      caption: {
        en: 'The shoulder is a ball in a shallow socket — huge range of motion, but easy to dislocate.',
        zh: '肩关节是“球”在浅“窝”里——活动范围大，但容易脱位。',
      },
      set: { disloc: 0, showPath: 0, sling: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'A fall on an outstretched arm levers the ball forward and down, out of the socket.',
        zh: '跌倒时手臂伸直撑地，肱骨头被撬向前下方，脱出关节盂。',
      },
      set: { disloc: 1 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'First aid: support the arm in the position it’s in, ice, and go to A&E. Don’t pull it back.',
        zh: '急救：保持手臂现有姿势并托住，冷敷，尽快就医。不要强行拉回。',
      },
    },
    {
      kind: 'try',
      caption: {
        en: 'How a clinician reduces it: drag the ball along the path back into the socket.',
        zh: '医生如何复位：沿路径拖动肱骨头，使其回到关节盂内。',
      },
      set: { showPath: 1 },
      try: {
        mode: 'drag',
        success: (p) => p.disloc < 0.08,
        ok: { en: 'Back in the socket — reduced.', zh: '回到关节盂——复位成功。' },
        demo: { disloc: 0 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'A sling rests the joint for about 3 weeks while the stretched ligaments heal, then physio.',
        zh: '用吊带固定约 3 周，让拉伤的韧带愈合，之后进行康复训练。',
      },
      set: { disloc: 0, showPath: 0, sling: 1 },
    },
  ],
};
