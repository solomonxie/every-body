import type { ReactNode, RefObject } from 'react';

import type { JointAngles } from './articulated';
import { Mannequin } from './mannequin';
import { OrbitRig } from './orbit-rig';
import type { SceneBusRef } from './scene-bus';
import { TapPicker, type Picker } from './tap-picker';

type Props = {
  busRef: SceneBusRef;
  skinColor: string;
  background: string;
  skinOpacity?: number;
  showOrgans?: boolean;
  selectedId?: string;
  angles?: JointAngles;
  pickerRef: RefObject<Picker | null>;
  /** overlays that rotate with the body */
  children?: ReactNode;
};

export function BodyScene({ busRef, skinColor, background, skinOpacity, showOrgans, selectedId, angles, pickerRef, children }: Props) {
  return (
    <>
      <color attach="background" args={[background]} />
      <ambientLight intensity={0.8} />
      <directionalLight position={[3, 4, 5]} intensity={1.1} />
      <directionalLight position={[-3, 2, -4]} intensity={0.4} />
      <OrbitRig busRef={busRef}>
        <Mannequin skinColor={skinColor} busRef={busRef} skinOpacity={skinOpacity} showOrgans={showOrgans} selectedId={selectedId} angles={angles} />
        {children}
      </OrbitRig>
      <TapPicker pickerRef={pickerRef} />
    </>
  );
}
