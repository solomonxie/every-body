import { ScrollView, StyleSheet } from 'react-native';

import { Spacing } from '@/constants/theme';
import { LAYERS, type LayerId } from '@/data/body';

import { Pill } from './pill';

type Props = {
  layers: LayerId[];
  onToggle: (layer: LayerId) => void;
  changedCount: number;
  onShowAll: () => void;
  canUndo: boolean;
  onUndo: () => void;
};

/** Peel the body: one pill per layer, plus Undo and "Show all" once parts are changed. */
export function LayerBar({ layers, onToggle, changedCount, onShowAll, canUndo, onUndo }: Props) {
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
      {canUndo && <Pill label="↶ Undo" selected={false} onPress={onUndo} />}
      {LAYERS.map((layer) => (
        <Pill
          key={layer.id}
          label={`${layer.labelZh} ${layer.label}`}
          selected={layers.includes(layer.id)}
          onPress={() => onToggle(layer.id)}
        />
      ))}
      {changedCount > 0 && <Pill label={`Reset parts (${changedCount})`} selected={false} onPress={onShowAll} />}
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
