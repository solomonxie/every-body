import { Circle, Ellipse, G, Line, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

const TOP = 90;
const BOTTOM = 190;
const R = (BOTTOM - TOP) / 2;
const MID = (TOP + BOTTOM) / 2;
const PLAQUE_X = 180;
const PLAQUE_W = 70;

/** fraction of the radius blocked */
export const plaqueOf = ({ ldl, years }: Params) => Math.min(0.85, (ldl * years) / 40);
/** Poiseuille: at the same pressure, flow ∝ r⁴ */
export const flowOf = (p: Params) => (p.rupture > 0.5 ? 0 : (1 - plaqueOf(p)) ** 4);

const wrap = (x: number, span: number) => ((x % span) + span) % span;

/** half-height of the open channel at x */
function lumenAt(x: number, plaque: number) {
  const d = (x - PLAQUE_X) / PLAQUE_W;
  return R * (1 - plaque * Math.exp(-d * d * 2.5));
}

function BloodFatsScene({ params, t }: SceneProps) {
  const plaque = plaqueOf(params);
  const flow = flowOf(params);
  const top = Array.from({ length: 37 }, (_, i) => {
    const x = i * 10;
    return `${i === 0 ? 'M' : 'L'} ${x} ${MID - lumenAt(x, plaque)}`;
  }).join(' ');
  const bottom = Array.from({ length: 37 }, (_, i) => {
    const x = 360 - i * 10;
    return `L ${x} ${MID + lumenAt(x, plaque) * 0.999}`;
  }).join(' ');
  const cells = 22;
  const ldlDots = Math.round(params.ldl * 14);

  return (
    <G>
      <Rect x={0} y={TOP - 14} width={360} height={14} fill="#E8B4B8" />
      <Rect x={0} y={BOTTOM} width={360} height={14} fill="#E8B4B8" />
      <Path d={`${top} ${bottom} Z`} fill="#F7DADA" />
      <Path d={`${top} L 360 ${TOP} L 0 ${TOP} Z`} fill="#F2C94C" opacity={plaque > 0.01 ? 0.95 : 0} />
      <Path d={`M 0 ${BOTTOM} L 360 ${BOTTOM} ${bottom} Z`} fill="#F2C94C" opacity={plaque > 0.01 ? 0.95 : 0} />

      {Array.from({ length: cells }, (_, i) => {
        const x = wrap(i * 41 + t * 60 * (0.15 + flow), 380) - 10;
        const lane = ((i * 0.37) % 1) * 1.6 - 0.8;
        return <Ellipse key={i} cx={x} cy={MID + lane * lumenAt(x, plaque)} rx={6} ry={3.5} fill="#C8323C" />;
      })}
      {Array.from({ length: ldlDots }, (_, i) => {
        const x = wrap(i * 67 + t * 40 * (0.15 + flow), 380) - 10;
        const lane = ((i * 0.53) % 1) * 1.6 - 0.8;
        return <Circle key={`l${i}`} cx={x} cy={MID + lane * lumenAt(x, plaque)} r={3} fill="#E8A21B" />;
      })}
      {params.rupture > 0.5 && (
        <Ellipse cx={PLAQUE_X + 10} cy={MID} rx={34} ry={lumenAt(PLAQUE_X, plaque) + 2} fill="#7A1F2B" />
      )}

      <Line x1={10} y1={MID} x2={40} y2={MID} stroke="#8A3B45" strokeWidth={2} />
      <Path d={`M 40 ${MID - 5} L 48 ${MID} L 40 ${MID + 5} Z`} fill="#8A3B45" />

      <Rect x={8} y={6} width={344} height={52} rx={8} fill="#FFFFFF" stroke="#DDD" />
      <Text x={20} y={26} fontSize={12} fill="#8A6A1B">{`Plaque 斑块  ${Math.round(plaque * 100)}% of radius`}</Text>
      <Text x={20} y={46} fontSize={12} fontWeight="bold" fill={flow < 0.3 ? '#D8434B' : '#2E9E5B'}>
        {`Flow 血流  ${Math.round(flow * 100)}%   (∝ r⁴)`}
      </Text>
      <Text x={340} y={36} fontSize={11} fill="#555" textAnchor="end">{`${Math.round(params.years)} yrs 年`}</Text>

      <Circle cx={20} cy={236} r={4} fill="#E8A21B" />
      <Text x={28} y={240} fontSize={10} fill="#555">LDL 低密度脂蛋白 (“bad” cholesterol)</Text>
      <Ellipse cx={20} cy={256} rx={6} ry={3.5} fill="#C8323C" />
      <Text x={28} y={260} fontSize={10} fill="#555">red blood cells 红细胞</Text>
      <Rect x={14} y={270} width={12} height={8} fill="#F2C94C" />
      <Text x={28} y={278} fontSize={10} fill="#555">fatty plaque 粥样斑块</Text>
    </G>
  );
}

export const bloodFats: Scenario = {
  id: 'blood-fats',
  group: 'blood',
  title: { en: 'Blood fats & plaque', zh: '血脂与斑块' },
  params: { ldl: 0.2, years: 0, rupture: 0 },
  Scene: BloodFatsScene,
  sources: ['WHO cardiovascular diseases fact sheet; Poiseuille’s law for flow vs radius'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'A healthy artery: smooth wall, blood flows freely.', zh: '健康动脉：管壁光滑，血流通畅。' },
      set: { ldl: 0.2, years: 0, rupture: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Too much LDL (“bad” cholesterol) in the blood seeps into the artery wall.',
        zh: '血液中低密度脂蛋白（“坏”胆固醇）过多，渗入动脉壁。',
      },
      set: { ldl: 0.9, years: 8 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Over years it builds a fatty plaque that narrows the channel.',
        zh: '日积月累，形成粥样斑块，使管腔变窄。',
      },
      set: { years: 28 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Drag the years. Halve the radius and flow drops to 1/16 — flow ∝ r⁴.',
        zh: '拖动年数。半径减半，血流降为 1/16——血流与半径的四次方成正比。',
      },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'years', label: 'Years 年', min: 0, max: 40, digits: 0 }],
        success: (p) => plaqueOf(p) >= 0.5,
        ok: { en: 'Half-blocked: only ~6% of the flow at the same pressure.', zh: '堵塞一半：同样压力下仅约 6% 的血流。' },
        demo: { years: 30 },
      },
    },
    {
      kind: 'try',
      caption: {
        en: 'Lower LDL (diet, exercise, statins) and the plaque stops growing.',
        zh: '降低 LDL（饮食、运动、他汀类药物），斑块停止增长。',
      },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'ldl', label: 'LDL 低密度脂蛋白', min: 0, max: 1 }],
        success: (p) => p.ldl < 0.4,
        ok: { en: 'Lower LDL, slower build-up.', zh: 'LDL 降低，斑块增长减慢。' },
        demo: { ldl: 0.25 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'If a plaque ruptures, a clot forms and can block the artery — a heart attack or stroke. Call 120/911.',
        zh: '斑块破裂可形成血栓，完全堵塞血管——心梗或中风。立即拨打 120。',
      },
      set: { ldl: 1, years: 36, rupture: 1 },
    },
  ],
};
