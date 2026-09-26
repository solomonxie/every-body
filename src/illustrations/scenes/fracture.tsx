import { Ellipse, G, Path, Rect, Text } from 'react-native-svg';

import type { DragHandler, Params, Scenario, SceneProps } from '../types';

const BONE = '#E9E2CF';
const BREAK_Y = 150;

/** healing phase fractions from weeks since the break */
export function healing(weeks: number) {
  const clamp = (x: number) => Math.max(0, Math.min(1, x));
  return {
    hematoma: clamp(1 - weeks / 2),
    soft: clamp(weeks / 2) * clamp((6 - weeks) / 3),
    hard: clamp((weeks - 2) / 4) * clamp((14 - weeks) / 6 + 0.3),
    remodel: clamp((weeks - 6) / 6),
  };
}

const dragFragment: DragHandler = ({ x }) => ({ offset: Math.max(0, Math.min(1, (x - 180) / 40)) });

function FractureScene({ params }: SceneProps) {
  const dx = params.offset * 40;
  const h = healing(params.weeks);
  const aligned = params.offset < 0.08;
  const bulge = 18 * (h.soft + h.hard) * (1 - h.remodel * 0.8);

  return (
    <G>
      <Rect x={160} y={20} width={40} height={BREAK_Y - 20} rx={14} fill={BONE} stroke="#B8A58A" strokeWidth={2} />
      <Rect x={160 + dx} y={BREAK_Y + 4} width={40} height={130} rx={14} fill={BONE} stroke="#B8A58A" strokeWidth={2} />
      <Path d={`M 160 ${BREAK_Y} l 10 6 l 10 -6 l 10 6 l 10 -6`} stroke="#8F7E63" strokeWidth={2} fill="none" />

      {h.hematoma > 0.02 && <Ellipse cx={180 + dx / 2} cy={BREAK_Y + 2} rx={40} ry={22} fill="#B3263A" opacity={0.6 * h.hematoma} />}
      {h.soft > 0.02 && <Ellipse cx={180 + dx / 2} cy={BREAK_Y + 2} rx={20 + bulge} ry={20} fill="#8FB3E0" opacity={0.7 * h.soft} />}
      {h.hard > 0.02 && <Ellipse cx={180 + dx / 2} cy={BREAK_Y + 2} rx={20 + bulge} ry={18} fill={BONE} stroke="#B8A58A" opacity={h.hard} />}

      {params.cast > 0.5 && (
        <Rect x={138} y={60} width={84 + dx} height={180} rx={20} fill="#FFFFFF" stroke="#CCC" strokeWidth={2} opacity={0.55} />
      )}
      {params.offset > 0.02 && (
        <Text x={210 + dx} y={BREAK_Y + 60} fontSize={10} fill="#D8434B">{'← displaced 移位'}</Text>
      )}

      <Rect x={8} y={6} width={130} height={30} rx={8} fill="#FFFFFF" stroke={aligned ? '#2E9E5B' : '#D8434B'} strokeWidth={2} />
      <Text x={73} y={26} fontSize={11} fontWeight="bold" fill={aligned ? '#2E9E5B' : '#D8434B'} textAnchor="middle">
        {aligned ? 'Aligned 对位良好' : 'Displaced 移位'}
      </Text>
      <Text x={20} y={268} fontSize={11} fill="#555">{`Week 第 ${params.weeks.toFixed(1)} 周`}</Text>
      <Text x={20} y={284} fontSize={10} fill="#555">
        {h.hematoma > 0.5 ? 'Blood clot 血肿' : h.soft > 0.5 ? 'Soft callus 软骨痂' : h.remodel > 0.5 ? 'Remodelling 塑形' : 'Hard callus 硬骨痂'}
      </Text>
    </G>
  );
}

const phaseOf = (p: Params) => healing(p.weeks);

export const fracture: Scenario = {
  id: 'fracture-healing',
  group: 'bones',
  title: { en: 'Fracture: setting & healing', zh: '骨折：复位与愈合' },
  warning: { en: 'Setting a bone is a clinician’s job — this shows how it works.', zh: '骨折复位须由医生操作——此处仅演示原理。' },
  params: { offset: 1, weeks: 0, cast: 0 },
  Scene: FractureScene,
  onDrag: dragFragment,
  sources: ['Standard fracture-healing phases: haematoma, soft callus, hard callus, remodelling'],
  steps: [
    {
      kind: 'watch',
      caption: { en: 'A broken forearm bone: the lower piece has slipped sideways.', zh: '前臂骨折：远端骨块向侧方移位。' },
      set: { offset: 1, weeks: 0, cast: 0 },
    },
    {
      kind: 'watch',
      caption: {
        en: 'First aid: keep it still in the position found, support it, cold pack, go to hospital.',
        zh: '急救：保持原位不动，托扶固定，冷敷，尽快就医。',
      },
    },
    {
      kind: 'try',
      caption: { en: 'Setting (reduction): drag the lower piece back into line.', zh: '试一试（复位）：把远端骨块拖回对齐。' },
      try: {
        mode: 'drag',
        success: (p) => p.offset < 0.08,
        ok: { en: 'Ends aligned — now they must be held still.', zh: '断端对齐——接下来需要固定。' },
        demo: { offset: 0 },
      },
    },
    {
      kind: 'watch',
      caption: { en: 'A cast holds the ends together while the bone heals.', zh: '石膏固定，使断端在愈合期间保持对位。' },
      set: { offset: 0, cast: 1 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Drag through the weeks: clot → soft callus → hard callus → remodelled bone.',
        zh: '试一试：拖动周数：血肿 → 软骨痂 → 硬骨痂 → 塑形。',
      },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'weeks', label: 'Weeks 周', min: 0, max: 12, digits: 1 }],
        success: (p) => phaseOf(p).remodel > 0.5,
        ok: { en: 'Adult forearm: ~6–8 weeks in a cast, remodelling for months.', zh: '成人前臂：石膏约 6–8 周，塑形持续数月。' },
        demo: { weeks: 12 },
      },
    },
  ],
};
