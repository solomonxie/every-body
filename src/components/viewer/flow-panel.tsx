import { ScrollView, StyleSheet, View } from 'react-native';
import Slider from '@react-native-community/slider';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import type { BodyPoint } from '@/types/BodyPoint';

import { Pill } from './pill';

type Props = {
  stops: BodyPoint[];
  bpm: number;
  onBpm: (bpm: number) => void;
  activeStop?: BodyPoint;
  onStop: (stop: BodyPoint) => void;
};

/** Blood-flow controls: heart-rate scrub (the "try") and the loop's stops. */
export function FlowPanel({ stops, bpm, onBpm, activeStop, onStop }: Props) {
  return (
    <View style={styles.container}>
      <View style={styles.rateRow}>
        <ThemedText type="smallBold">Heart rate 心率</ThemedText>
        <ThemedText type="smallBold">{Math.round(bpm)} bpm</ThemedText>
      </View>
      <Slider style={styles.slider} minimumValue={40} maximumValue={180} value={bpm} onValueChange={onBpm} />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {stops.map((stop, i) => (
          <Pill
            key={stop.id}
            label={`${i + 1}. ${stop.name}`}
            selected={stop.id === activeStop?.id}
            onPress={() => onStop(stop)}
          />
        ))}
      </ScrollView>
      <ThemedView style={styles.card}>
        {activeStop ? (
          <>
            <ThemedText type="smallBold">
              {activeStop.name} · {activeStop.nameZh}
            </ThemedText>
            <ThemedText type="small" themeColor="textSecondary">
              {activeStop.description}
            </ThemedText>
          </>
        ) : (
          <ThemedText type="small" themeColor="textSecondary">
            Red = oxygen-rich, blue = oxygen-poor. Drag the heart rate and watch the flow follow.
          </ThemedText>
        )}
      </ThemedView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: Spacing.two,
  },
  rateRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.three,
  },
  slider: {
    marginHorizontal: Spacing.three,
  },
  row: {
    gap: Spacing.two,
    paddingHorizontal: Spacing.three,
  },
  card: {
    marginHorizontal: Spacing.three,
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.one,
  },
});
