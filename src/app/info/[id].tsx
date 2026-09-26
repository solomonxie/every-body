import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { SYSTEM_INFO } from '@/data/system-info';
import { quizPool } from '@/quiz';
import { useBilingual, useName } from '@/state/settings';
import { BODY_SYSTEMS } from '@/types/BodySystem';

export default function InfoScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id);
  const info = id ? SYSTEM_INFO[id] : undefined;
  const { showEn, showZh } = useBilingual();
  const name = useName();
  const parts = id && id !== 'acupoint-reflex-map' ? quizPool(id) : [];

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: system?.name ?? 'Info' }} />
      <ScrollView contentContainerStyle={styles.content}>
        <ThemedView style={[styles.swatch, { backgroundColor: system?.color }]} />
        {!info ? (
          <ThemedText themeColor="textSecondary">No details yet. 暂无详细信息。</ThemedText>
        ) : (
          <>
            {showEn && <ThemedText>{info.summary}</ThemedText>}
            {showZh && <ThemedText themeColor={showEn ? 'textSecondary' : 'text'}>{info.summaryZh}</ThemedText>}

            <ThemedView type="backgroundElement" style={styles.card}>
              {info.facts.map(([en, zh]) => (
                <ThemedText key={en} type="small">
                  • {name(en, zh).replace(' · ', '\n  ')}
                </ThemedText>
              ))}
            </ThemedView>

            {info.links?.map((link) => (
              <Pressable key={link.label} onPress={() => router.push(link.href)}>
                <ThemedText type="smallBold" style={styles.link}>
                  {link.label}
                </ThemedText>
              </Pressable>
            ))}

            {parts.length > 0 && (
              <>
                <ThemedText type="smallBold" themeColor="textSecondary">
                  PARTS 部位 · {parts.length}
                </ThemedText>
                <View style={styles.chips}>
                  {parts.map((part) => (
                    <Pressable
                      key={part.partId}
                      onPress={() => router.push({ pathname: '/viewer/[id]', params: { id: id!, part: part.partId } })}
                    >
                      <ThemedView type="backgroundElement" style={styles.chip}>
                        <ThemedText type="small">{name(part.name, part.nameZh)}</ThemedText>
                      </ThemedView>
                    </Pressable>
                  ))}
                </View>
              </>
            )}
          </>
        )}
      </ScrollView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: Spacing.three,
    gap: Spacing.three,
    paddingBottom: Spacing.six,
  },
  swatch: {
    height: 8,
    borderRadius: 4,
  },
  card: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.two,
  },
  link: {
    color: '#6C4F9E',
  },
  chips: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.two,
  },
  chip: {
    borderRadius: 999,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
  },
});
