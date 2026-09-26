import { Pressable, StyleSheet, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { ORGAN_NAMES, type OrganId } from '@/data/anatomy';
import { LAYERS, SCHEMATIC_PARTS } from '@/data/body';

export function partLabel(partId: string) {
  const part = SCHEMATIC_PARTS.find((p) => p.id === partId);
  if (part) {
    const layer = LAYERS.find((l) => l.id === part.layer);
    return { name: part.name, nameZh: part.nameZh, layer: layer ? `${layer.labelZh} ${layer.label}` : '' };
  }
  const organ = ORGAN_NAMES[partId as OrganId];
  return organ && { name: organ[0], nameZh: organ[1], layer: '器官 Organs' };
}

type Props = { partId: string; onHide: (partId: string) => void; onClose: () => void };

/** Name of the tapped part, with Hide. */
export function PartCard({ partId, onHide, onClose }: Props) {
  const label = partLabel(partId);
  if (!label) return null;
  return (
    <ThemedView style={styles.card}>
      <View style={styles.text}>
        <ThemedText type="smallBold">
          {label.name} · {label.nameZh}
        </ThemedText>
        <ThemedText type="small" themeColor="textSecondary">
          {label.layer}
        </ThemedText>
      </View>
      <Pressable onPress={() => onHide(partId)} hitSlop={8}>
        <ThemedText type="smallBold">Hide 隐藏</ThemedText>
      </Pressable>
      <Pressable onPress={onClose} hitSlop={8}>
        <ThemedText type="smallBold">✕</ThemedText>
      </Pressable>
    </ThemedView>
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
});
