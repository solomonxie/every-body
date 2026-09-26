import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

/** fraction of the at-risk muscle dead after `minutes` of blockage (starts ~20 min) */
export const necrosisOf = ({ minutes, clot, opened }: Params) => {
  if (clot < 0.5) return 0;
  const m = opened > 0.5 ? Math.min(minutes, 90) : minutes;
  return m < 20 ? 0 : 1 - Math.exp(-(m - 20) / 140);
};

const HEART = 'M 180 60 C 230 20, 320 60, 290 150 C 270 210, 210 250, 180 270 C 150 250, 90 210, 70 150 C 40 60, 130 20, 180 60 Z';
const LAD = 'M 176 70 C 172 120, 176 180, 184 250';
const wrap = (x: number, span: number) => ((x % span) + span) % span;

function HeartAttackScene({ params, t }: SceneProps) {
  const dead = necrosisOf(params);
  const blocked = params.clot > 0.5 && params.opened < 0.5;
  const beat = 1 + 0.03 * Math.max(0, Math.sin(t * 7.5)) ** 4;
  return (
    <G>
      <G transform={`translate(180 150) scale(${beat}) translate(-180 -150)`}>
        <Path d={HEART} fill="#C8323C" stroke="#8A1F2B" strokeWidth={3} />
        {params.clot > 0.5 && (
          <G>
            <Path d="M 150 170 C 160 210, 200 240, 184 262 C 170 250, 130 220, 120 180 Z" fill="#E88A94" />
            <Path d="M 150 170 C 160 210, 200 240, 184 262 C 170 250, 130 220, 120 180 Z" fill="#6E6E78" opacity={dead} />
          </G>
        )}
        <Path d={LAD} stroke="#F2D060" strokeWidth={6} fill="none" />
        <Path d="M 176 70 C 230 80, 270 110, 280 160" stroke="#F2D060" strokeWidth={5} fill="none" />
        <Path d="M 176 70 C 120 80, 90 110, 84 150" stroke="#F2D060" strokeWidth={5} fill="none" />
        {[0, 1, 2].map((i) => {
          const u = wrap(t * 0.4 + i / 3, 1);
          if (blocked && u > 0.25) return null;
          return <Circle key={i} cx={176 - 4 + u * 12} cy={70 + u * 180} r={3} fill="#FFFFFF" />;
        })}
        {params.clot > 0.5 && <Circle cx={174} cy={115} r={7} fill={params.opened > 0.5 ? '#9AA3AE' : '#3D0B12'} />}
      </G>
      <Text x={196} y={112} fontSize={10} fill="#FFF">{params.opened > 0.5 ? 'stent 支架' : params.clot > 0.5 ? 'clot 血栓' : ''}</Text>
      <Text x={20} y={30} fontSize={10} fill="#8A6A1B">coronary arteries 冠状动脉 (yellow)</Text>

      <Rect x={8} y={272} width={344} height={24} rx={8} fill="#FFFFFF" stroke={dead > 0.3 ? '#D8434B' : '#DDD'} strokeWidth={2} />
      <Text x={20} y={288} fontSize={11} fontWeight="bold" fill="#D8434B">
        {params.clot > 0.5 ? `${Math.round(params.minutes)} min · heart muscle lost 心肌坏死 ${Math.round(dead * 100)}%` : 'Normal supply 供血正常'}
      </Text>
    </G>
  );
}

export const heartAttack: Scenario = {
  id: 'heart-attack',
  group: 'illness',
  title: { en: 'Heart attack', zh: '心肌梗死' },
  params: { clot: 0, minutes: 0, opened: 0 },
  Scene: HeartAttackScene,
  sources: ['Reimer & Jennings wavefront of necrosis; AHA/ESC STEMI: door-to-balloon ≤ 90 min'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'Coronary arteries on the heart’s surface feed the heart muscle itself.', zh: '心脏表面的冠状动脉为心肌自身供血。' },
      set: { clot: 0, minutes: 0, opened: 0 },
    },
    {
      kind: 'watch',
      caption: { en: 'A plaque ruptures, a clot blocks the artery — the muscle below loses its blood.', zh: '斑块破裂，血栓堵塞冠状动脉——下游心肌失去血供。' },
      set: { clot: 1, minutes: 10 },
    },
    {
      kind: 'try',
      caption: { en: 'Drag the time: muscle starts dying after ~20 min and keeps dying for hours.', zh: '试一试：拖动时间：约 20 分钟后心肌开始坏死，并持续数小时。' },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'minutes', label: 'Minutes 分钟', min: 0, max: 360, digits: 0 }],
        success: (p) => p.minutes >= 180,
        ok: { en: 'Time is muscle — lost heart muscle doesn’t grow back.', zh: '时间就是心肌——坏死心肌无法再生。' },
        demo: { minutes: 240 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Signs: crushing chest pain over 15 min, spreading to arm, jaw or back; sweating, breathless. Call 120 — don’t drive yourself.',
        zh: '信号：胸口压榨样疼痛超过 15 分钟，放射至手臂、下颌或后背；出汗、气短。拨打 120，不要自己开车。',
      },
    },
    {
      kind: 'try',
      caption: { en: 'Compare: artery reopened with a stent within 90 min vs. left blocked.', zh: '对比：90 分钟内支架开通血管 vs. 持续堵塞。' },
      set: { minutes: 300 },
      try: {
        mode: 'compare',
        param: 'opened',
        options: [
          { label: 'Blocked 未开通', value: 0 },
          { label: 'Stent at 90 min 支架', value: 1 },
        ],
        success: (p) => p.opened > 0.5,
        ok: { en: 'Opening the artery early saves most of the muscle.', zh: '尽早开通血管可挽救大部分心肌。' },
      },
    },
  ],
};
