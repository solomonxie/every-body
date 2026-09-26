export interface ReflexTarget {
  name: string;
  nameZh: string;
  /** what applying pressure at the point does here */
  effect: string;
  effectZh: string;
  /** symbolic placement on the placeholder sphere, in radians */
  lat: number;
  lon: number;
}

export interface BodyPoint {
  id: string;
  name: string;
  nameZh: string;
  description: string;
  /** placement on the placeholder sphere, in radians */
  lat: number;
  lon: number;
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
