import { useState } from 'react';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Canvas } from '@react-three/fiber';
import Slider from '@react-native-community/slider';

import { RotatingMesh } from '@/components/canvas/rotating-mesh';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { BODY_SYSTEMS } from '@/types/BodySystem';

// TODO: swap RotatingMesh for a real, licensed anatomy model once one is sourced.
export default function ViewerScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id) ?? BODY_SYSTEMS[0];
  const [layerOpacity, setLayerOpacity] = useState(1);

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: system.name }} />
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <ThemedView style={styles.canvasWrapper}>
          <Canvas camera={{ position: [0, 0, 4] }}>
            <ambientLight intensity={0.6} />
            <directionalLight position={[3, 3, 3]} intensity={1} />
            <RotatingMesh color={system.color} />
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
  infoButton: {
    marginBottom: Spacing.two,
  },
  infoButtonInner: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    alignItems: 'center',
  },
});
