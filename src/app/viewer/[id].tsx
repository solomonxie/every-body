import { useRef, useState } from 'react';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, ScrollView, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Canvas } from '@react-three/fiber';
import Slider from '@react-native-community/slider';

import { ReflexPulse } from '@/components/canvas/reflex-pulse';
import { RotatingMesh } from '@/components/canvas/rotating-mesh';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { REFLEX_TRAVEL_MS } from '@/constants/reflex';
import { Spacing } from '@/constants/theme';
import { POINTS_BY_SYSTEM } from '@/data/system-points';
import type { BodyPoint } from '@/types/BodyPoint';
import { BODY_SYSTEMS } from '@/types/BodySystem';

const FLOW_LABEL = {
  blood: 'Blood circulation through these points (stub — animation not yet wired to the model).',
} as const;

// TODO: swap RotatingMesh for a real, licensed anatomy model once one is sourced.
export default function ViewerScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id) ?? BODY_SYSTEMS[0];
  const [layerOpacity, setLayerOpacity] = useState(1);
  const [activePointId, setActivePointId] = useState<string | undefined>();
  const [pressTrigger, setPressTrigger] = useState(0);
  const [effectVisible, setEffectVisible] = useState(false);
  const pressTriggerId = useRef(0);

  const systemPoints = POINTS_BY_SYSTEM[system.id];
  const activePoint = systemPoints?.points.find((point) => point.id === activePointId);
  const hasReflexTargets = systemPoints?.points.some((point) => point.target) ?? false;

  const handlePointPress = (point: BodyPoint) => {
    if (!point.target) {
      setActivePointId(point.id === activePointId ? undefined : point.id);
      setEffectVisible(false);
      return;
    }
    pressTriggerId.current += 1;
    const myTrigger = pressTriggerId.current;
    setActivePointId(point.id);
    setPressTrigger(myTrigger);
    setEffectVisible(false);
    setTimeout(() => {
      if (pressTriggerId.current === myTrigger) setEffectVisible(true);
    }, REFLEX_TRAVEL_MS);
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: system.name }} />
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <ThemedView style={styles.canvasWrapper}>
          <Canvas camera={{ position: [0, 0, 4] }}>
            <ambientLight intensity={0.6} />
            <directionalLight position={[3, 3, 3]} intensity={1} />
            <RotatingMesh color={system.color}>
              <ReflexPulse point={activePoint} triggerKey={pressTrigger} />
            </RotatingMesh>
          </Canvas>
        </ThemedView>

        <ThemedView type="backgroundElement" style={styles.controls}>
          <ThemedText type="small" themeColor="textSecondary">
            Peel layers (stub — not yet wired to the model)
          </ThemedText>
          <Slider
            minimumValue={0}
            maximumValue={1}
            value={layerOpacity}
            onValueChange={setLayerOpacity}
          />
        </ThemedView>

        {systemPoints && (
          <ThemedView type="backgroundElement" style={styles.controls}>
            {systemPoints.flow && (
              <ThemedText type="small" themeColor="textSecondary">
                {FLOW_LABEL[systemPoints.flow.kind]}
              </ThemedText>
            )}
            {hasReflexTargets && (
              <ThemedText type="small" themeColor="textSecondary">
                Press a point to apply pressure — watch the pulse travel to what it affects.
              </ThemedText>
            )}
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.pointChips}>
              {systemPoints.points.map((point) => (
                <Pressable key={point.id} onPress={() => handlePointPress(point)}>
                  <ThemedView
                    type={point.id === activePointId ? 'backgroundSelected' : 'background'}
                    style={styles.pointChip}
                  >
                    <ThemedText type="small">{point.name}</ThemedText>
                  </ThemedView>
                </Pressable>
              ))}
            </ScrollView>
            {activePoint && (
              <ThemedView style={styles.pointDetail}>
                <ThemedText type="smallBold">
                  {activePoint.name} · {activePoint.nameZh}
                </ThemedText>
                <ThemedText type="small" themeColor="textSecondary">
                  {activePoint.description}
                </ThemedText>
              </ThemedView>
            )}
            {activePoint?.target && effectVisible && (
              <ThemedView style={styles.pointDetail}>
                <ThemedText type="smallBold">
                  → {activePoint.target.name} · {activePoint.target.nameZh}
                </ThemedText>
                <ThemedText type="small" themeColor="textSecondary">
                  {activePoint.target.effect} {activePoint.target.effectZh}
                </ThemedText>
              </ThemedView>
            )}
          </ThemedView>
        )}

        <Pressable style={styles.infoButton} onPress={() => router.push(`/info/${system.id}`)}>
          <ThemedView type="backgroundElement" style={styles.infoButtonInner}>
            <ThemedText type="smallBold">View part info</ThemedText>
          </ThemedView>
        </Pressable>
      </SafeAreaView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    gap: Spacing.three,
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.three,
  },
  canvasWrapper: {
    flex: 1,
    borderRadius: Spacing.four,
    overflow: 'hidden',
  },
  controls: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.two,
  },
  pointChips: {
    gap: Spacing.two,
  },
  pointChip: {
    borderRadius: Spacing.two,
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.one,
  },
  pointDetail: {
    gap: Spacing.half,
  },
  infoButton: {
    marginBottom: Spacing.two,
  },
  infoButtonInner: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    alignItems: 'center',
  },
});
