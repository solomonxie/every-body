import { useEffect, type RefObject } from 'react';
import { useThree } from '@react-three/fiber';
import { Raycaster, Vector2 } from 'three';

export type Picker = (x: number, y: number) => string | undefined;

const raycaster = new Raycaster();
const ndc = new Vector2();

/** Exposes a screen-point → pointId raycast, so taps from the gesture layer can hit 3D markers. */
export function TapPicker({ pickerRef }: { pickerRef: RefObject<Picker | null> }) {
  const { camera, scene, size } = useThree();

  useEffect(() => {
    pickerRef.current = (x, y) => {
      ndc.set((x / size.width) * 2 - 1, -(y / size.height) * 2 + 1);
      raycaster.setFromCamera(ndc, camera);
      const hit = raycaster.intersectObjects(scene.children, true).find((h) => h.object.userData.pointId);
      return hit?.object.userData.pointId as string | undefined;
    };
    return () => {
      pickerRef.current = null;
    };
  }, [camera, scene, size, pickerRef]);

  return null;
}
