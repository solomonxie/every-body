import { useMemo, useRef, useState } from 'react';
import { Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ReflexPulse } from '@/components/canvas/reflex-pulse';
import { createSceneBus, faceFront } from '@/components/canvas/scene-bus';
import { ChartView, zonesFor } from '@/components/reflex/chart-view';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { ModelView } from '@/components/viewer/model-view';
import { Pill } from '@/components/viewer/pill';
import { REFLEX_TRAVEL_MS } from '@/constants/reflex';
import { Spacing } from '@/constants/theme';
import { REFLEX_CHARTS, ZONE_GROUPS, type ReflexZone, type Side } from '@/data/reflex-charts';
import type { BodyPoint } from '@/types/BodyPoint';

const SKIN_TONE = '#F2C9A5';
const SIDES: { id: Side; label: string }[] = [
  { id: 'left', label: 'Left 左' },
  { id: 'right', label: 'Right 右' },
];

/** Hand / ear reflex chart with a 3D inset showing where the pressed zone acts. */
export default function ReflexChartScreen() {
  const { chart: chartId } = useLocalSearchParams<{ chart: string }>();
  const chart = REFLEX_CHARTS[chartId as keyof typeof REFLEX_CHARTS] ?? REFLEX_CHARTS.hand;

  const busRef = useRef(createSceneBus());
  const [faceId, setFaceId] = useState(chart.faces[0].id);
  const [side, setSide] = useState<Side>('right');
  const [showLabels, setShowLabels] = useState(true);
  const [selected, setSelected] = useState<ReflexZone | undefined>();
  const [pressTrigger, setPressTrigger] = useState(0);
  const [effectVisible, setEffectVisible] = useState(false);
  const effectTimer = useRef<ReturnType<typeof setTimeout>>(undefined);

  const face = chart.faces.find((f) => f.id === faceId) ?? chart.faces[0];
  const groups = [...new Set(zonesFor(face, side).map((zone) => zone.group))];

  const pulsePoint = useMemo<BodyPoint | undefined>(
    () =>
      selected && {
        id: selected.id,
        name: selected.name,
        nameZh: selected.nameZh,
        description: selected.effect,
        position: chart.anchors[side],
        target: {
          name: selected.name,
          nameZh: selected.nameZh,
          effect: selected.effect,
          effectZh: selected.effectZh,
          organIds: selected.organIds,
        },
      },
    [selected, side, chart],
  );

  const press = (zone: ReflexZone) => {
    const bus = busRef.current;
    bus.touched = true;
    faceFront(bus);
    bus.litOrgans = zone.organIds;
    bus.flashStart = -1;
    setSelected(zone);
    setPressTrigger((n) => n + 1);
    setEffectVisible(false);
    clearTimeout(effectTimer.current);
    effectTimer.current = setTimeout(() => setEffectVisible(true), REFLEX_TRAVEL_MS);
  };

  const changeView = (next: { face?: string; side?: Side }) => {
    if (next.face) setFaceId(next.face);
    if (next.side) setSide(next.side);
    setSelected(undefined);
    busRef.current.litOrgans = [];
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: `${chart.titleZh} ${chart.title}` }} />

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.controls}>
        {SIDES.map((s) => (
          <Pill key={s.id} label={s.label} selected={s.id === side} onPress={() => changeView({ side: s.id })} />
        ))}
        {chart.faces.length > 1 &&
          chart.faces.map((f) => (
            <Pill
              key={f.id}
              label={`${f.label} ${f.labelZh}`}
              selected={f.id === face.id}
              onPress={() => changeView({ face: f.id })}
            />
          ))}
        <Pill label="Labels 标注" selected={showLabels} onPress={() => setShowLabels(!showLabels)} />
      </ScrollView>

      <View style={styles.stage}>
        <ChartView
          chart={chart}
          face={face}
          side={side}
          selectedId={selected?.id}
          showLabels={showLabels}
          onSelect={press}
        />
        <View style={styles.inset}>
          <ModelView busRef={busRef} skinColor={SKIN_TONE} compact>
            <ReflexPulse point={pulsePoint} triggerKey={pressTrigger} busRef={busRef} />
          </ModelView>
        </View>
      </View>

      <View style={styles.legend}>
        {groups.map((group) => (
          <View key={group} style={styles.legendItem}>
            <View style={[styles.legendDot, { backgroundColor: ZONE_GROUPS[group].color }]} />
            <ThemedText type="small" themeColor="textSecondary">
              {ZONE_GROUPS[group].labelZh}
            </ThemedText>
          </View>
        ))}
      </View>

      <ThemedView type="backgroundElement" style={styles.panel}>
        <SafeAreaView edges={['bottom']}>
          <View style={styles.card}>
            {selected ? (
              <>
                <ThemedText type="smallBold">
                  {selected.name} · {selected.nameZh}
                </ThemedText>
                <View style={[styles.effect, !effectVisible && styles.pending]}>
                  <ThemedText type="small">{selected.effect}</ThemedText>
                  <ThemedText type="small">{selected.effectZh}</ThemedText>
                  <View style={styles.cardFooter}>
                    <ThemedText type="small" themeColor="textSecondary">
                      Traditional claim — not medical advice.
                    </ThemedText>
                    <Pressable onPress={() => press(selected)} hitSlop={8}>
                      <ThemedText type="smallBold">↻ Replay</ThemedText>
                    </Pressable>
                  </View>
                </View>
              </>
            ) : (
              <ThemedText type="small" themeColor="textSecondary">
                Tap a zone — the pulse on the little figure shows where it acts. 点按区域，查看对应器官。
              </ThemedText>
            )}
          </View>
        </SafeAreaView>
      </ThemedView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  controls: {
    gap: Spacing.two,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
  },
  stage: {
    flex: 1,
    paddingHorizontal: Spacing.two,
  },
  inset: {
    position: 'absolute',
    top: 0,
    left: Spacing.three,
    width: 84,
    height: 132,
    borderRadius: Spacing.three,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(43,34,80,0.2)',
  },
  legend: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one,
  },
  legendDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  panel: {
    borderTopLeftRadius: Spacing.four,
    borderTopRightRadius: Spacing.four,
  },
  card: {
    minHeight: 150,
    padding: Spacing.three,
    gap: Spacing.one,
  },
  effect: {
    gap: Spacing.one,
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
});
