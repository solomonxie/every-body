import { useEffect, type RefObject } from 'react';
import { useThree } from '@react-three/fiber';
import { Raycaster, Vector2 } from 'three';

export type Pick = { kind: 'point' | 'part'; id: string };
export type Picker = (x: number, y: number) => Pick | undefined;

const raycaster = new Raycaster();
const ndc = new Vector2();

/** Exposes a screen-point → point/part raycast, so taps from the gesture layer can hit 3D objects. Points win. */
export function TapPicker({ pickerRef }: { pickerRef: RefObject<Picker | null> }) {
  const { camera, scene, size } = useThree();

  useEffect(() => {
    pickerRef.current = (x, y) => {
      ndc.set((x / size.width) * 2 - 1, -(y / size.height) * 2 + 1);
      raycaster.setFromCamera(ndc, camera);
      const hits = raycaster.intersectObjects(scene.children, true);
      // point hit-spheres are invisible on purpose; parts must be showing
      const point = hits.find((h) => h.object.userData.pointId);
      if (point) return { kind: 'point', id: point.object.userData.pointId as string };
      const part = hits.find((h) => h.object.visible && h.object.userData.partId);
      return part && { kind: 'part', id: part.object.userData.partId as string };
    };
    return () => {
      pickerRef.current = null;
    };
  }, [camera, scene, size, pickerRef]);

  return null;
}
