import { useRef, useState } from 'react';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { BloodFlow } from '@/components/canvas/blood-flow';
import { PointMarkers } from '@/components/canvas/point-markers';
import { ReflexPulse } from '@/components/canvas/reflex-pulse';
import { createSceneBus, DEFAULT_BPM, faceFront, FOCUS, setFocus } from '@/components/canvas/scene-bus';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { FlowPanel } from '@/components/viewer/flow-panel';
import { ModelView } from '@/components/viewer/model-view';
import { ReflexPanel, type RegionFilter } from '@/components/viewer/reflex-panel';
import { REFLEX_TRAVEL_MS } from '@/constants/reflex';
import { Spacing } from '@/constants/theme';
import { POINTS_BY_SYSTEM } from '@/data/system-points';
import type { BodyPoint } from '@/types/BodyPoint';
import { BODY_SYSTEMS } from '@/types/BodySystem';

const SKIN_TONE = '#F2C9A5';

// TODO: swap the primitive Mannequin for the licensed anatomy model (IMPLEMENT_PLAN T3.6).
export default function ViewerScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id) ?? BODY_SYSTEMS[0];
  const systemPoints = POINTS_BY_SYSTEM[system.id];
  const isReflex = systemPoints?.points.some((point) => point.target) ?? false;
  const flowStops = systemPoints?.flow
    ? systemPoints.flow.pointIds.flatMap((pid) => systemPoints.points.find((p) => p.id === pid) ?? [])
    : undefined;

  const busRef = useRef(createSceneBus());
  const [activePointId, setActivePointId] = useState<string | undefined>();
  const [pressTrigger, setPressTrigger] = useState(0);
  const [effectVisible, setEffectVisible] = useState(false);
  const [filter, setFilter] = useState<RegionFilter>('all');
  const [bpm, setBpm] = useState(DEFAULT_BPM);
  const effectTimer = useRef<ReturnType<typeof setTimeout>>(undefined);

  const activePoint = systemPoints?.points.find((point) => point.id === activePointId);

  const pressPoint = (point: BodyPoint) => {
    const b = busRef.current;
    b.touched = true;
    setActivePointId(point.id);
    if (!point.target) return;
    faceFront(b);
    b.litOrgans = point.target.organIds;
    b.flashStart = -1;
    setPressTrigger((n) => n + 1);
    setEffectVisible(false);
    clearTimeout(effectTimer.current);
    effectTimer.current = setTimeout(() => setEffectVisible(true), REFLEX_TRAVEL_MS);
  };

  const pickPoint = (pointId: string) => {
    const point = systemPoints?.points.find((p) => p.id === pointId);
    if (point) pressPoint(point);
  };

  const changeFilter = (next: RegionFilter) => {
    setFilter(next);
    const b = busRef.current;
    setFocus(b, FOCUS[next]);
    b.touched = true;
    faceFront(b);
  };

  const changeBpm = (next: number) => {
    busRef.current.bpm = next;
    setBpm(next);
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen
        options={{
          title: system.name,
          headerRight: () => (
            <Pressable accessibilityLabel="System info" hitSlop={10} onPress={() => router.push(`/info/${system.id}`)}>
              <Text style={styles.infoGlyph}>ⓘ</Text>
            </Pressable>
          ),
        }}
      />
      <ModelView busRef={busRef} skinColor={isReflex ? SKIN_TONE : system.color} onPickPoint={pickPoint}>
        {systemPoints && <PointMarkers points={systemPoints.points} activeId={activePointId} />}
        {isReflex && <ReflexPulse point={activePoint} triggerKey={pressTrigger} busRef={busRef} />}
        {flowStops && <BloodFlow stops={flowStops} busRef={busRef} />}
      </ModelView>

      <ThemedView type="backgroundElement" style={styles.panel}>
        <SafeAreaView edges={['bottom']}>
          <View style={styles.panelBody}>
            {isReflex && systemPoints ? (
              <ReflexPanel
                points={systemPoints.points}
                filter={filter}
                onFilter={changeFilter}
                activePoint={activePoint}
                effectVisible={effectVisible}
                onPress={pressPoint}
              />
            ) : flowStops ? (
              <FlowPanel stops={flowStops} bpm={bpm} onBpm={changeBpm} activeStop={activePoint} onStop={pressPoint} />
            ) : (
              <ThemedText type="small" themeColor="textSecondary" style={styles.placeholder}>
                Placeholder figure — real {system.name.toLowerCase()} anatomy arrives with the licensed model.
                Try Reflex Map or Circulatory for the interactive demos.
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
  panel: {
    borderTopLeftRadius: Spacing.four,
    borderTopRightRadius: Spacing.four,
  },
  panelBody: {
    paddingTop: Spacing.three,
    paddingBottom: Spacing.two,
  },
  placeholder: {
    paddingHorizontal: Spacing.three,
    paddingBottom: Spacing.two,
  },
  infoGlyph: {
    fontSize: 22,
    color: '#6C4F9E',
  },
});
