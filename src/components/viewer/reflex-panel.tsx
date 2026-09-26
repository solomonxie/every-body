import { router } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { useBilingual, useName, useSettings } from '@/state/settings';
import type { BodyPoint, PointRegion } from '@/types/BodyPoint';

import { Pill } from './pill';

export type RegionFilter = PointRegion | 'all';

const CHART_LINKS = { foot: 'foot chart 足底反射区', hand: 'hand chart 手部反射区', ear: 'ear chart 耳穴图' } as const;

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
  const name = useName();
  const { showEn, showZh } = useBilingual();
  const { names } = useSettings().settings;

  return (
    <View style={styles.container}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {FILTERS.map((f) => (
          <Pill key={f.id} label={f.label} selected={f.id === filter} onPress={() => onFilter(f.id)} />
        ))}
      </ScrollView>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {visible.map((point) => (
          <Pill key={point.id} label={names === 'en' ? point.name : point.nameZh} selected={point.id === activePoint?.id} onPress={() => onPress(point)} />
        ))}
      </ScrollView>

      {filter !== 'all' && filter !== 'body' && (
        <Pressable onPress={() => router.push(`/reflex/${filter}`)} style={styles.chartLink}>
          <ThemedText type="smallBold">Open {CHART_LINKS[filter]} ›</ThemedText>
        </Pressable>
      )}

      {activePoint ? (
        <ThemedView style={styles.card}>
          <ThemedText type="smallBold">{name(activePoint.name, activePoint.nameZh)}</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            {activePoint.description}
          </ThemedText>
          {activePoint.target && (
            <View style={[styles.effect, !effectVisible && styles.pending]}>
              <ThemedText type="smallBold">→ {name(activePoint.target.name, activePoint.target.nameZh)}</ThemedText>
              {showEn && <ThemedText type="small">{activePoint.target.effect}</ThemedText>}
              {showZh && <ThemedText type="small">{activePoint.target.effectZh}</ThemedText>}
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
  chartLink: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.one,
  },
  prompt: {
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three,
  },
});
