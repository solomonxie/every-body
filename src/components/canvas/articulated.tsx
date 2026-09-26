import type { ReactNode } from 'react';
import { Quaternion, Vector3 } from 'three';

import { JOINTS, type Joint } from '@/data/body';

export type JointAngles = Record<string, number>;
export type Item = { id: string; node: ReactNode };

const inJoint = new Set(JOINTS.flatMap((j) => j.parts));

function JointGroup({ joint, angles, items }: { joint: Joint; angles: JointAngles; items: Item[] }) {
  const radians = ((angles[joint.id] ?? 0) * Math.PI) / 180;
  const quaternion = new Quaternion().setFromAxisAngle(new Vector3(...joint.axis).normalize(), radians);
  const [px, py, pz] = joint.pivot;
  return (
    <group position={joint.pivot} quaternion={quaternion}>
      <group position={[-px, -py, -pz]}>
        {items.filter((item) => joint.parts.includes(item.id)).map((item) => item.node)}
        {JOINTS.filter((child) => child.parent === joint.id).map((child) => (
          <JointGroup key={child.id} joint={child} angles={angles} items={items} />
        ))}
      </group>
    </group>
  );
}

/** Renders items with the ones belonging to a joint rotated about its pivot (nested: elbow inside shoulder). */
export function Articulated({ items, angles }: { items: Item[]; angles: JointAngles }) {
  return (
    <>
      {items.filter((item) => !inJoint.has(item.id)).map((item) => item.node)}
      {JOINTS.filter((j) => !j.parent).map((joint) => (
        <JointGroup key={joint.id} joint={joint} angles={angles} items={items} />
      ))}
    </>
  );
}
