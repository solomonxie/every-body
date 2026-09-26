import type { ReactNode, RefObject } from 'react';

import { Mannequin } from './mannequin';
import { OrbitRig } from './orbit-rig';
import type { SceneBusRef } from './scene-bus';
import { TapPicker, type Picker } from './tap-picker';

type Props = {
  busRef: SceneBusRef;
  skinColor: string;
  background: string;
  pickerRef: RefObject<Picker | null>;
  /** overlays that rotate with the body */
  children?: ReactNode;
};

export function BodyScene({ busRef, skinColor, background, pickerRef, children }: Props) {
  return (
    <>
      <color attach="background" args={[background]} />
      <ambientLight intensity={0.8} />
      <directionalLight position={[3, 4, 5]} intensity={1.1} />
      <directionalLight position={[-3, 2, -4]} intensity={0.4} />
      <OrbitRig busRef={busRef}>
        <Mannequin skinColor={skinColor} busRef={busRef} />
        {children}
      </OrbitRig>
      <TapPicker pickerRef={pickerRef} />
    </>
  );
}
