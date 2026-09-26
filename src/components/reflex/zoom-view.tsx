import { useMemo, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

const MAX_SCALE = 4;

/** Pinch to zoom, drag to pan (one-finger drags need ≥ 10 px, so taps still reach the zones). */
export function ZoomView({ children }: { children: ReactNode }) {
  const scale = useSharedValue(1);
  const savedScale = useSharedValue(1);
  const x = useSharedValue(0);
  const y = useSharedValue(0);
  const savedX = useSharedValue(0);
  const savedY = useSharedValue(0);

  const gesture = useMemo(() => {
    const pinch = Gesture.Pinch()
      .onUpdate((e) => {
        scale.set(Math.max(1, Math.min(MAX_SCALE, savedScale.get() * e.scale)));
      })
      .onEnd(() => {
        savedScale.set(scale.get());
      });
    const pan = Gesture.Pan()
      .minDistance(10)
      .onUpdate((e) => {
        x.set(savedX.get() + e.translationX);
        y.set(savedY.get() + e.translationY);
      })
      .onEnd(() => {
        savedX.set(x.get());
        savedY.set(y.get());
      });
    return Gesture.Simultaneous(pinch, pan);
  }, [scale, savedScale, x, y, savedX, savedY]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateX: x.get() }, { translateY: y.get() }, { scale: scale.get() }],
  }));

  const reset = () => {
    scale.set(withTiming(1));
    x.set(withTiming(0));
    y.set(withTiming(0));
    savedScale.set(1);
    savedX.set(0);
    savedY.set(0);
  };

  return (
    <View style={styles.clip}>
      <GestureDetector gesture={gesture}>
        <Animated.View style={[styles.fill, style]}>{children}</Animated.View>
      </GestureDetector>
      <Pressable accessibilityLabel="Reset zoom" onPress={reset} style={styles.reset} hitSlop={8}>
        <Text style={styles.resetText}>⟲ 1×</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  clip: {
    flex: 1,
    overflow: 'hidden',
  },
  fill: {
    flex: 1,
  },
  reset: {
    position: 'absolute',
    right: 12,
    bottom: 8,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 4,
    backgroundColor: 'rgba(43,34,80,0.7)',
  },
  resetText: {
    color: '#FFFFFF',
    fontSize: 12,
  },
});
