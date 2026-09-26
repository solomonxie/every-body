import { useState } from 'react';
import { router, Stack } from 'expo-router';
import { Pressable, SectionList, StyleSheet, TextInput, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { search } from '@/search';

const SUGGESTIONS = ['肾', 'heart', '合谷', 'femur', '血压', 'CPR', '耳', 'stroke'];

export default function SearchScreen() {
  const [query, setQuery] = useState('');
  const theme = useTheme();
  const sections = search(query);

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: 'Search 搜索' }} />
      <View style={styles.bar}>
        <TextInput
          autoFocus
          value={query}
          onChangeText={setQuery}
          placeholder="Search parts, points, zones, topics 搜索"
          placeholderTextColor={theme.textSecondary}
          clearButtonMode="while-editing"
          autoCorrect={false}
          style={[styles.input, { color: theme.text, backgroundColor: theme.backgroundElement }]}
        />
      </View>

      {query.trim() === '' ? (
        <View style={styles.empty}>
          <ThemedText type="small" themeColor="textSecondary">
            Try 试试：
          </ThemedText>
          <View style={styles.suggestions}>
            {SUGGESTIONS.map((s) => (
              <Pressable key={s} onPress={() => setQuery(s)} style={[styles.suggestion, { backgroundColor: theme.backgroundElement }]}>
                <ThemedText type="small">{s}</ThemedText>
              </Pressable>
            ))}
          </View>
        </View>
      ) : sections.length === 0 ? (
        <View style={styles.empty}>
          <ThemedText>No matches for “{query}”.</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            Try the English or Chinese name. 试试中文或英文名称。
          </ThemedText>
        </View>
      ) : (
        <SectionList
          sections={sections}
          keyExtractor={(item) => item.key}
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={styles.list}
          renderSectionHeader={({ section }) => (
            <ThemedText type="smallBold" themeColor="textSecondary" style={styles.header}>
              {section.title} · {section.data.length}
            </ThemedText>
          )}
          renderItem={({ item }) => (
            <Pressable onPress={() => router.push(item.href)} style={styles.row}>
              <View style={styles.rowText}>
                <ThemedText numberOfLines={1}>
                  {item.nameZh ? `${item.nameZh} · ${item.name}` : item.name}
                </ThemedText>
                <ThemedText type="small" themeColor="textSecondary" numberOfLines={1}>
                  {item.detail}
                </ThemedText>
              </View>
              <ThemedText themeColor="textSecondary">›</ThemedText>
            </Pressable>
          )}
        />
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  bar: {
    padding: Spacing.three,
  },
  input: {
    borderRadius: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two + 2,
    fontSize: 16,
  },
  empty: {
    paddingHorizontal: Spacing.three,
    gap: Spacing.two,
  },
  suggestions: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.two,
  },
  suggestion: {
    borderRadius: 999,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
  },
  list: {
    paddingBottom: Spacing.six,
  },
  header: {
    paddingHorizontal: Spacing.three,
    paddingTop: Spacing.three,
    paddingBottom: Spacing.one,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    gap: Spacing.two,
  },
  rowText: {
    flex: 1,
  },
});
