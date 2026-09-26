import { router } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { organName, type OrganId } from '@/data/anatomy';
import { LAYERS, SCHEMATIC_PARTS } from '@/data/body';
import { zonesForOrgan } from '@/data/reflex-lookup';
import { useName, useSettings } from '@/state/settings';

import type { PartAction } from './part-state';

export function partLabel(partId: string, female = false) {
  const part = SCHEMATIC_PARTS.find((p) => p.id === partId);
  if (part) {
    const layer = LAYERS.find((l) => l.id === part.layer);
    return {
      name: part.name,
      nameZh: part.nameZh,
      layer: layer ? `${layer.labelZh} ${layer.label}` : '',
    };
  }
  const organ = organName(partId as OrganId, female);
  return organ && { name: organ[0], nameZh: organ[1], layer: '器官 Organs' };
}

type Props = {
  partId: string;
  onAction: (action: PartAction, partId: string) => void;
  faded: boolean;
  isolated: boolean;
  onClose: () => void;
};

/** Name of the tapped part, with Hide / Fade / Isolate. */
export function PartCard({ partId, onAction, faded, isolated, onClose }: Props) {
  const female = useSettings().settings.body === 'female';
  const label = partLabel(partId, female);
  const name = useName();
  const zones = zonesForOrgan(partId);
  if (!label) return null;
  return (
    <View>
      <ThemedView style={styles.card}>
        <View style={styles.text}>
          <ThemedText type="smallBold">{name(label.name, label.nameZh)}</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            {label.layer}
          </ThemedText>
        </View>
        <View style={styles.actions}>
          <Pressable onPress={() => onAction('hide', partId)} hitSlop={6}>
            <ThemedText type="smallBold">Hide 隐藏</ThemedText>
          </Pressable>
          <Pressable onPress={() => onAction('fade', partId)} hitSlop={6}>
            <ThemedText type="smallBold">{faded ? 'Unfade' : 'Fade 淡化'}</ThemedText>
          </Pressable>
          <Pressable onPress={() => onAction('isolate', partId)} hitSlop={6}>
            <ThemedText type="smallBold">{isolated ? 'Show rest' : 'Isolate 单独'}</ThemedText>
          </Pressable>
        </View>
        <Pressable onPress={onClose} hitSlop={8}>
          <ThemedText type="smallBold">✕</ThemedText>
        </Pressable>
      </ThemedView>
      {zones.length > 0 && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.zones}>
          <ThemedText type="small" themeColor="textSecondary">
            Reflex zones 反射区 ({zones.length}):
          </ThemedText>
          {zones.map((zone) => (
            <Pressable key={zone.key} onPress={() => router.push(zone.href)}>
              <ThemedView style={styles.zone}>
                <ThemedText type="small">{zone.label} ›</ThemedText>
              </ThemedView>
            </Pressable>
          ))}
        </ScrollView>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.three,
    marginHorizontal: Spacing.three,
    marginBottom: Spacing.two,
    borderRadius: Spacing.three,
    padding: Spacing.three,
  },
  text: {
    flex: 1,
  },
  zones: {
    gap: Spacing.two,
    alignItems: 'center',
    paddingHorizontal: Spacing.three,
    paddingBottom: Spacing.two,
  },
  zone: {
    borderRadius: 999,
    paddingHorizontal: Spacing.two + 2,
    paddingVertical: Spacing.one,
  },
  actions: {
    gap: Spacing.one,
    alignItems: 'flex-end',
  },
});
