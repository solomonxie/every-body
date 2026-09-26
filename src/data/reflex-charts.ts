import type { OrganId } from '@/data/anatomy';
import type { Vec3 } from '@/types/BodyPoint';

// Hand and ear reflex charts — schematic geometry, zone positions from the standard maps:
// hand: Chinese hand reflexology (手部反射区) on the palm, WHO acupoint locations on the back;
// ear: GB/T 13734-2008 auricular point regions. Placement is relative to bone/landmark lines.
// Owner's view: palm drawing = left palm, back drawing = back of right hand, ear = left ear.
// The other side renders mirrored.

export type Side = 'left' | 'right';

export type ZoneGroup =
  | 'head'
  | 'senses'
  | 'respiratory'
  | 'heart'
  | 'digestive'
  | 'urinary'
  | 'reproductive'
  | 'musculoskeletal';

export const ZONE_GROUPS: Record<ZoneGroup, { label: string; labelZh: string; color: string }> = {
  head: { label: 'Head', labelZh: '头脑', color: '#8E6CD9' },
  senses: { label: 'Senses', labelZh: '五官', color: '#3F95D6' },
  respiratory: { label: 'Lungs', labelZh: '呼吸', color: '#E07F8A' },
  heart: { label: 'Heart', labelZh: '心', color: '#D8434B' },
  digestive: { label: 'Digestion', labelZh: '消化', color: '#E39B4B' },
  urinary: { label: 'Kidney', labelZh: '泌尿', color: '#2BA7A0' },
  reproductive: { label: 'Reproductive', labelZh: '生殖', color: '#C77DA0' },
  musculoskeletal: { label: 'Spine & joints', labelZh: '骨骼关节', color: '#8F7E63' },
};

export interface Ellipse {
  cx: number;
  cy: number;
  rx: number;
  ry: number;
  /** degrees, about its own center */
  rot?: number;
}

export type OutlineShape =
  | { kind: 'rect'; x: number; y: number; w: number; h: number; r: number; rot?: number; ox?: number; oy?: number }
  | { kind: 'path'; d: string };

export interface ReflexZone {
  id: string;
  name: string;
  nameZh: string;
  /** chart label when nameZh is too long to fit */
  label?: string;
  shapes: Ellipse[];
  group: ZoneGroup;
  organIds: OrganId[];
  effect: string;
  effectZh: string;
  /** only on this side's chart (e.g. heart zone on the left palm) */
  side?: Side;
  /** an acupoint (small dot) rather than a reflex area */
  point?: boolean;
}

export interface ChartFace {
  id: string;
  label: string;
  labelZh: string;
  /** which side the drawing depicts; the other side renders mirrored */
  drawnSide: Side;
  outline: OutlineShape[];
  guides: string[];
  /** schematic bones / grid the zones are placed against, drawn dashed */
  bones: string[];
  zones: ReflexZone[];
}

export interface ReflexChart {
  id: 'hand' | 'ear' | 'foot';
  title: string;
  titleZh: string;
  viewBox: [number, number, number, number];
  /** x' = mirrorWidth - x for the mirrored side */
  mirrorWidth: number;
  labelSize: number;
  faces: ChartFace[];
  /** where the pulse leaves the 3D body */
  anchors: Record<Side, Vec3>;
}

const e = (cx: number, cy: number, rx: number, ry = rx, rot?: number): Ellipse => ({ cx, cy, rx, ry, rot });

// ---- Hand -------------------------------------------------------------------------------
// Thumb: capsule rotated -22° about its MCP joint (60, 315); d = distance up the thumb.
const THUMB_ROT = -22;
const onThumb = (d: number): [number, number] => [60 - 0.375 * d, 315 - 0.927 * d];

// Metacarpals 2–5 run from the finger base (t = 0) to the wrist (t = 1).
const METACARPALS: [number, number, number, number][] = [
  [88, 205, 125, 360],
  [133, 205, 143, 360],
  [178, 205, 162, 360],
  [220, 210, 180, 358],
];
const alongMetacarpal = (i: number, t: number): [number, number] => {
  const [x0, y0, x1, y1] = METACARPALS[i];
  return [x0 + (x1 - x0) * t, y0 + (y1 - y0) * t];
};
const between = (i: number, t: number): [number, number] => {
  const [ax, ay] = alongMetacarpal(i, t);
  const [bx, by] = alongMetacarpal(i + 1, t);
  return [(ax + bx) / 2, (ay + by) / 2];
};
const at = ([cx, cy]: [number, number], rx: number, ry = rx, rot?: number) => e(cx, cy, rx, ry, rot);

const HAND_OUTLINE: OutlineShape[] = [
  { kind: 'rect', x: 95, y: 350, w: 110, h: 80, r: 12 },
  { kind: 'rect', x: 40, y: 185, w: 40, h: 130, r: 20, rot: THUMB_ROT, ox: 60, oy: 315 },
  { kind: 'rect', x: 68, y: 70, w: 40, h: 150, r: 20 },
  { kind: 'rect', x: 113, y: 45, w: 40, h: 175, r: 20 },
  { kind: 'rect', x: 158, y: 60, w: 40, h: 160, r: 20 },
  { kind: 'rect', x: 203, y: 105, w: 34, h: 115, r: 17 },
  { kind: 'rect', x: 60, y: 185, w: 180, h: 185, r: 40 },
];

const [thumbIpX, thumbIpY] = onThumb(75);
const HAND_BONES = [
  ...METACARPALS.map(([x0, y0, x1, y1]) => `M ${x0} ${y0} L ${x1} ${y1}`),
  `M 60 315 L 100 358`,
  `M 60 315 L ${onThumb(125).join(' ')}`,
  `M ${thumbIpX - 14} ${thumbIpY - 6} L ${thumbIpX + 14} ${thumbIpY + 6}`,
];
const WRIST_CREASE = 'M 100 374 L 200 374';

const PALM_ZONES: ReflexZone[] = [
  {
    id: 'palm-brain', name: 'Brain', nameZh: '大脑',
    shapes: [at(onThumb(108), 13, 17, THUMB_ROT)],
    group: 'head', organIds: ['brain'],
    effect: 'Thumb pad. Pressed for headache, dizziness and poor sleep.',
    effectZh: '拇指指腹。按压用于头痛、头晕、失眠。',
  },
  {
    id: 'palm-pituitary', name: 'Pituitary', nameZh: '垂体',
    shapes: [at(onThumb(93), 5)],
    group: 'head', organIds: ['brain'],
    effect: 'Center of the thumb pad. Said to balance hormones.',
    effectZh: '拇指指腹中央。传统认为可调节内分泌。',
  },
  {
    id: 'palm-neck', name: 'Neck', nameZh: '颈项',
    shapes: [at(onThumb(40), 13, 8, THUMB_ROT)],
    group: 'musculoskeletal', organIds: ['throat', 'spine'],
    effect: 'Base section of the thumb. For a stiff neck.',
    effectZh: '拇指近节。用于颈项僵硬酸痛。',
  },
  {
    id: 'palm-sinuses', name: 'Frontal sinuses', nameZh: '额窦',
    shapes: [e(88, 86, 12), e(133, 61, 12), e(178, 76, 12), e(220, 119, 11)],
    group: 'senses', organIds: ['sinuses'],
    effect: 'Fingertips. For a blocked nose, sinus pressure, frontal headache.',
    effectZh: '各指顶端。用于鼻塞、鼻窦胀痛、前额头痛。',
  },
  {
    id: 'palm-eyes', name: 'Eyes', nameZh: '眼',
    shapes: [e(88, 208, 15, 6), e(133, 208, 15, 6)],
    group: 'senses', organIds: ['eyes'],
    effect: 'Roots of index and middle fingers. For tired, strained eyes.',
    effectZh: '食指、中指根部。用于眼疲劳、干涩。',
  },
  {
    id: 'palm-ears', name: 'Ears', nameZh: '耳',
    shapes: [e(178, 208, 15, 6), e(220, 211, 13, 6)],
    group: 'senses', organIds: ['ears'],
    effect: 'Roots of ring and little fingers. For ringing ears and ear ache.',
    effectZh: '无名指、小指根部。用于耳鸣、耳痛。',
  },
  {
    id: 'palm-lungs', name: 'Lungs & bronchi', nameZh: '肺·支气管',
    shapes: [e(156, 228, 72, 7)],
    group: 'respiratory', organIds: ['lung-l', 'lung-r'],
    effect: 'Band across the heads of metacarpals 2–5. For coughs and chest tightness.',
    effectZh: '第2–5掌骨头横带。用于咳嗽、胸闷。',
  },
  {
    id: 'palm-shoulder', name: 'Shoulder', nameZh: '肩',
    shapes: [e(236, 232, 5, 12)],
    group: 'musculoskeletal', organIds: ['shoulders'],
    effect: 'Little-finger edge at the knuckle. For stiff shoulders.',
    effectZh: '第5掌指关节尺侧。用于肩部僵硬酸痛。',
  },
  {
    id: 'palm-heart', name: 'Heart', nameZh: '心',
    shapes: [at(between(2, 0.25), 13, 10)],
    group: 'heart', organIds: ['heart'], side: 'left',
    effect: 'Left hand only, between metacarpals 4 and 5 near the knuckles. For palpitations and restlessness.',
    effectZh: '仅左手，第4、5掌骨间近掌骨头处。用于心悸、心烦。',
  },
  {
    id: 'palm-spleen', name: 'Spleen', nameZh: '脾',
    shapes: [at(between(2, 0.47), 12, 9)],
    group: 'digestive', organIds: ['stomach', 'intestines'], side: 'left',
    effect: 'Left hand only, below the heart zone. TCM spleen: appetite, digestion, fatigue.',
    effectZh: '仅左手，心反射区下方。中医之脾：食欲、消化、乏力。',
  },
  {
    id: 'palm-liver', name: 'Liver', nameZh: '肝',
    shapes: [at(between(2, 0.38), 16, 19)],
    group: 'digestive', organIds: ['liver'], side: 'right',
    effect: 'Right hand only, between metacarpals 4 and 5 at mid-shaft. Said to support detox and ease irritability.',
    effectZh: '仅右手，第4、5掌骨体中段之间。传统认为可助肝排毒、平肝除烦。',
  },
  {
    id: 'palm-stomach', name: 'Stomach', nameZh: '胃',
    shapes: [e(70, 326, 9, 7, 45)],
    group: 'digestive', organIds: ['stomach'],
    effect: 'Far end of the thumb metacarpal. For indigestion and bloating.',
    effectZh: '第1掌骨体远端。用于消化不良、胃胀。',
  },
  {
    id: 'palm-pancreas', name: 'Pancreas', nameZh: '胰',
    shapes: [e(80, 337, 6)],
    group: 'digestive', organIds: ['pancreas'],
    effect: 'Middle of the thumb metacarpal. Traditionally linked to blood sugar.',
    effectZh: '第1掌骨体中部。传统上与血糖调节相关。',
  },
  {
    id: 'palm-duodenum', name: 'Duodenum', nameZh: '十二指肠',
    shapes: [e(90, 348, 6)],
    group: 'digestive', organIds: ['stomach', 'intestines'],
    effect: 'Near end of the thumb metacarpal. For stomach ache after meals.',
    effectZh: '第1掌骨体近端。用于餐后胃痛、腹胀。',
  },
  {
    id: 'palm-adrenal', name: 'Adrenals', nameZh: '肾上腺',
    shapes: [at(between(0, 0.22), 6)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Between metacarpals 2 and 3, below the knuckles. Traditionally for inflammation and allergy.',
    effectZh: '第2、3掌骨间，掌骨头下方。传统用于炎症、过敏。',
  },
  {
    id: 'palm-kidneys', name: 'Kidneys', nameZh: '肾',
    shapes: [at(alongMetacarpal(1, 0.5), 10, 13)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Middle of metacarpal 3, center of the palm. For fatigue and lower-back ache.',
    effectZh: '第3掌骨中点，掌心。用于疲劳、腰酸。',
  },
  {
    id: 'palm-colon', name: 'Colon', nameZh: '结肠',
    shapes: [e(150, 305, 55, 5), e(214, 322, 6, 20)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Across the lower-middle palm and down the little-finger side. For constipation.',
    effectZh: '掌中下部横带及小指侧纵带。用于便秘。',
  },
  {
    id: 'palm-small-intestine', name: 'Small intestine', nameZh: '小肠',
    shapes: [e(150, 328, 32, 11)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Hollow of the lower palm, framed by the colon. For poor absorption.',
    effectZh: '掌心下部凹陷，结肠环绕之中。用于消化吸收不良。',
  },
  {
    id: 'palm-bladder', name: 'Bladder', nameZh: '膀胱',
    shapes: [e(146, 353, 10, 7)],
    group: 'urinary', organIds: ['bladder'],
    effect: 'Where the thumb and little-finger mounds meet, above the wrist. For frequent urination.',
    effectZh: '大小鱼际交接处凹陷。用于尿频。',
  },
  {
    id: 'palm-gonads', name: 'Reproductive', nameZh: '生殖腺',
    shapes: [e(150, 385, 24, 6)],
    group: 'reproductive', organIds: ['uterus'],
    effect: 'Middle of the wrist crease. For menstrual discomfort.',
    effectZh: '腕横纹中点。用于经期不适。',
  },
];

const NAILS = [e(88, 88, 11, 13), e(133, 63, 11, 13), e(178, 78, 11, 13), e(220, 121, 9, 11)];
const BACK_GUIDES = [
  ...NAILS.map(({ cx, cy, rx, ry }) => `M ${cx - rx} ${cy} a ${rx} ${ry} 0 1 0 ${rx * 2} 0 a ${rx} ${ry} 0 1 0 ${-rx * 2} 0`),
  WRIST_CREASE,
];

const BACK_ZONES: ReflexZone[] = [
  {
    id: 'back-cervical', name: 'Cervical spine', nameZh: '颈椎',
    shapes: [e(156, 232, 70, 7)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Far fifth of each metacarpal. For neck stiffness.',
    effectZh: '各掌骨背侧远端1/5。用于颈椎僵硬。',
  },
  {
    id: 'back-thoracic', name: 'Thoracic spine', nameZh: '胸椎',
    shapes: [e(152, 266, 62, 11)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Middle of each metacarpal. For upper-back ache.',
    effectZh: '各掌骨背侧中段。用于胸背酸痛。',
  },
  {
    id: 'back-lumbar', name: 'Lumbar spine', nameZh: '腰椎',
    shapes: [e(150, 320, 52, 15)],
    group: 'musculoskeletal', organIds: ['spine', 'kidney-l', 'kidney-r'],
    effect: 'Near half of each metacarpal. For lower-back ache.',
    effectZh: '各掌骨背侧近端。用于腰痛。',
  },
  {
    id: 'back-sacrum', name: 'Sacrum & coccyx', nameZh: '骶尾骨',
    shapes: [e(150, 362, 38, 6)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Where the metacarpals meet the wrist. For tailbone and sciatic pain.',
    effectZh: '腕掌关节处。用于骶尾痛、坐骨神经痛。',
  },
  {
    id: 'back-hegu', name: 'Hegu (LI4)', nameZh: '合谷', point: true,
    shapes: [e(94, 285, 7)],
    group: 'head', organIds: ['brain', 'shoulders'],
    effect: 'Between metacarpals 1 and 2, level with the middle of the 2nd. The classic point for headache, toothache and face pain. Avoid in pregnancy.',
    effectZh: '第1、2掌骨间，第2掌骨中点桡侧。头痛、牙痛、面痛常用穴。孕妇忌按。',
  },
  {
    id: 'back-luozhen', name: 'Luozhen (EX-UE8)', nameZh: '落枕', point: true,
    shapes: [at(between(0, 0.2), 6)],
    group: 'musculoskeletal', organIds: ['spine', 'shoulders'],
    effect: 'Between metacarpals 2 and 3, just behind the knuckles. Press while slowly turning the head for a stiff neck.',
    effectZh: '第2、3掌骨间，掌指关节后。落枕时边按边缓慢转头。',
  },
  {
    id: 'back-zhongzhu', name: 'Zhongzhu (SJ3)', nameZh: '中渚', point: true,
    shapes: [at(between(2, 0.2), 6)],
    group: 'senses', organIds: ['ears'],
    effect: 'Between metacarpals 4 and 5, behind the knuckles. For ringing ears and one-sided headache.',
    effectZh: '第4、5掌骨间，掌指关节后。用于耳鸣、偏头痛。',
  },
  {
    id: 'back-yemen', name: 'Yemen (SJ2)', nameZh: '液门', point: true,
    shapes: [e(199, 213, 5)],
    group: 'senses', organIds: ['throat', 'ears'],
    effect: 'Web between ring and little fingers. For sore throat and ear problems.',
    effectZh: '无名指与小指指蹼缘。用于咽喉肿痛、耳病。',
  },
  {
    id: 'back-houxi', name: 'Houxi (SI3)', nameZh: '后溪', point: true,
    shapes: [e(240, 240, 6)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Little-finger edge, behind the knuckle. For stiff neck and upper-back pain.',
    effectZh: '小指尺侧，第5掌指关节后。用于颈项强痛、上背痛。',
  },
  {
    id: 'back-yaotong', name: 'Yaotongdian (EX-UE7)', nameZh: '腰痛点', point: true,
    shapes: [at(between(0, 0.55), 6), at(between(2, 0.55), 6)],
    group: 'musculoskeletal', organIds: ['spine', 'kidney-l', 'kidney-r'],
    effect: 'Two points between metacarpals 2–3 and 4–5, halfway to the wrist. For acute low-back strain.',
    effectZh: '第2、3及第4、5掌骨间，掌指关节与腕横纹中点。用于急性腰扭伤。',
  },
  {
    id: 'back-yangxi', name: 'Yangxi (LI5)', nameZh: '阳溪', point: true,
    shapes: [e(104, 376, 6)],
    group: 'head', organIds: ['brain'],
    effect: 'Thumb end of the wrist crease, in the hollow. For wrist pain, headache and toothache.',
    effectZh: '腕背横纹桡侧凹陷中。用于腕痛、头痛、牙痛。',
  },
  {
    id: 'back-yangchi', name: 'Yangchi (SJ4)', nameZh: '阳池', point: true,
    shapes: [e(170, 378, 6)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Middle of the back wrist crease, little-finger side. For wrist pain and cold hands.',
    effectZh: '腕背横纹中，指伸肌腱尺侧凹陷。用于腕痛、手足怕冷。',
  },
  {
    id: 'back-waiguan', name: 'Waiguan (SJ5)', nameZh: '外关', point: true,
    shapes: [e(160, 410, 7)],
    group: 'head', organIds: ['brain', 'ears'],
    effect: 'Two thumb-widths above the wrist crease, between the forearm bones. For headache, ear and wrist pain.',
    effectZh: '腕背横纹上2寸，尺桡骨之间。用于头痛、耳病、腕痛。',
  },
];

// ---- Ear (left, tragus on the left) ------------------------------------------------------

const EAR_OUTLINE: OutlineShape[] = [
  {
    kind: 'path',
    d: 'M 120 18 C 200 8, 248 80, 238 160 C 230 222, 192 250, 178 290 C 168 322, 178 372, 136 388 C 98 398, 82 362, 88 330 C 93 302, 78 282, 66 252 C 52 214, 40 170, 50 110 C 60 50, 90 24, 120 18 Z',
  },
];

const EAR_GUIDES = [
  'M 80 60 C 130 30, 205 60, 212 140 C 216 200, 186 236, 170 264',
  'M 150 268 C 170 230, 178 180, 170 130 C 166 105, 170 85, 182 58',
  'M 170 130 C 150 115, 125 110, 95 118',
  'M 95 128 C 130 120, 160 135, 162 180 C 164 230, 140 262, 110 262 C 85 262, 72 245, 70 225',
  'M 58 175 C 90 165, 120 168, 140 178',
  'M 54 195 C 72 200, 74 240, 58 250',
  'M 110 262 C 125 272, 145 272, 152 262',
];

// Earlobe: the standard 3×3 grid (LO1–LO9), front column nearest the face.
const LOBE_GRID = ['M 98 300 L 172 300', 'M 96 328 L 174 328', 'M 98 356 L 166 356', 'M 122 300 L 122 380', 'M 147 300 L 147 384'];
const lobe = (col: number, row: number, r = 8) => e(110 + col * 24, 314 + row * 28, r);

const EAR_ZONES: ReflexZone[] = [
  {
    id: 'ear-apex', name: 'Ear apex (HX6,7i)', nameZh: '耳尖', point: true,
    shapes: [e(132, 26, 7)],
    group: 'head', organIds: ['brain', 'heart'],
    effect: 'Top of the helix. Traditionally pricked to bring down fever and high blood pressure.',
    effectZh: '耳轮顶端。传统点刺用于退热、降压。',
  },
  {
    id: 'ear-tf-upper', name: 'Superior triangular fossa (TF1)', nameZh: '角窝上', point: true,
    shapes: [e(116, 84, 6)],
    group: 'heart', organIds: ['heart'],
    effect: 'Front-upper triangular fossa. Traditionally for high blood pressure.',
    effectZh: '三角窝前上部。传统用于高血压。',
  },
  {
    id: 'ear-shenmen', name: 'Shenmen (TF4)', nameZh: '神门', point: true,
    shapes: [e(160, 86, 7)],
    group: 'head', organIds: ['brain'],
    effect: 'Back-upper triangular fossa. The calming point: stress, anxiety, poor sleep, pain.',
    effectZh: '三角窝后1/3上部。安神要穴：压力、焦虑、失眠、疼痛。',
  },
  {
    id: 'ear-genitals', name: 'Internal genitals (TF2)', nameZh: '内生殖器', point: true,
    shapes: [e(112, 106, 6)],
    group: 'reproductive', organIds: ['uterus'],
    effect: 'Front-lower triangular fossa. For menstrual problems.',
    effectZh: '三角窝前1/3下部。用于月经不调、痛经。',
  },
  {
    id: 'ear-pelvis', name: 'Pelvis (TF5)', nameZh: '盆腔', point: true,
    shapes: [e(158, 112, 6)],
    group: 'reproductive', organIds: ['uterus', 'bladder'],
    effect: 'Back-lower triangular fossa. For pelvic and lower-abdominal pain.',
    effectZh: '三角窝后1/3下部。用于盆腔炎、下腹痛。',
  },
  {
    id: 'ear-sympathetic', name: 'Sympathetic (AH6a)', nameZh: '交感', point: true,
    shapes: [e(98, 119, 5)],
    group: 'heart', organIds: ['heart', 'stomach'],
    effect: 'Front tip of the inferior crus, under the helix. For spasms, palpitations, stomach cramps.',
    effectZh: '对耳轮下脚前端与耳轮内缘交界处。用于胃肠痉挛、心悸。',
  },
  {
    id: 'ear-elbow', name: 'Elbow (SF3)', nameZh: '肘', point: true,
    shapes: [e(196, 130, 6)],
    group: 'musculoskeletal', organIds: ['shoulders'],
    effect: 'Middle of the scapha. For elbow and arm pain.',
    effectZh: '耳舟中部。用于肘臂疼痛。',
  },
  {
    id: 'ear-shoulder', name: 'Shoulder (SF4,5)', nameZh: '肩', point: true,
    shapes: [e(194, 184, 6)],
    group: 'musculoskeletal', organIds: ['shoulders'],
    effect: 'Lower scapha. For stiff or frozen shoulder.',
    effectZh: '耳舟下部。用于肩周炎、肩痛。',
  },
  {
    id: 'ear-lumbosacral', name: 'Lumbosacral spine (AH9)', nameZh: '腰骶椎',
    shapes: [e(180, 158, 5, 14)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Upper antihelix body, outer edge. For low-back pain.',
    effectZh: '对耳轮体上部外缘。用于腰骶痛。',
  },
  {
    id: 'ear-thoracic', name: 'Thoracic spine (AH11)', nameZh: '胸椎',
    shapes: [e(178, 206, 5, 14)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Middle antihelix body, outer edge. For upper-back pain.',
    effectZh: '对耳轮体中部外缘。用于胸背痛。',
  },
  {
    id: 'ear-cervical', name: 'Cervical spine (AH13)', nameZh: '颈椎',
    shapes: [e(166, 248, 5, 11)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Lower antihelix body, outer edge. For neck pain.',
    effectZh: '对耳轮体下部外缘。用于颈椎病、落枕。',
  },
  {
    id: 'ear-bladder', name: 'Bladder (CO9)', nameZh: '膀胱', point: true,
    shapes: [e(120, 134, 6)],
    group: 'urinary', organIds: ['bladder'],
    effect: 'Cymba, under the inferior crus, front. For frequent urination.',
    effectZh: '耳甲艇，对耳轮下脚下方前部。用于尿频、尿急。',
  },
  {
    id: 'ear-kidney', name: 'Kidney (CO10)', nameZh: '肾', point: true,
    shapes: [e(141, 134, 7)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Cymba, under the inferior crus, back. For fatigue, low back ache, ringing ears.',
    effectZh: '耳甲艇，对耳轮下脚下方后部。用于疲劳、腰酸、耳鸣。',
  },
  {
    id: 'ear-pancreas', name: 'Pancreas & gallbladder (CO11)', nameZh: '胰胆', point: true,
    shapes: [e(156, 147, 6)],
    group: 'digestive', organIds: ['pancreas'],
    effect: 'Back-upper cymba. For indigestion and a bitter taste.',
    effectZh: '耳甲艇后上部。用于消化不良、口苦。',
  },
  {
    id: 'ear-liver', name: 'Liver (CO12)', nameZh: '肝', point: true,
    shapes: [e(158, 166, 7)],
    group: 'digestive', organIds: ['liver'],
    effect: 'Back-lower cymba. For irritability, tired or dry eyes.',
    effectZh: '耳甲艇后下部。用于烦躁易怒、眼睛干涩疲劳。',
  },
  {
    id: 'ear-large-intestine', name: 'Large intestine (CO7)', nameZh: '大肠', point: true,
    shapes: [e(98, 153, 6)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Above the helix root, front third. For constipation.',
    effectZh: '耳轮脚上方前1/3。用于便秘、腹泻。',
  },
  {
    id: 'ear-small-intestine', name: 'Small intestine (CO6)', nameZh: '小肠', point: true,
    shapes: [e(117, 156, 6)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Above the helix root, middle third. For poor digestion.',
    effectZh: '耳轮脚上方中1/3。用于消化不良。',
  },
  {
    id: 'ear-duodenum', name: 'Duodenum (CO5)', nameZh: '十二指肠', point: true,
    shapes: [e(136, 161, 6)],
    group: 'digestive', organIds: ['stomach', 'intestines'],
    effect: 'Above the helix root, back third. For duodenal ulcer pain.',
    effectZh: '耳轮脚上方后1/3。用于十二指肠溃疡疼痛。',
  },
  {
    id: 'ear-stomach', name: 'Stomach (CO4)', nameZh: '胃', point: true,
    shapes: [e(142, 182, 7)],
    group: 'digestive', organIds: ['stomach'],
    effect: 'Where the helix root ends. For stomach ache, nausea, acid.',
    effectZh: '耳轮脚消失处。用于胃痛、恶心、反酸。',
  },
  {
    id: 'ear-spleen', name: 'Spleen (CO13)', nameZh: '脾', point: true,
    shapes: [e(152, 204, 6)],
    group: 'digestive', organIds: ['stomach', 'intestines'],
    effect: 'Back-upper cavum. TCM spleen: appetite, digestion, fatigue.',
    effectZh: '耳甲腔后上部。中医之脾：食欲、消化、乏力。',
  },
  {
    id: 'ear-heart', name: 'Heart (CO15)', nameZh: '心', point: true,
    shapes: [e(118, 216, 7)],
    group: 'heart', organIds: ['heart'],
    effect: 'Center of the cavum. For palpitations and restless sleep.',
    effectZh: '耳甲腔正中凹陷处。用于心悸、心烦失眠。',
  },
  {
    id: 'ear-trachea', name: 'Trachea (CO16)', nameZh: '气管', point: true,
    shapes: [e(96, 208, 5)],
    group: 'respiratory', organIds: ['throat', 'lung-l', 'lung-r'],
    effect: 'Between the heart point and the ear canal. For cough.',
    effectZh: '心区与外耳门之间。用于咳嗽、气喘。',
  },
  {
    id: 'ear-lung', name: 'Lung (CO14)', nameZh: '肺',
    shapes: [e(114, 196, 16, 5), e(124, 238, 20, 6)],
    group: 'respiratory', organIds: ['lung-l', 'lung-r'],
    effect: 'Around the heart and trachea points. For cough; traditionally also skin and quitting smoking.',
    effectZh: '心、气管区周围。用于咳嗽，传统亦用于皮肤病、戒烟。',
  },
  {
    id: 'ear-sanjiao', name: 'Sanjiao (CO17)', nameZh: '三焦', point: true,
    shapes: [e(106, 252, 5)],
    group: 'digestive', organIds: ['stomach', 'intestines', 'bladder'],
    effect: 'Bottom of the cavum, above the notch. TCM water passages: bloating, swelling.',
    effectZh: '耳甲腔底部，屏间切迹上方。中医三焦：腹胀、水肿。',
  },
  {
    id: 'ear-endocrine', name: 'Endocrine (CO18)', nameZh: '内分泌', point: true,
    shapes: [e(88, 258, 5)],
    group: 'head', organIds: ['pancreas', 'throat'],
    effect: 'Inside the notch below the tragus. Said to regulate hormones.',
    effectZh: '屏间切迹内。传统认为可调节内分泌。',
  },
  {
    id: 'ear-nose', name: 'External nose (TG1,2i)', nameZh: '外鼻', point: true,
    shapes: [e(62, 222, 5)],
    group: 'senses', organIds: ['sinuses'],
    effect: 'Middle of the tragus, outer face. For a blocked or runny nose.',
    effectZh: '耳屏外侧面中部。用于鼻塞、流涕。',
  },
  {
    id: 'ear-throat', name: 'Throat (TG3)', nameZh: '咽喉', point: true,
    shapes: [e(74, 206, 5)],
    group: 'senses', organIds: ['throat'],
    effect: 'Inner face of the tragus, upper half. For sore throat and hoarseness.',
    effectZh: '耳屏内侧面上1/2。用于咽痛、声音嘶哑。',
  },
  {
    id: 'ear-adrenal', name: 'Adrenal (TG2p)', nameZh: '肾上腺', point: true,
    shapes: [e(60, 246, 5)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Lower tip of the tragus. Traditionally for inflammation, allergy and low blood pressure.',
    effectZh: '耳屏游离缘下部尖端。传统用于炎症、过敏、低血压。',
  },
  {
    id: 'ear-forehead', name: 'Forehead (AT1)', nameZh: '额', point: true,
    shapes: [e(116, 272, 5)],
    group: 'head', organIds: ['brain', 'sinuses'],
    effect: 'Front of the antitragus. For frontal headache and dizziness.',
    effectZh: '对耳屏外侧面前部。用于前额痛、头晕。',
  },
  {
    id: 'ear-temple', name: 'Temple (AT2)', nameZh: '颞', point: true,
    shapes: [e(132, 276, 5)],
    group: 'head', organIds: ['brain'],
    effect: 'Middle of the antitragus. For one-sided headache.',
    effectZh: '对耳屏外侧面中部。用于偏头痛。',
  },
  {
    id: 'ear-occiput', name: 'Occiput (AT3)', nameZh: '枕', point: true,
    shapes: [e(148, 271, 5)],
    group: 'head', organIds: ['brain', 'spine'],
    effect: 'Back of the antitragus. For back-of-head pain and dizziness.',
    effectZh: '对耳屏外侧面后部。用于后头痛、眩晕。',
  },
  {
    id: 'ear-subcortex', name: 'Subcortex (AT4)', nameZh: '皮质下', point: true,
    shapes: [e(130, 262, 5)],
    group: 'head', organIds: ['brain'],
    effect: 'Inner face of the antitragus. For pain, poor sleep and nervous tension.',
    effectZh: '对耳屏内侧面。用于疼痛、失眠、神经紧张。',
  },
  {
    id: 'ear-teeth', name: 'Teeth (LO1)', nameZh: '牙', point: true,
    shapes: [lobe(0, 0, 7)],
    group: 'senses', organIds: ['face'],
    effect: 'Lobe square 1. For toothache.',
    effectZh: '耳垂1区。用于牙痛。',
  },
  {
    id: 'ear-eye', name: 'Eye (LO5)', nameZh: '眼', point: true,
    shapes: [lobe(1, 1)],
    group: 'senses', organIds: ['eyes'],
    effect: 'Center square of the lobe. For tired, red or dry eyes.',
    effectZh: '耳垂5区正中。用于眼疲劳、红肿、干涩。',
  },
  {
    id: 'ear-inner-ear', name: 'Inner ear (LO6)', nameZh: '内耳', point: true,
    shapes: [lobe(2, 1, 7)],
    group: 'senses', organIds: ['ears'],
    effect: 'Lobe square 6. For ringing ears and dizziness.',
    effectZh: '耳垂6区。用于耳鸣、眩晕。',
  },
  {
    id: 'ear-cheek', name: 'Cheek (LO5,6i)', nameZh: '面颊', point: true,
    shapes: [e(147, 328, 5)],
    group: 'senses', organIds: ['face'],
    effect: 'Between the eye and inner-ear squares. For facial pain and acne.',
    effectZh: '耳垂眼区与内耳区之间。用于面痛、痤疮。',
  },
  {
    id: 'ear-tonsil', name: 'Tonsil (LO7,8,9)', nameZh: '扁桃体',
    shapes: [e(134, 368, 30, 6)],
    group: 'senses', organIds: ['throat'],
    effect: 'Bottom row of the lobe. For swollen tonsils and sore throat.',
    effectZh: '耳垂7、8、9区。用于扁桃体肿痛、咽痛。',
  },
];

// ---- Foot (left foot, big toe on the right; sole and top share the outline) --------------

const FOOT_OUTLINE: OutlineShape[] = [
  { kind: 'path', d: 'M 70 150 C 55 220, 60 300, 72 380 C 78 452, 166 470, 174 400 C 178 350, 160 300, 172 250 C 180 210, 202 180, 200 150 C 198 120, 82 116, 70 150 Z' },
  { kind: 'rect', x: 160, y: 50, w: 46, h: 100, r: 23 },
  { kind: 'rect', x: 128, y: 62, w: 28, h: 84, r: 14 },
  { kind: 'rect', x: 100, y: 72, w: 26, h: 76, r: 13 },
  { kind: 'rect', x: 76, y: 84, w: 24, h: 66, r: 12 },
  { kind: 'rect', x: 55, y: 100, w: 22, h: 54, r: 11 },
];

const FOOT_BONES = [
  'M 183 148 L 166 262',
  'M 142 146 L 140 262',
  'M 113 148 L 118 262',
  'M 88 150 L 98 262',
  'M 66 154 L 80 262',
  'M 72 262 L 172 262',
];

const SOLE_ZONES: ReflexZone[] = [
  {
    id: 'sole-brain', name: 'Brain', nameZh: '大脑',
    shapes: [e(183, 82, 17, 22)],
    group: 'head', organIds: ['brain'],
    effect: 'Big-toe pad (left foot ↔ right brain). For headache, dizziness, poor sleep.',
    effectZh: '拇趾趾腹（左脚对应右脑）。用于头痛、头晕、失眠。',
  },
  {
    id: 'sole-pituitary', name: 'Pituitary', nameZh: '垂体',
    shapes: [e(183, 96, 5)],
    group: 'head', organIds: ['brain'],
    effect: 'Center of the big-toe pad. Said to balance hormones.',
    effectZh: '拇趾趾腹中央。传统认为可调节内分泌。',
  },
  {
    id: 'sole-sinuses', name: 'Frontal sinuses', nameZh: '额窦',
    shapes: [e(142, 76, 9), e(113, 86, 9), e(88, 96, 8), e(66, 111, 7)],
    group: 'senses', organIds: ['sinuses'],
    effect: 'Tips of toes 2–5. For a blocked nose and frontal headache.',
    effectZh: '第2–5趾趾端。用于鼻塞、前额头痛。',
  },
  {
    id: 'sole-neck', name: 'Neck', nameZh: '颈项',
    shapes: [e(183, 134, 16, 6)],
    group: 'musculoskeletal', organIds: ['throat', 'spine'],
    effect: 'Base of the big toe. For a stiff neck.',
    effectZh: '拇趾根部横纹处。用于颈项僵硬。',
  },
  {
    id: 'sole-eyes', name: 'Eyes', nameZh: '眼',
    shapes: [e(142, 136, 11, 5), e(113, 139, 11, 5)],
    group: 'senses', organIds: ['eyes'],
    effect: 'Base of toes 2 and 3. For tired, strained eyes.',
    effectZh: '第2、3趾根部。用于眼疲劳。',
  },
  {
    id: 'sole-ears', name: 'Ears', nameZh: '耳',
    shapes: [e(88, 143, 10, 5), e(66, 147, 9, 5)],
    group: 'senses', organIds: ['ears'],
    effect: 'Base of toes 4 and 5. For ringing ears.',
    effectZh: '第4、5趾根部。用于耳鸣。',
  },
  {
    id: 'sole-thyroid', name: 'Thyroid', nameZh: '甲状腺',
    shapes: [e(172, 168, 8, 18, -20)],
    group: 'head', organIds: ['throat'],
    effect: 'Curved band on the ball of the big toe. Said to regulate metabolism.',
    effectZh: '第1跖骨头处弧形带。传统认为可调节代谢。',
  },
  {
    id: 'sole-trapezius', name: 'Trapezius', nameZh: '斜方肌',
    shapes: [e(106, 160, 38, 5)],
    group: 'musculoskeletal', organIds: ['shoulders'],
    effect: 'Just below the eye and ear zones. For tight shoulders.',
    effectZh: '眼、耳反射区下方横带。用于肩颈紧张。',
  },
  {
    id: 'sole-lungs', name: 'Lungs & bronchi', nameZh: '肺·支气管',
    shapes: [e(108, 178, 42, 8)],
    group: 'respiratory', organIds: ['lung-l', 'lung-r'],
    effect: 'Band across the ball of the foot. For cough and chest tightness.',
    effectZh: '前脚掌横带。用于咳嗽、胸闷。',
  },
  {
    id: 'sole-heart', name: 'Heart', nameZh: '心', side: 'left',
    shapes: [e(86, 204, 11, 10)],
    group: 'heart', organIds: ['heart'],
    effect: 'Left foot only, between metatarsals 4 and 5 below the lungs. For palpitations.',
    effectZh: '仅左脚，第4、5跖骨间，肺反射区下方。用于心悸。',
  },
  {
    id: 'sole-spleen', name: 'Spleen', nameZh: '脾', side: 'left',
    shapes: [e(88, 236, 10, 9)],
    group: 'digestive', organIds: ['stomach', 'intestines'],
    effect: 'Left foot only, below the heart zone. TCM spleen: appetite, digestion.',
    effectZh: '仅左脚，心反射区下方。中医之脾：食欲、消化。',
  },
  {
    id: 'sole-liver', name: 'Liver', nameZh: '肝', side: 'right',
    shapes: [e(90, 218, 18, 22)],
    group: 'digestive', organIds: ['liver'],
    effect: 'Right foot only, between metatarsals 4 and 5 below the lungs. Said to support detox.',
    effectZh: '仅右脚，第4、5跖骨间，肺反射区下方。传统认为可助肝排毒。',
  },
  {
    id: 'sole-stomach', name: 'Stomach', nameZh: '胃',
    shapes: [e(166, 214, 12, 11)],
    group: 'digestive', organIds: ['stomach'],
    effect: 'A finger-width behind the big-toe joint. For indigestion and bloating.',
    effectZh: '第1跖趾关节后方约一横指。用于消化不良、胃胀。',
  },
  {
    id: 'sole-pancreas', name: 'Pancreas', nameZh: '胰',
    shapes: [e(164, 237, 11, 5)],
    group: 'digestive', organIds: ['pancreas'],
    effect: 'Below the stomach zone. Traditionally linked to blood sugar.',
    effectZh: '胃反射区下方。传统上与血糖调节相关。',
  },
  {
    id: 'sole-duodenum', name: 'Duodenum', nameZh: '十二指肠',
    shapes: [e(162, 252, 11, 5)],
    group: 'digestive', organIds: ['stomach', 'intestines'],
    effect: 'Below the pancreas zone. For stomach ache after meals.',
    effectZh: '胰反射区下方。用于餐后胃痛。',
  },
  {
    id: 'sole-adrenal', name: 'Adrenals', nameZh: '肾上腺',
    shapes: [e(130, 202, 6)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Between metatarsals 2 and 3, a thumb-width behind their heads. For inflammation and allergy.',
    effectZh: '第2、3跖骨间，跖骨头后一拇指宽。用于炎症、过敏。',
  },
  {
    id: 'sole-yongquan', name: 'Yongquan (KI1)', nameZh: '涌泉', point: true,
    shapes: [e(126, 222, 5)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r', 'brain'],
    effect: 'Hollow at the front third of the sole when the toes curl. Grounding point: insomnia, dizziness, hot feet.',
    effectZh: '足底前1/3凹陷处（卷足时）。用于失眠、头晕、足心发热。',
  },
  {
    id: 'sole-kidneys', name: 'Kidneys', nameZh: '肾',
    shapes: [e(128, 244, 11, 14)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r'],
    effect: 'Middle of the sole, below the adrenals. For fatigue and lower-back ache.',
    effectZh: '足底中部，肾上腺下方。用于疲劳、腰酸。',
  },
  {
    id: 'sole-ureter', name: 'Ureter', nameZh: '输尿管',
    shapes: [e(145, 290, 4, 28, -28)],
    group: 'urinary', organIds: ['kidney-l', 'kidney-r', 'bladder'],
    effect: 'Line from the kidney zone down to the bladder. For urinary discomfort.',
    effectZh: '肾至膀胱的斜线带。用于排尿不畅。',
  },
  {
    id: 'sole-bladder', name: 'Bladder', nameZh: '膀胱',
    shapes: [e(160, 322, 10, 9)],
    group: 'urinary', organIds: ['bladder'],
    effect: 'Inner edge where the arch meets the heel. For frequent urination.',
    effectZh: '足底内侧，足弓与足跟交界处。用于尿频。',
  },
  {
    id: 'sole-colon', name: 'Colon', nameZh: '结肠',
    shapes: [e(108, 270, 38, 4), e(76, 300, 5, 28), e(110, 334, 34, 4)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Frames the small intestine: across, down the outer edge, across above the heel. For constipation.',
    effectZh: '环绕小肠：横结肠、外侧纵行结肠、足跟前横带。用于便秘。',
  },
  {
    id: 'sole-small-intestine', name: 'Small intestine', nameZh: '小肠',
    shapes: [e(110, 302, 26, 20)],
    group: 'digestive', organIds: ['intestines'],
    effect: 'Middle-lower sole, framed by the colon. For poor absorption.',
    effectZh: '足底中下部，结肠环绕之中。用于消化吸收不良。',
  },
  {
    id: 'sole-insomnia', name: 'Insomnia point', nameZh: '失眠点', point: true,
    shapes: [e(118, 372, 6)],
    group: 'head', organIds: ['brain'],
    effect: 'Front of the heel pad, center. For poor sleep.',
    effectZh: '足跟前部正中。用于失眠。',
  },
  {
    id: 'sole-gonads', name: 'Reproductive', nameZh: '生殖腺',
    shapes: [e(118, 414, 24, 16)],
    group: 'reproductive', organIds: ['uterus'],
    effect: 'Center of the heel. For menstrual discomfort.',
    effectZh: '足跟正中。用于经期不适。',
  },
  {
    id: 'sole-cervical', name: 'Cervical spine', nameZh: '颈椎',
    shapes: [e(193, 152, 3, 12)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Inner edge, big-toe joint. The spine runs along the inner arch. For neck pain.',
    effectZh: '足内侧缘拇趾关节处，脊柱沿足弓内侧分布。用于颈痛。',
  },
  {
    id: 'sole-thoracic', name: 'Thoracic spine', nameZh: '胸椎',
    shapes: [e(184, 206, 3, 30, 12)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Inner edge along the first metatarsal. For upper-back ache.',
    effectZh: '足内侧缘，沿第1跖骨。用于胸背酸痛。',
  },
  {
    id: 'sole-lumbar', name: 'Lumbar spine', nameZh: '腰椎',
    shapes: [e(168, 272, 3, 28, 8)],
    group: 'musculoskeletal', organIds: ['spine', 'kidney-l', 'kidney-r'],
    effect: 'Inner arch. For lower-back pain.',
    effectZh: '足弓内侧。用于腰痛。',
  },
  {
    id: 'sole-sacrum', name: 'Sacrum & coccyx', nameZh: '骶尾骨',
    shapes: [e(167, 355, 3, 34, -4)],
    group: 'musculoskeletal', organIds: ['spine'],
    effect: 'Inner heel edge. For tailbone and sciatic pain.',
    effectZh: '足跟内侧缘。用于骶尾痛、坐骨神经痛。',
  },
];

const TOENAILS = [e(183, 64, 12, 10), e(142, 74, 8, 7), e(113, 84, 7, 7), e(88, 95, 7, 6), e(66, 110, 6, 5)];

const TOP_ZONES: ReflexZone[] = [
  {
    id: 'top-xingjian', name: 'Xingjian (LV2)', nameZh: '行间', point: true,
    shapes: [e(158, 150, 5)],
    group: 'digestive', organIds: ['liver', 'eyes'],
    effect: 'Web between the big and second toes. For red eyes, headache, irritability.',
    effectZh: '第1、2趾间趾蹼缘。用于目赤、头痛、烦躁。',
  },
  {
    id: 'top-taichong', name: 'Taichong (LV3)', nameZh: '太冲', point: true,
    shapes: [e(160, 196, 6)],
    group: 'digestive', organIds: ['liver', 'brain'],
    effect: 'Between metatarsals 1 and 2, in the hollow before they meet. For stress, headache, high blood pressure.',
    effectZh: '第1、2跖骨间，跖骨结合部前凹陷中。用于情志不畅、头痛、高血压。',
  },
  {
    id: 'top-neiting', name: 'Neiting (ST44)', nameZh: '内庭', point: true,
    shapes: [e(128, 152, 5)],
    group: 'digestive', organIds: ['stomach', 'face'],
    effect: 'Web between the second and third toes. For toothache and stomach heat.',
    effectZh: '第2、3趾间趾蹼缘。用于牙痛、胃热。',
  },
  {
    id: 'top-zulinqi', name: 'Zulinqi (GB41)', nameZh: '足临泣', point: true,
    shapes: [e(90, 214, 6)],
    group: 'head', organIds: ['brain', 'eyes'],
    effect: 'Between metatarsals 4 and 5, near their base. For one-sided headache and eye pain.',
    effectZh: '第4、5跖骨底结合部前方。用于偏头痛、目痛。',
  },
  {
    id: 'top-chest', name: 'Chest & breast', nameZh: '胸',
    shapes: [e(122, 236, 36, 16)],
    group: 'respiratory', organIds: ['lung-l', 'lung-r', 'heart'],
    effect: 'Middle of the foot top, over metatarsals 2–4. For chest tightness.',
    effectZh: '足背第2–4跖骨中段。用于胸闷。',
  },
  {
    id: 'top-jiexi', name: 'Jiexi (ST41)', nameZh: '解溪', point: true,
    shapes: [e(122, 330, 7)],
    group: 'digestive', organIds: ['stomach', 'brain'],
    effect: 'Front of the ankle crease, between the two tendons. For ankle pain, headache, bloating.',
    effectZh: '踝关节前横纹中点，两筋之间。用于踝痛、头痛、腹胀。',
  },
];

export const REFLEX_CHARTS: Record<ReflexChart['id'], ReflexChart> = {
  hand: {
    id: 'hand',
    title: 'Hand reflex zones',
    titleZh: '手部反射区',
    viewBox: [-25, 30, 350, 405],
    mirrorWidth: 300,
    labelSize: 9.5,
    faces: [
      {
        id: 'palm',
        label: 'Palm',
        labelZh: '掌',
        drawnSide: 'left',
        outline: HAND_OUTLINE,
        guides: [WRIST_CREASE],
        bones: HAND_BONES,
        zones: PALM_ZONES,
      },
      {
        id: 'back',
        label: 'Back',
        labelZh: '背',
        drawnSide: 'right',
        outline: HAND_OUTLINE,
        guides: BACK_GUIDES,
        bones: HAND_BONES,
        zones: BACK_ZONES,
      },
    ],
    anchors: { left: [0.52, 0.02, 0.05], right: [-0.52, 0.02, 0.05] },
  },
  ear: {
    id: 'ear',
    title: 'Ear points',
    titleZh: '耳穴',
    viewBox: [20, 5, 240, 395],
    mirrorWidth: 280,
    labelSize: 7.5,
    faces: [
      {
        id: 'outer',
        label: 'Outer ear',
        labelZh: '耳廓',
        drawnSide: 'left',
        outline: EAR_OUTLINE,
        guides: EAR_GUIDES,
        bones: LOBE_GRID,
        zones: EAR_ZONES,
      },
    ],
    anchors: { left: [0.22, 1.43, 0.02], right: [-0.22, 1.43, 0.02] },
  },
  foot: {
    id: 'foot',
    title: 'Foot reflex zones',
    titleZh: '足部反射区',
    viewBox: [30, 30, 200, 440],
    mirrorWidth: 260,
    labelSize: 8,
    faces: [
      {
        id: 'sole',
        label: 'Sole',
        labelZh: '足底',
        drawnSide: 'left',
        outline: FOOT_OUTLINE,
        guides: [],
        bones: FOOT_BONES,
        zones: SOLE_ZONES,
      },
      {
        id: 'top',
        label: 'Top',
        labelZh: '足背',
        drawnSide: 'left',
        outline: FOOT_OUTLINE,
        guides: TOENAILS.map(({ cx, cy, rx, ry }) => `M ${cx - rx} ${cy} a ${rx} ${ry} 0 1 0 ${rx * 2} 0 a ${rx} ${ry} 0 1 0 ${-rx * 2} 0`),
        bones: FOOT_BONES,
        zones: TOP_ZONES,
      },
    ],
    anchors: { left: [0.16, -1.53, 0.12], right: [-0.16, -1.53, 0.12] },
  },
};
