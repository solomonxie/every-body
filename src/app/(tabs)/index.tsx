import { router, type Href } from 'expo-router';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { POINTS_BY_SYSTEM } from '@/data/system-points';
import { ILLUSTRATION_GROUPS, ILLUSTRATIONS } from '@/illustrations';
import { BODY_SYSTEMS } from '@/types/BodySystem';

type Tile = { id: string; name: string; color: string; href: Href; interactive: boolean };

const [reflexMap, ...otherSystems] = BODY_SYSTEMS.map<Tile>((system) => ({
  ...system,
  href: `/viewer/${system.id}`,
  interactive: Boolean(POINTS_BY_SYSTEM[system.id]),
}));

const TILES: Tile[] = [
  reflexMap,
  { id: 'hand-chart', name: 'Hand Chart 手部反射区', color: '#E8A87C', href: '/reflex/hand', interactive: true },
  { id: 'foot-chart', name: 'Foot Chart 足底反射区', color: '#C9A06A', href: '/reflex/foot', interactive: true },
  { id: 'ear-chart', name: 'Ear Points 耳穴', color: '#D98BA8', href: '/reflex/ear', interactive: true },
  ...otherSystems,
];

export default function ExploreScreen() {
  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['left', 'right', 'bottom']}>
        <Pressable onPress={() => router.push('/search')}>
          <ThemedView type="backgroundElement" style={styles.search}>
            <ThemedText themeColor="textSecondary">🔍 Search parts, points, zones, topics 搜索</ThemedText>
          </ThemedView>
        </Pressable>
        <ThemedText type="small" themeColor="textSecondary" style={styles.intro}>
          Pick a system or chart. ▶ tiles are interactive — press points, change the heart rate.
        </ThemedText>
        <FlatList
          data={TILES}
          numColumns={3}
          keyExtractor={(item) => item.id}
          columnWrapperStyle={styles.row}
          contentContainerStyle={styles.list}
          ListFooterComponent={IllustrationsSection}
          renderItem={({ item }) => (
            <Pressable style={styles.cardWrapper} onPress={() => router.push(item.href)}>
              <ThemedView type="backgroundElement" style={styles.card}>
                <ThemedView style={[styles.swatch, { backgroundColor: item.color }]}>
                  {item.interactive && <ThemedText style={styles.badge}>▶</ThemedText>}
                </ThemedView>
                <ThemedText type="smallBold" numberOfLines={2}>
                  {item.name}
                </ThemedText>
              </ThemedView>
            </Pressable>
          )}
        />
      </SafeAreaView>
    </ThemedView>
  );
}

function IllustrationsSection() {
  return (
    <View style={styles.section}>
      <ThemedText type="smallBold" themeColor="textSecondary">
        ILLUSTRATIONS · 图解 — watch, then try
      </ThemedText>
      {ILLUSTRATION_GROUPS.map((group) => (
        <ThemedView key={group.id} type="backgroundElement" style={styles.group}>
          <ThemedText type="smallBold" style={{ color: group.color }}>
            {group.title.en} · {group.title.zh}
          </ThemedText>
          {ILLUSTRATIONS.filter((s) => s.group === group.id).map((scenario) => (
            <Pressable key={scenario.id} onPress={() => router.push(`/illustration/${scenario.id}`)} style={styles.topic}>
              <ThemedText>
                {scenario.title.zh} {scenario.title.en}
              </ThemedText>
              <ThemedText themeColor="textSecondary">
                {scenario.steps.length} steps ›
              </ThemedText>
            </Pressable>
          ))}
        </ThemedView>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  search: {
    borderRadius: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two + 2,
    marginBottom: Spacing.two,
  },
  section: {
    gap: Spacing.two,
    paddingTop: Spacing.three,
  },
  group: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.one,
  },
  topic: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: Spacing.two,
  },
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
    gap: Spacing.two,
    paddingBottom: Spacing.four,
  },
  row: {
    gap: Spacing.two,
  },
  cardWrapper: {
    flex: 1,
  },
  card: {
    flex: 1,
    borderRadius: Spacing.three,
    padding: Spacing.two,
    gap: Spacing.two,
  },
  swatch: {
    aspectRatio: 1,
    borderRadius: Spacing.two,
    alignItems: 'flex-end',
    padding: Spacing.one,
  },
  badge: {
    color: '#FFFFFF',
    fontSize: 14,
  },
});
