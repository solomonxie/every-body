import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Canvas } from '@react-three/fiber';
import { GestureDetector } from 'react-native-gesture-handler';

import { BodyScene } from '@/components/canvas/body-scene';
import { FOCUS, type SceneBusRef } from '@/components/canvas/scene-bus';
import type { Pick, Picker } from '@/components/canvas/tap-picker';

import { createOrbitGesture, resetView } from './orbit-gesture';

const BACKGROUNDS = { gray: '#DADCE2', white: '#FFFFFF' } as const;

type Props = {
  busRef: SceneBusRef;
  skinColor: string;
  onPick?: (pick: Pick) => void;
  skinOpacity?: number;
  showOrgans?: boolean;
  selectedId?: string;
  /** small inset: no rails, no hint */
  compact?: boolean;
  /** extra scene content that rotates with the body */
  children?: ReactNode;
};

/** Full-bleed 3D body: drag to spin, pinch to zoom, tap a point, double-tap to reset. */
export function ModelView({ busRef, skinColor, onPick, skinOpacity, showOrgans, selectedId, compact = false, children }: Props) {
  const pickerRef = useRef<Picker | null>(null);
  const [background, setBackground] = useState<keyof typeof BACKGROUNDS>('gray');
  const [hintVisible, setHintVisible] = useState(!compact);

  const onPickRef = useRef(onPick);
  useEffect(() => {
    onPickRef.current = onPick;
  }, [onPick]);

  const reset = () => resetView(busRef.current);

  const gesture = useMemo(
    // gesture callbacks read the refs on touch events only, never during render
    // eslint-disable-next-line react-hooks/refs
    () => createOrbitGesture({ busRef, pickerRef, onPickRef, onFirstTouch: () => setHintVisible(false) }),
    [busRef],
  );

  return (
    <View style={styles.container}>
      <GestureDetector gesture={gesture}>
        <View style={[styles.canvas, { backgroundColor: BACKGROUNDS[background] }]} collapsable={false}>
          <View style={styles.canvas} pointerEvents="none">
            <Canvas camera={{ position: [0, 0, FOCUS.all.distance], fov: 40 }}>
              <BodyScene
                busRef={busRef}
                skinColor={skinColor}
                background={BACKGROUNDS[background]}
                skinOpacity={skinOpacity}
                showOrgans={showOrgans}
                selectedId={selectedId}
                pickerRef={pickerRef}
              >
                {children}
              </BodyScene>
            </Canvas>
          </View>
        </View>
      </GestureDetector>

      {!compact && (
        <View style={styles.rail} pointerEvents="box-none">
          <RailButton label="Reset view" glyph="⌂" onPress={reset} />
          <RailButton
            label={background === 'gray' ? 'White background' : 'Gray background'}
            glyph="◐"
            onPress={() => setBackground(background === 'gray' ? 'white' : 'gray')}
          />
        </View>
      )}

      {hintVisible && (
        <View style={styles.hint} pointerEvents="none">
          <Text style={styles.hintText}>Drag to spin · pinch to zoom · tap a point</Text>
        </View>
      )}
    </View>
  );
}

function RailButton({ label, glyph, onPress }: { label: string; glyph: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [styles.railButton, pressed && styles.railButtonPressed]}
    >
      <Text style={styles.railGlyph}>{glyph}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  canvas: {
    flex: 1,
  },
  rail: {
    position: 'absolute',
    top: 12,
    right: 12,
    gap: 10,
  },
  railButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255,255,255,0.75)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  railButtonPressed: {
    backgroundColor: 'rgba(255,255,255,0.95)',
  },
  railGlyph: {
    fontSize: 20,
    color: '#2B2250',
  },
  hint: {
    position: 'absolute',
    bottom: 14,
    alignSelf: 'center',
    backgroundColor: 'rgba(43,34,80,0.85)',
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  hintText: {
    color: '#FFFFFF',
    fontSize: 13,
  },
});
