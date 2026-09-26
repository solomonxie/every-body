import { useEffect, useMemo, useRef, useState } from 'react';
import { Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { GestureDetector } from 'react-native-gesture-handler';
import { SafeAreaView } from 'react-native-safe-area-context';
import Svg from 'react-native-svg';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';
import { Rhythm, Scrubs } from '@/illustrations/controls';
import { createDragGesture, type PointHandler } from '@/illustrations/drag-gesture';
import { findIllustration, ILLUSTRATIONS } from '@/illustrations';
import { SCENE_H, SCENE_W, type Scenario } from '@/illustrations/types';
import { usePlayer } from '@/illustrations/use-player';

export default function IllustrationScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const scenario = findIllustration(id) ?? ILLUSTRATIONS[0];
  return <Player key={scenario.id} scenario={scenario} />;
}

function Player({ scenario }: { scenario: Scenario }) {
  const { step, stepIndex, goTo, params, t, setParams, easeParams, pulse, solved } = usePlayer(scenario);
  const [size, setSize] = useState({ w: 1, h: 1 });
  const dragRef = useRef<PointHandler | null>(null);
  const { Scene } = scenario;
  const isLast = stepIndex === scenario.steps.length - 1;
  const dragging = step.try?.mode === 'drag' && scenario.onDrag;

  useEffect(() => {
    dragRef.current = dragging
      ? (x, y) => {
          const scale = Math.min(size.w / SCENE_W, size.h / SCENE_H);
          const point = { x: (x - (size.w - SCENE_W * scale) / 2) / scale, y: (y - (size.h - SCENE_H * scale) / 2) / scale };
          setParams(scenario.onDrag!(point, params));
        }
      : null;
  });

  // the handler ref is read on touch only, never during render
  // eslint-disable-next-line react-hooks/refs
  const gesture = useMemo(() => createDragGesture(dragRef), []);

  const tapCompression = (rate: number) => {
    setParams({ taps: (params.taps ?? 0) + 1, rate });
    pulse('press');
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: `${scenario.title.zh} ${scenario.title.en}` }} />

      <GestureDetector gesture={gesture}>
        <View
          style={styles.stage}
          collapsable={false}
          onLayout={(e) => setSize({ w: e.nativeEvent.layout.width, h: e.nativeEvent.layout.height })}
        >
          <Svg width="100%" height="100%" viewBox={`0 0 ${SCENE_W} ${SCENE_H}`} preserveAspectRatio="xMidYMid meet">
            <Scene params={params} t={t} />
          </Svg>
        </View>
      </GestureDetector>

      {scenario.warning && (
        <ThemedText type="small" style={styles.warning}>
          ⚠ {scenario.warning.en} {scenario.warning.zh}
        </ThemedText>
      )}

      <ThemedView type="backgroundElement" style={styles.panel}>
        <SafeAreaView edges={['bottom']}>
          <View style={styles.panelBody}>
            <View style={styles.dots}>
              {scenario.steps.map((s, i) => (
                <Pressable key={i} onPress={() => goTo(i)} hitSlop={6}>
                  <ThemedText style={[styles.dot, i === stepIndex && styles.dotActive]}>{s.kind === 'try' ? '◆' : '●'}</ThemedText>
                </Pressable>
              ))}
              <ThemedText type="small" themeColor="textSecondary">
                {step.kind === 'try' ? '  Try it 试一试' : '  Watch 观看'}
              </ThemedText>
            </View>

            <ThemedText type="smallBold">{step.caption.en}</ThemedText>
            <ThemedText type="small">{step.caption.zh}</ThemedText>

            {step.try?.mode === 'scrub' && <Scrubs scrubs={step.try.scrubs} params={params} onChange={easeParams} />}
            {step.try?.mode === 'rhythm' && (
              <Rhythm minRate={step.try.minRate} maxRate={step.try.maxRate} onTap={tapCompression} />
            )}
            {step.try?.mode === 'drag' && !solved && (
              <ThemedText type="small" themeColor="textSecondary">
                ☝ Drag on the picture 在图上拖动
              </ThemedText>
            )}
            {step.try && solved && (
              <ThemedText type="smallBold" style={styles.ok}>
                ✓ {step.try.ok.en} {step.try.ok.zh}
              </ThemedText>
            )}

            <View style={styles.nav}>
              <NavButton label="‹ Prev" disabled={stepIndex === 0} onPress={() => goTo(stepIndex - 1)} />
              {step.try?.demo && !solved && <NavButton label="Show me" onPress={() => easeParams(step.try!.demo!)} />}
              <NavButton
                label={isLast ? '↺ Replay' : step.kind === 'try' && !solved ? 'Skip ›' : 'Next ›'}
                primary={solved}
                onPress={() => goTo(isLast ? 0 : stepIndex + 1)}
              />
            </View>
          </View>
        </SafeAreaView>
      </ThemedView>
    </ThemedView>
  );
}

function NavButton({ label, onPress, disabled, primary }: { label: string; onPress: () => void; disabled?: boolean; primary?: boolean }) {
  return (
    <Pressable onPress={onPress} disabled={disabled} style={[styles.navButton, primary && styles.navPrimary, disabled && styles.navDisabled]}>
      <ThemedText type="smallBold" style={primary && styles.navPrimaryText}>
        {label}
      </ThemedText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  stage: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  warning: {
    color: '#B5462E',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.one,
  },
  panel: {
    borderTopLeftRadius: Spacing.four,
    borderTopRightRadius: Spacing.four,
  },
  panelBody: {
    padding: Spacing.three,
    gap: Spacing.two,
  },
  dots: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
  },
  dot: {
    fontSize: 14,
    opacity: 0.35,
  },
  dotActive: {
    opacity: 1,
  },
  ok: {
    color: '#2E9E5B',
  },
  nav: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: Spacing.two,
    paddingTop: Spacing.one,
  },
  navButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.two,
    borderRadius: 999,
    backgroundColor: 'rgba(128,128,128,0.15)',
  },
  navPrimary: {
    backgroundColor: '#6C4F9E',
  },
  navPrimaryText: {
    color: '#FFFFFF',
  },
  navDisabled: {
    opacity: 0.35,
  },
});
