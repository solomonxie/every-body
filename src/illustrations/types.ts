import type { ComponentType } from 'react';

export type Params = Record<string, number>;

export type Bilingual = { en: string; zh: string };

export type ScrubControl = { param: string; label: string; min: number; max: number; unit?: string; digits?: number };

export type TryControl =
  | { mode: 'scrub'; scrubs: ScrubControl[] }
  | { mode: 'rhythm'; target: number; minRate: number; maxRate: number; label?: string }
  /** hold the button: `param` → 1 while held; `progress` fills over `seconds` of total hold */
  | { mode: 'hold'; param: string; progress: string; seconds: number; label: string }
  | { mode: 'compare'; param: string; options: { label: string; value: number }[] }
  | { mode: 'drag' };

export interface Step {
  kind: 'watch' | 'try';
  caption: Bilingual;
  /** param targets eased to on entering the step */
  set?: Params;
  try?: TryControl & {
    success: (params: Params) => boolean;
    ok: Bilingual;
    /** targets for "Show me" */
    demo?: Params;
  };
}

export type SceneProps = { params: Params; t: number };

export type DragHandler = (point: { x: number; y: number }, params: Params) => Params;

export type IllustrationGroup = 'bones' | 'first-aid' | 'blood' | 'illness' | 'pregnancy';

export interface Scenario {
  id: string;
  group: IllustrationGroup;
  title: Bilingual;
  /** shown once on the first step, e.g. "don't try this yourself" */
  warning?: Bilingual;
  params: Params;
  steps: Step[];
  Scene: ComponentType<SceneProps>;
  /** viewBox is 0 0 360 300; the point is in viewBox units */
  onDrag?: DragHandler;
  /** extra param changes on each rhythm tap */
  onTap?: (params: Params) => Params;
  sources: string[];
}

export const SCENE_W = 360;
export const SCENE_H = 300;
