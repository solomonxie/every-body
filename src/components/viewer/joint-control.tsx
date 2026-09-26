import { StyleSheet, View } from 'react-native';
import Slider from '@react-native-community/slider';

import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';
import { JOINTS, type Joint } from '@/data/body';
import { useName } from '@/state/settings';

type Props = { joint: Joint; angle: number; onChange: (degrees: number) => void };

/** "Try" for a tapped bone or muscle: move its joint through its range; the working muscle bulges. */
export function JointControl({ joint, angle, onChange }: Props) {
  const name = useName();
  const movers = joint.movers.map((id) => id.replace(/-[lr]$/, '')).join(', ');
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <ThemedText type="smallBold">Try ▸ {name(joint.name, joint.nameZh)}</ThemedText>
        <ThemedText type="smallBold">{Math.round(angle)}°</ThemedText>
      </View>
      <Slider minimumValue={0} maximumValue={joint.maxDeg} value={angle} onValueChange={onChange} />
      <ThemedText type="small" themeColor="textSecondary">
        {`Working muscle: ${movers} · range 0–${joint.maxDeg}°`}
      </ThemedText>
    </View>
  );
}

export const findJoint = (id: string) => JOINTS.find((j) => j.id === id);

const styles = StyleSheet.create({
  container: {
    marginHorizontal: Spacing.three,
    marginBottom: Spacing.two,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
});
