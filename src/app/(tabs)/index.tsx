import { router } from 'expo-router';
import { FlatList, Pressable, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { BODY_SYSTEMS } from '@/types/BodySystem';

export default function ExploreScreen() {
  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <ThemedText type="small" themeColor="textSecondary" style={styles.intro}>
          Pick a body system to explore layer by layer.
        </ThemedText>
        <FlatList
          data={BODY_SYSTEMS}
          numColumns={2}
          keyExtractor={(item) => item.id}
          columnWrapperStyle={styles.row}
          contentContainerStyle={styles.list}
          renderItem={({ item }) => (
            <Pressable style={styles.cardWrapper} onPress={() => router.push(`/viewer/${item.id}`)}>
              <ThemedView type="backgroundElement" style={styles.card}>
                <ThemedView style={[styles.swatch, { backgroundColor: item.color }]} />
                <ThemedText type="smallBold">{item.name}</ThemedText>
              </ThemedView>
            </Pressable>
          )}
        />
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
    paddingHorizontal: Spacing.four,
    paddingTop: Spacing.three,
  },
  intro: {
    paddingBottom: Spacing.three,
  },
  list: {
    gap: Spacing.three,
    paddingBottom: Spacing.four,
  },
  row: {
    gap: Spacing.three,
  },
  cardWrapper: {
    flex: 1,
  },
  card: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.two,
  },
  swatch: {
    height: 64,
    borderRadius: Spacing.two,
  },
});
