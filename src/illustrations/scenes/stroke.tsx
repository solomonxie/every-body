import { Circle, Ellipse, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

const ZONE = { x: 205, y: 120, r: 46 };
const NEURONS_PER_MIN = 1.9e6;

/** fraction of the starved zone that is lost after `minutes` without flow */
export const coreOf = ({ minutes, clot, treated }: Params) =>
  clot < 0.5 ? 0 : Math.min(1, Math.sqrt(Math.min(minutes, treated > 0.5 ? 60 : 360) / 360));

const wrap = (x: number, span: number) => ((x % span) + span) % span;
const BRANCHES = [
  'M 150 250 C 150 200, 160 170, 175 150 C 190 130, 215 118, 240 110',
  'M 150 250 C 148 190, 130 150, 110 120',
  'M 150 250 C 160 200, 200 190, 250 170',
];

function StrokeScene({ params, t }: SceneProps) {
  const core = coreOf(params);
  const blocked = params.clot > 0.5;
  return (
    <G>
      <Ellipse cx={170} cy={120} rx={130} ry={95} fill="#F4C6CF" stroke="#C98A97" strokeWidth={2} />
      <Text x={60} y={40} fontSize={10} fill="#8A3B45">brain (side view) 脑</Text>
      {blocked && (
        <G>
          <Circle cx={ZONE.x} cy={ZONE.y} r={ZONE.r} fill={params.treated > 0.5 ? '#F7DDE2' : '#E5B8C0'} />
          <Circle cx={ZONE.x} cy={ZONE.y} r={ZONE.r * core} fill="#8C8C94" />
        </G>
      )}
      {BRANCHES.map((d, i) => (
        <Path key={i} d={d} stroke="#C8323C" strokeWidth={i === 0 ? 6 : 4} fill="none" strokeLinecap="round" />
      ))}
      {blocked && <Circle cx={175} cy={150} r={7} fill="#5A1420" />}
      {[0, 1, 2, 3, 4].map((i) => {
        const u = wrap(t * 0.5 + i / 5, 1);
        const stopped = blocked && i % 3 === 0 && u > 0.45;
        return stopped ? null : <Circle key={i} cx={150 + (i % 3 === 0 ? u * 90 : i % 3 === 1 ? -u * 40 : u * 100)} cy={250 - u * (i % 3 === 1 ? 130 : 110)} r={3} fill="#FFFFFF" opacity={0.9} />;
      })}

      <Rect x={8} y={232} width={344} height={62} rx={8} fill="#FFFFFF" stroke={core > 0.3 ? '#D8434B' : '#DDD'} strokeWidth={2} />
      <Text x={20} y={252} fontSize={11} fill="#555">{blocked ? `Minutes without blood 缺血 ${Math.round(params.minutes)} min` : 'Normal blood supply 供血正常'}</Text>
      <Text x={20} y={270} fontSize={12} fontWeight="bold" fill="#D8434B">
        {blocked ? `Neurons lost 神经元损失 ≈ ${((Math.min(params.minutes, params.treated > 0.5 ? 60 : 360) * NEURONS_PER_MIN) / 1e6).toFixed(0)} million 百万` : ''}
      </Text>
      <Text x={20} y={286} fontSize={10} fill="#555">{params.treated > 0.5 ? 'Clot removed at 60 min — surrounding area saved 周围脑组织被挽救' : blocked ? 'grey = dead core · pink = at-risk area 灰：坏死 粉：可挽救区' : ''}</Text>
    </G>
  );
}

export const stroke: Scenario = {
  id: 'stroke',
  group: 'illness',
  title: { en: 'Stroke', zh: '脑卒中（中风）' },
  params: { clot: 0, minutes: 0, treated: 0 },
  Scene: StrokeScene,
  sources: ['Saver 2006 “Time is brain” (1.9 million neurons/min); Chinese Stroke Association 中风120'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'Arteries carry oxygen to every part of the brain.', zh: '动脉为大脑各部分输送氧气。' },
      set: { clot: 0, minutes: 0, treated: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Ischaemic stroke: a clot blocks an artery. The brain beyond it is starved of oxygen.',
        zh: '缺血性卒中：血栓堵塞动脉，其供血区域脑组织缺氧。',
      },
      set: { clot: 1, minutes: 5 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Drag the time. About 1.9 million neurons die every minute — the dead core spreads.',
        zh: '试一试：拖动时间。每分钟约 190 万个神经元死亡——坏死区不断扩大。',
      },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'minutes', label: 'Minutes 分钟', min: 0, max: 360, digits: 0 }],
        success: (p) => p.minutes >= 120,
        ok: { en: 'Time is brain.', zh: '时间就是大脑。' },
        demo: { minutes: 180 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Spot it — 中风120: 1 face uneven, 2 one arm weak, 0 (listen) slurred speech → call 120 now, note the time.',
        zh: '识别“中风120”：1 看脸不对称，2 查两臂一侧无力，0 聆听言语不清 → 立即拨打 120，记下发病时间。',
      },
    },
    {
      kind: 'try',
      caption: {
        en: 'Compare: clot removed at hospital within an hour vs. no treatment.',
        zh: '对比：1 小时内在医院溶栓/取栓 vs. 未治疗。',
      },
      set: { minutes: 240 },
      try: {
        mode: 'compare',
        param: 'treated',
        options: [
          { label: 'No treatment 未治疗', value: 0 },
          { label: 'Treated at 1 h 1小时内治疗', value: 1 },
        ],
        success: (p) => p.treated > 0.5,
        ok: { en: 'Fast treatment saves the at-risk area.', zh: '及时治疗可挽救缺血半暗带。' },
      },
    },
  ],
};
