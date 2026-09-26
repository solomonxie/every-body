import { useState } from 'react';
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

type RhythmProps = { minRate: number; maxRate: number; onTap: (rate: number) => void };

const PAUSE_MS = 2000;

/** Big tap target; rate = average of the last few intervals, reset after a pause. */
export function Rhythm({ minRate, maxRate, onTap }: RhythmProps) {
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
        <ThemedText style={styles.pushText}>PUSH 按压</ThemedText>
      </Pressable>
      <ThemedText type="small" themeColor="textSecondary">
        {`Aim for ${minRate}–${maxRate} per minute — about 2 taps a second.`}
      </ThemedText>
    </View>
  );
}

const styles = StyleSheet.create({
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
