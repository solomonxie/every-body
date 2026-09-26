import { ScrollView, StyleSheet } from 'react-native';

import { Spacing } from '@/constants/theme';
import { LAYERS, type LayerId } from '@/data/body';

import { Pill } from './pill';

type Props = { layers: LayerId[]; onToggle: (layer: LayerId) => void; hiddenCount: number; onShowAll: () => void };

/** Peel the body: one pill per layer, plus "Show all" when parts are hidden. */
export function LayerBar({ layers, onToggle, hiddenCount, onShowAll }: Props) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
      {LAYERS.map((layer) => (
        <Pill
          key={layer.id}
          label={`${layer.labelZh} ${layer.label}`}
          selected={layers.includes(layer.id)}
          onPress={() => onToggle(layer.id)}
        />
      ))}
      {hiddenCount > 0 && <Pill label={`Show all (${hiddenCount} hidden)`} selected={false} onPress={onShowAll} />}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: {
    gap: Spacing.two,
    paddingHorizontal: Spacing.three,
    paddingBottom: Spacing.two,
  },
});
