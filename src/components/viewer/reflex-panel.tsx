import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import type { BodyPoint, PointRegion } from '@/types/BodyPoint';

import { Pill } from './pill';

export type RegionFilter = PointRegion | 'all';

const FILTERS: { id: RegionFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'foot', label: 'Foot 足' },
  { id: 'hand', label: 'Hand 手' },
  { id: 'ear', label: 'Ear 耳' },
  { id: 'body', label: 'Body 身' },
];

type Props = {
  points: BodyPoint[];
  filter: RegionFilter;
  onFilter: (filter: RegionFilter) => void;
  activePoint?: BodyPoint;
  effectVisible: boolean;
  onPress: (point: BodyPoint) => void;
};

/** Points list + effect card for the Reflex Map — see docs/design/mvp/uiux/points.md. */
export function ReflexPanel({ points, filter, onFilter, activePoint, effectVisible, onPress }: Props) {
  const visible = filter === 'all' ? points : points.filter((point) => point.region === filter);

  return (
    <View style={styles.container}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {FILTERS.map((f) => (
          <Pill key={f.id} label={f.label} selected={f.id === filter} onPress={() => onFilter(f.id)} />
        ))}
      </ScrollView>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {visible.map((point) => (
          <Pill key={point.id} label={point.nameZh} selected={point.id === activePoint?.id} onPress={() => onPress(point)} />
        ))}
      </ScrollView>

      {activePoint ? (
        <ThemedView style={styles.card}>
          <ThemedText type="smallBold">
            {activePoint.name} · {activePoint.nameZh}
          </ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            {activePoint.description}
          </ThemedText>
          {activePoint.target && (
            <View style={[styles.effect, !effectVisible && styles.pending]}>
              <ThemedText type="smallBold">
                → {activePoint.target.name} · {activePoint.target.nameZh}
              </ThemedText>
              <ThemedText type="small">{activePoint.target.effect}</ThemedText>
              <ThemedText type="small">{activePoint.target.effectZh}</ThemedText>
              <View style={styles.cardFooter}>
                <ThemedText type="small" themeColor="textSecondary">
                  Traditional reflexology claim — not medical advice.
                </ThemedText>
                <Pressable onPress={() => onPress(activePoint)} hitSlop={8}>
                  <ThemedText type="smallBold">↻ Replay</ThemedText>
                </Pressable>
              </View>
            </View>
          )}
        </ThemedView>
      ) : (
        <ThemedText type="small" themeColor="textSecondary" style={styles.prompt}>
          Press a point — watch where it acts. Tap a dot on the body or a name above.
        </ThemedText>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: Spacing.two,
    minHeight: 290,
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
  effect: {
    gap: Spacing.one,
    paddingTop: Spacing.two,
  },
  pending: {
    opacity: 0,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: Spacing.two,
    paddingTop: Spacing.one,
  },
  prompt: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three,
  },
});
