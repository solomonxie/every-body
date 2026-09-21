import { StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';

export default function SettingsScreen() {
  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <ThemedText type="subtitle">Settings</ThemedText>
        <ThemedView type="backgroundElement" style={styles.row}>
          <ThemedText>Units</ThemedText>
          <ThemedText themeColor="textSecondary">Metric</ThemedText>
        </ThemedView>
        <ThemedView type="backgroundElement" style={styles.row}>
          <ThemedText>Appearance</ThemedText>
          <ThemedText themeColor="textSecondary">System</ThemedText>
        </ThemedView>
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
    gap: Spacing.two,
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.four,
  },
  row: {
    padding: Spacing.three,
    borderRadius: Spacing.three,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
});
