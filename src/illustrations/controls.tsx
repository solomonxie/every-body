import { useEffect, useRef, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Slider from '@react-native-community/slider';

import { ThemedText } from '@/components/themed-text';
import { Spacing } from '@/constants/theme';

import type { Params, ScrubControl } from './types';

export function Scrubs({ scrubs, params, onChange }: { scrubs: ScrubControl[]; params: Params; onChange: (values: Params) => void }) {
  return (
    <View style={styles.scrubs}>
      {scrubs.map((scrub) => {
        const value = params[scrub.param] ?? scrub.min;
        const shown = scrub.digits === undefined ? `${Math.round(((value - scrub.min) / (scrub.max - scrub.min)) * 100)}%` : value.toFixed(scrub.digits);
        return (
          <View key={scrub.param}>
            <View style={styles.scrubHeader}>
              <ThemedText type="small">{scrub.label}</ThemedText>
              <ThemedText type="smallBold">
                {shown}
                {scrub.unit ? ` ${scrub.unit}` : ''}
              </ThemedText>
            </View>
            <Slider
              minimumValue={scrub.min}
              maximumValue={scrub.max}
              value={value}
              onValueChange={(v) => onChange({ [scrub.param]: v })}
            />
          </View>
        );
      })}
    </View>
  );
}

type RhythmProps = { minRate: number; maxRate: number; label?: string; onTap: (rate: number) => void };

const PAUSE_MS = 2000;

/** Big tap target; rate = average of the last few intervals, reset after a pause. */
export function Rhythm({ minRate, maxRate, label = 'PUSH 按压', onTap }: RhythmProps) {
  const [times, setTimes] = useState<number[]>([]);

  const tap = () => {
    const now = Date.now();
    const kept = times.length && now - times[times.length - 1] > PAUSE_MS ? [] : times;
    const recent = [...kept, now].slice(-6);
    const intervals = recent.slice(1).map((time, i) => time - recent[i]);
    const avg = intervals.length ? intervals.reduce((a, b) => a + b, 0) / intervals.length : 0;
    setTimes(recent);
    onTap(avg > 0 ? 60000 / avg : 0);
  };

  return (
    <View style={styles.rhythm}>
      <Pressable onPress={tap} style={({ pressed }) => [styles.pushButton, pressed && styles.pushPressed]}>
        <ThemedText style={styles.pushText}>{label}</ThemedText>
      </Pressable>
      {maxRate < 1000 && (
        <ThemedText type="small" themeColor="textSecondary">
          {`Aim for ${minRate}–${maxRate} per minute — about 2 taps a second.`}
        </ThemedText>
      )}
    </View>
  );
}

type HoldProps = { label: string; seconds: number; onChange: (holding: boolean, progress: number) => void };

const TICK_MS = 100;

/** Press and hold; progress = total held time / seconds. */
export function Hold({ label, seconds, onChange }: HoldProps) {
  const [holding, setHolding] = useState(false);
  const held = useRef(0);

  useEffect(() => {
    if (!holding) return;
    const timer = setInterval(() => {
      held.current += TICK_MS / 1000;
      onChange(true, Math.min(1, held.current / seconds));
    }, TICK_MS);
    return () => clearInterval(timer);
  }, [holding, seconds, onChange]);

  const setPressed = (pressed: boolean) => {
    setHolding(pressed);
    onChange(pressed, Math.min(1, held.current / seconds));
  };

  return (
    <View style={styles.rhythm}>
      <Pressable
        onPressIn={() => setPressed(true)}
        onPressOut={() => setPressed(false)}
        style={[styles.pushButton, holding && styles.pushPressed]}
      >
        <ThemedText style={styles.pushText}>{label}</ThemedText>
      </Pressable>
      <ThemedText type="small" themeColor="textSecondary">
        Press and keep holding 按住不放
      </ThemedText>
    </View>
  );
}

type CompareProps = { options: { label: string; value: number }[]; value: number; onChange: (value: number) => void };

export function Compare({ options, value, onChange }: CompareProps) {
  return (
    <View style={styles.compare}>
      {options.map((option) => {
        const selected = Math.abs(option.value - value) < 0.5;
        return (
          <Pressable key={option.label} onPress={() => onChange(option.value)} style={[styles.option, selected && styles.optionSelected]}>
            <ThemedText type="smallBold" style={selected && styles.optionSelectedText}>
              {option.label}
            </ThemedText>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  compare: {
    flexDirection: 'row',
    gap: Spacing.two,
  },
  option: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.two,
    borderRadius: 999,
    backgroundColor: 'rgba(128,128,128,0.15)',
  },
  optionSelected: {
    backgroundColor: '#6C4F9E',
  },
  optionSelectedText: {
    color: '#FFFFFF',
  },
  scrubs: {
    gap: Spacing.one,
  },
  scrubHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  rhythm: {
    alignItems: 'center',
    gap: Spacing.two,
  },
  pushButton: {
    width: 140,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#D8434B',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pushPressed: {
    backgroundColor: '#A82F36',
    transform: [{ scale: 0.95 }],
  },
  pushText: {
    color: '#FFFFFF',
    fontWeight: 'bold',
    fontSize: 18,
  },
});
