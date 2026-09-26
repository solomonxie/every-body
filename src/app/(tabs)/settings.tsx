import Constants from 'expo-constants';
import { ScrollView, StyleSheet, Switch, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Pill } from '@/components/viewer/pill';
import { Spacing } from '@/constants/theme';
import { useSettings, type NameMode } from '@/state/settings';

const NAME_OPTIONS: { id: NameMode; label: string }[] = [
  { id: 'en', label: 'English' },
  { id: 'zh', label: '中文' },
  { id: 'both', label: 'Both 双语' },
];

export default function SettingsScreen() {
  const { settings, update } = useSettings();

  return (
    <ThemedView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <ThemedText type="smallBold" themeColor="textSecondary">
          NAMES 名称
        </ThemedText>
        <View style={styles.row}>
          {NAME_OPTIONS.map((o) => (
            <Pill key={o.id} label={o.label} selected={settings.names === o.id} onPress={() => update({ names: o.id })} />
          ))}
        </View>

        <ThemedText type="smallBold" themeColor="textSecondary">
          VIEWER 3D 视图
        </ThemedText>
        <ThemedView type="backgroundElement" style={styles.card}>
          <View style={styles.line}>
            <ThemedText>Background 背景</ThemedText>
            <View style={styles.row}>
              <Pill label="Gray 灰" selected={settings.background === 'gray'} onPress={() => update({ background: 'gray' })} />
              <Pill label="White 白" selected={settings.background === 'white'} onPress={() => update({ background: 'white' })} />
            </View>
          </View>
          <View style={styles.line}>
            <ThemedText>Body 体型</ThemedText>
            <View style={styles.row}>
              <Pill label="Male 男" selected={settings.body === 'male'} onPress={() => update({ body: 'male' })} />
              <Pill label="Female 女" selected={settings.body === 'female'} onPress={() => update({ body: 'female' })} />
            </View>
          </View>
          <View style={styles.line}>
            <ThemedText>Auto-rotate on open 自动旋转</ThemedText>
            <Switch value={settings.autoRotate} onValueChange={(autoRotate) => update({ autoRotate })} />
          </View>
        </ThemedView>

        <ThemedText type="smallBold" themeColor="textSecondary">
          ABOUT 关于
        </ThemedText>
        <ThemedView type="backgroundElement" style={styles.card}>
          <ThemedText type="smallBold">Health disclaimer 健康声明</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            Body Atlas is for learning. It isn’t medical advice. Reflex and acupoint effects describe traditional
            practice, not proven treatment. In an emergency call 120 / 911.
          </ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            本应用仅供学习，不构成医疗建议。穴位与反射区功效为传统说法，并非经证实的疗法。紧急情况请拨打 120。
          </ThemedText>
        </ThemedView>
        <ThemedView type="backgroundElement" style={styles.card}>
          <ThemedText type="smallBold">Sources 资料来源</ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            Ear points: GB/T 13734-2008. Acupoints: WHO Standard Acupuncture Point Locations (2008). First aid: ILCOR /
            Red Cross. Each illustration lists its own sources. All drawings are schematic, built from simple geometry.
          </ThemedText>
        </ThemedView>
        <View style={styles.line}>
          <ThemedText type="small" themeColor="textSecondary">
            Version 版本
          </ThemedText>
          <ThemedText type="small" themeColor="textSecondary">
            {Constants.expoConfig?.version ?? '—'}
          </ThemedText>
        </View>
      </ScrollView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: Spacing.three,
    gap: Spacing.two,
    paddingBottom: Spacing.six,
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.two,
  },
  card: {
    borderRadius: Spacing.three,
    padding: Spacing.three,
    gap: Spacing.two,
  },
  line: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: Spacing.two,
  },
});
