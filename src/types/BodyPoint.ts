import type { OrganId } from '@/data/anatomy';

export type Vec3 = [number, number, number];

export type PointRegion = 'foot' | 'hand' | 'ear' | 'body';

export interface ReflexTarget {
  name: string;
  nameZh: string;
  /** what applying pressure at the point does here */
  effect: string;
  effectZh: string;
  /** organs the pulse travels to and lights up */
  organIds: OrganId[];
}

export interface BodyPoint {
  id: string;
  name: string;
  nameZh: string;
  description: string;
  region?: PointRegion;
  /** mannequin space: y up, figure faces +z, its right side is -x */
  position: Vec3;
  /** the related body part this point reflexively affects, for acupoint/reflex maps */
  target?: ReflexTarget;
}

export interface FlowPath {
  kind: 'blood';
  /** ordered point ids the animated particle travels through, looping back to the first */
  pointIds: string[];
}

export interface SystemPoints {
  points: BodyPoint[];
  flow?: FlowPath;
}
