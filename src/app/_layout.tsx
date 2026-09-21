import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { useColorScheme } from 'react-native';

export default function RootLayout() {
  const colorScheme = useColorScheme();

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <Stack>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="viewer/[id]" options={{ title: 'Viewer' }} />
        <Stack.Screen name="info/[id]" options={{ title: 'Info' }} />
      </Stack>
    </ThemeProvider>
  );
}
