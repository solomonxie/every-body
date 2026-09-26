import { Circle, G, Path, Rect, Text } from 'react-native-svg';

import type { Params, Scenario, SceneProps } from '../types';

/** open airway radius (0..1): narrowed by inflammation + muscle squeeze, widened by the inhaler */
export const airwayOf = ({ attack, inhaler }: Params) => Math.max(0.25, 1 - 0.65 * attack * (1 - 0.8 * inhaler));
/** airflow ∝ r⁴ */
export const flowOf = (p: Params) => airwayOf(p) ** 4;

function AsthmaScene({ params, t }: SceneProps) {
  const r = airwayOf(params);
  const flow = flowOf(params);
  const R = 70;
  const breath = (Math.sin(t * (flow > 0.3 ? 1.6 : 3.2)) + 1) / 2;
  const squeeze = params.attack * (1 - 0.8 * params.inhaler);
  return (
    <G>
      <Circle cx={120} cy={140} r={R + 18} fill="#E8B4B8" />
      {Array.from({ length: 12 }, (_, i) => {
        const a = (i / 12) * Math.PI * 2;
        return (
          <Rect
            key={i}
            x={120 + Math.cos(a) * (R + 6) - 5}
            y={140 + Math.sin(a) * (R + 6) - 9}
            width={10}
            height={18}
            fill="#C1443C"
            opacity={0.3 + squeeze * 0.7}
            transform={`rotate(${(a * 180) / Math.PI + 90} ${120 + Math.cos(a) * (R + 6)} ${140 + Math.sin(a) * (R + 6)})`}
          />
        );
      })}
      <Circle cx={120} cy={140} r={R} fill="#F2C9D0" />
      <Circle cx={120} cy={140} r={R * r} fill="#FFFFFF" stroke="#E0A0AA" strokeWidth={2} />
      {params.attack > 0.3 && (
        <Path d={`M ${120 - R * r} 140 Q 120 ${140 + R * r * 0.4} ${120 + R * r} 140`} stroke="#F2E0A0" strokeWidth={6} fill="none" opacity={0.8} />
      )}
      {[0, 1, 2, 3, 4].map((i) => (
        <Circle key={i} cx={120 + (i - 2) * R * r * 0.3} cy={140 - R * r * 0.5 + breath * R * r} r={3} fill="#3F95D6" opacity={flow} />
      ))}
      <Text x={120} y={250} fontSize={10} fill="#8A3B45" textAnchor="middle">airway cross-section 气道横截面</Text>
      <Text x={120} y={264} fontSize={9} fill="#8A3B45" textAnchor="middle">muscle 平滑肌 · swollen lining 黏膜水肿 · mucus 痰</Text>

      <Rect x={230} y={40} width={122} height={96} rx={8} fill="#FFFFFF" stroke={flow < 0.3 ? '#D8434B' : '#2E9E5B'} strokeWidth={2} />
      <Text x={291} y={62} fontSize={11} fill="#555" textAnchor="middle">Airflow 气流</Text>
      <Text x={291} y={92} fontSize={24} fontWeight="bold" fill={flow < 0.3 ? '#D8434B' : '#2E9E5B'} textAnchor="middle">{`${Math.round(flow * 100)}%`}</Text>
      <Text x={291} y={116} fontSize={10} fill="#555" textAnchor="middle">{`radius ${Math.round(r * 100)}% → flow ∝ r⁴`}</Text>
      {params.attack > 0.5 && <Text x={230} y={160} fontSize={11} fill="#D8434B">wheeze · tight chest 喘鸣 胸闷</Text>}
    </G>
  );
}

export const asthma: Scenario = {
  id: 'asthma',
  group: 'illness',
  title: { en: 'Asthma attack', zh: '哮喘发作' },
  params: { attack: 0, inhaler: 0 },
  Scene: AsthmaScene,
  sources: ['GINA 2024 asthma strategy; Poiseuille flow ∝ r⁴'],
  steps: [
    { kind: 'watch', caption: { en: 'A normal airway: wide open, air flows easily.', zh: '正常气道：通畅，气流顺畅。' }, set: { attack: 0, inhaler: 0 } },
    {
      kind: 'watch',
      caption: {
        en: 'Attack: the muscle ring tightens, the lining swells, mucus builds. The tube narrows.',
        zh: '发作时：平滑肌收缩、黏膜水肿、痰液增多，气道变窄。',
      },
      set: { attack: 1 },
    },
    {
      kind: 'try',
      caption: {
        en: 'Use the reliever inhaler — it relaxes the muscle. Watch airflow: a little wider = a lot more air.',
        zh: '试一试：使用缓解吸入剂——放松平滑肌。气道稍宽，气流大增。',
      },
      try: {
        mode: 'scrub',
        scrubs: [{ param: 'inhaler', label: 'Inhaler 吸入剂', min: 0, max: 1 }],
        success: (p) => flowOf(p) > 0.5,
        ok: { en: 'Breathing eases. If it doesn’t within minutes, call 120.', zh: '呼吸缓解。几分钟内不缓解请拨打 120。' },
        demo: { inhaler: 1 },
      },
    },
    {
      kind: 'watch',
      caption: {
        en: 'Attack plan: sit upright, 1 puff every 30–60 s up to 10. Can’t speak in sentences or lips turn blue → 120.',
        zh: '发作处理：坐直，每 30–60 秒吸 1 喷，最多 10 喷。说话不成句或嘴唇发紫 → 拨打 120。',
      },
      set: { inhaler: 1 },
    },
  ],
};
