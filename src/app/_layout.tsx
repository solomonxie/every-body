import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { StyleSheet, useColorScheme } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

export default function RootLayout() {
  const colorScheme = useColorScheme();

  return (
    <GestureHandlerRootView style={styles.root}>
      <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
        <Stack>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="viewer/[id]" options={{ title: 'Viewer', headerBackTitle: 'Explore' }} />
          <Stack.Screen name="info/[id]" options={{ title: 'Info' }} />
          <Stack.Screen name="illustration/[id]" options={{ title: 'Illustration', headerBackTitle: 'Back' }} />
          <Stack.Screen name="reflex/[chart]" options={{ title: 'Reflex chart', headerBackTitle: 'Back' }} />
        </Stack>
      </ThemeProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
});
