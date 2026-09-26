import { useRef, useState } from 'react';
import { router, Stack, useLocalSearchParams } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { createSceneBus } from '@/components/canvas/scene-bus';
import { SchematicBody } from '@/components/canvas/schematic-body';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { ModelView } from '@/components/viewer/model-view';
import { Spacing } from '@/constants/theme';
import { DEFAULT_LAYERS } from '@/data/body';
import { makeQuestions, quizPool } from '@/quiz';
import { useName } from '@/state/settings';
import { BODY_SYSTEMS } from '@/types/BodySystem';

const ROUNDS = 10;

export default function QuizScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const system = BODY_SYSTEMS.find((s) => s.id === id) ?? BODY_SYSTEMS[1];
  const [seed, setSeed] = useState(() => Date.now() % 100000);
  const questions = makeQuestions(quizPool(system.id), ROUNDS, seed);
  const [index, setIndex] = useState(0);
  const [picked, setPicked] = useState<string | undefined>();
  const [score, setScore] = useState(0);
  const busRef = useRef(createSceneBus());
  const name = useName();

  const done = index >= questions.length;
  const q = questions[Math.min(index, questions.length - 1)];
  const layers = DEFAULT_LAYERS[system.id] ?? ['skin', 'organs'];

  const choose = (optionName: string) => {
    if (picked) return;
    setPicked(optionName);
    if (optionName === q.answer.name) setScore(score + 1);
  };

  const next = () => {
    setPicked(undefined);
    setIndex(index + 1);
  };

  const restart = () => {
    setSeed(seed + 1);
    setIndex(0);
    setScore(0);
    setPicked(undefined);
  };

  return (
    <ThemedView style={styles.container}>
      <Stack.Screen options={{ title: `Quiz 测验 · ${system.name}` }} />
      <ModelView
        busRef={busRef}
        skinColor={system.color}
        skinOpacity={0.1}
        showOrgans={layers.includes('organs')}
        selectedId={done ? undefined : q.answer.partId}
      >
        <SchematicBody layers={layers} hidden={[]} selectedId={done ? undefined : q.answer.partId} />
      </ModelView>

      <ThemedView type="backgroundElement" style={styles.panel}>
        <SafeAreaView edges={['bottom']}>
          <View style={styles.body}>
            {done ? (
              <>
                <ThemedText type="subtitle">
                  {score} / {questions.length}
                </ThemedText>
                <ThemedText themeColor="textSecondary">
                  {score === questions.length ? 'Perfect! 全对！' : score >= questions.length * 0.7 ? 'Well done 不错！' : 'Keep exploring 继续加油'}
                </ThemedText>
                <View style={styles.row}>
                  <Button label="Again 再来" onPress={restart} primary />
                  <Button label="Back 返回" onPress={() => router.back()} />
                </View>
              </>
            ) : (
              <>
                <View style={styles.row}>
                  <ThemedText type="smallBold">What is the glowing part? 发光的是哪个部位？</ThemedText>
                  <ThemedText type="small" themeColor="textSecondary">
                    {index + 1}/{questions.length} · ✓ {score}
                  </ThemedText>
                </View>
                {q.options.map((option) => {
                  const correct = option.name === q.answer.name;
                  const state = !picked ? 'idle' : correct ? 'right' : option.name === picked ? 'wrong' : 'idle';
                  return (
                    <Pressable
                      key={option.name}
                      onPress={() => choose(option.name)}
                      style={[styles.option, state === 'right' && styles.right, state === 'wrong' && styles.wrong]}
                    >
                      <ThemedText style={state !== 'idle' && styles.optionText}>{name(option.name, option.nameZh)}</ThemedText>
                    </Pressable>
                  );
                })}
                {picked && <Button label={index + 1 === questions.length ? 'See score 查看得分' : 'Next 下一题 ›'} onPress={next} primary />}
              </>
            )}
          </View>
        </SafeAreaView>
      </ThemedView>
    </ThemedView>
  );
}

function Button({ label, onPress, primary }: { label: string; onPress: () => void; primary?: boolean }) {
  return (
    <Pressable onPress={onPress} style={[styles.button, primary && styles.primary]}>
      <ThemedText type="smallBold" style={primary && styles.primaryText}>
        {label}
      </ThemedText>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  panel: {
    borderTopLeftRadius: Spacing.four,
    borderTopRightRadius: Spacing.four,
  },
  body: {
    padding: Spacing.three,
    gap: Spacing.two,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: Spacing.two,
  },
  option: {
    borderRadius: Spacing.three,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two + 2,
    backgroundColor: 'rgba(128,128,128,0.12)',
  },
  right: {
    backgroundColor: '#2E9E5B',
  },
  wrong: {
    backgroundColor: '#D8434B',
  },
  optionText: {
    color: '#FFFFFF',
  },
  button: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: Spacing.two + 2,
    borderRadius: 999,
    backgroundColor: 'rgba(128,128,128,0.15)',
  },
  primary: {
    backgroundColor: '#6C4F9E',
  },
  primaryText: {
    color: '#FFFFFF',
  },
});
