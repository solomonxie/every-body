import { Stack, useLocalSearchParams } from 'expo-router';
import { StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { BODY_SYSTEMS } from '@/types/BodySystem';

export default function InfoScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id);

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: system?.name ?? 'Info' }} />
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <ThemedView type="backgroundElement" style={[styles.swatch, { backgroundColor: system?.color }]} />
        <ThemedText type="subtitle">{system?.name ?? 'Unknown part'}</ThemedText>
        <ThemedText themeColor="textSecondary">
          Description placeholder — part-level detail (origin, function, related structures) goes
          here once real anatomy content is sourced.
        </ThemedText>
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
  swatch: {
    height: 96,
    borderRadius: Spacing.three,
  },
});
