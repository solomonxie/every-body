import { useRef, useState } from 'react';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { BloodFlow } from '@/components/canvas/blood-flow';
import { PointMarkers } from '@/components/canvas/point-markers';
import { ReflexPulse } from '@/components/canvas/reflex-pulse';
import { SchematicBody } from '@/components/canvas/schematic-body';
import type { Pick } from '@/components/canvas/tap-picker';
import { createSceneBus, DEFAULT_BPM, faceFront, FOCUS, setFocus } from '@/components/canvas/scene-bus';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { FlowPanel } from '@/components/viewer/flow-panel';
import { LayerBar } from '@/components/viewer/layer-bar';
import { PartCard } from '@/components/viewer/part-card';
import { ModelView } from '@/components/viewer/model-view';
import { ReflexPanel, type RegionFilter } from '@/components/viewer/reflex-panel';
import { REFLEX_TRAVEL_MS } from '@/constants/reflex';
import { Spacing } from '@/constants/theme';
import { DEFAULT_LAYERS, SCHEMATIC_PARTS, type LayerId } from '@/data/body';
import { POINTS_BY_SYSTEM } from '@/data/system-points';
import type { BodyPoint } from '@/types/BodyPoint';
import { BODY_SYSTEMS } from '@/types/BodySystem';

const SKIN_TONE = '#F2C9A5';

export default function ViewerScreen() {
  const { id, point: pointParam, part: partParam } = useLocalSearchParams<{ id: string; point?: string; part?: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id) ?? BODY_SYSTEMS[0];
  const systemPoints = POINTS_BY_SYSTEM[system.id];
  const isReflex = systemPoints?.points.some((point) => point.target) ?? false;
  const flowStops = systemPoints?.flow
    ? systemPoints.flow.pointIds.flatMap((pid) => systemPoints.points.find((p) => p.id === pid) ?? [])
    : undefined;

  const initialPoint = systemPoints?.points.find((p) => p.id === pointParam);
  const busRef = useRef(createSceneBus(initialPoint?.target?.organIds));
  const [activePointId, setActivePointId] = useState<string | undefined>(initialPoint?.id);
  const [pressTrigger, setPressTrigger] = useState(initialPoint?.target ? 1 : 0);
  const [effectVisible, setEffectVisible] = useState(Boolean(initialPoint?.target));
  const [filter, setFilter] = useState<RegionFilter>('all');
  const [bpm, setBpm] = useState(DEFAULT_BPM);
  const effectTimer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const partLayer = SCHEMATIC_PARTS.find((p) => p.id === partParam)?.layer;
  const [layers, setLayers] = useState<LayerId[]>(() => {
    const base = DEFAULT_LAYERS[system.id] ?? ['skin', 'organs'];
    return partLayer && !base.includes(partLayer) ? [...base, partLayer] : base;
  });
  const [hidden, setHidden] = useState<string[]>([]);
  const [selectedPartId, setSelectedPartId] = useState<string | undefined>(partParam);
  const innerLayers = layers.some((layer) => layer !== 'skin');

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

  const pick = ({ kind, id: pickedId }: Pick) => {
    if (kind === 'part') {
      setSelectedPartId(pickedId === selectedPartId ? undefined : pickedId);
      return;
    }
    const point = systemPoints?.points.find((p) => p.id === pickedId);
    if (point) pressPoint(point);
  };

  const toggleLayer = (layer: LayerId) =>
    setLayers(layers.includes(layer) ? layers.filter((l) => l !== layer) : [...layers, layer]);

  const hidePart = (partId: string) => {
    setHidden([...hidden, partId]);
    setSelectedPartId(undefined);
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
      <ModelView
        busRef={busRef}
        skinColor={isReflex ? SKIN_TONE : system.color}
        skinOpacity={layers.includes('skin') ? (innerLayers ? 0.12 : 0.32) : 0}
        showOrgans={layers.includes('organs')}
        selectedId={selectedPartId}
        onPick={pick}
      >
        <SchematicBody layers={layers} hidden={hidden} selectedId={selectedPartId} />
        {systemPoints && <PointMarkers points={systemPoints.points} activeId={activePointId} />}
        {isReflex && <ReflexPulse point={activePoint} triggerKey={pressTrigger} busRef={busRef} />}
        {flowStops && <BloodFlow stops={flowStops} busRef={busRef} />}
      </ModelView>

      <ThemedView type="backgroundElement" style={styles.panel}>
        <SafeAreaView edges={['bottom']}>
          <View style={styles.panelBody}>
            <LayerBar layers={layers} onToggle={toggleLayer} hiddenCount={hidden.length} onShowAll={() => setHidden([])} />
            {selectedPartId && (
              <PartCard partId={selectedPartId} onHide={hidePart} onClose={() => setSelectedPartId(undefined)} />
            )}
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
                Tap any part to name it — 点击任意部位查看名称. Toggle layers above to peel the body.
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
