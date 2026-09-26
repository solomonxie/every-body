import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

export type NameMode = 'en' | 'zh' | 'both';

export interface Settings {
  names: NameMode;
  background: 'gray' | 'white';
  autoRotate: boolean;
}

const DEFAULTS: Settings = { names: 'both', background: 'gray', autoRotate: true };
const KEY = 'settings.v1';

const SettingsContext = createContext<{ settings: Settings; update: (patch: Partial<Settings>) => void }>({
  settings: DEFAULTS,
  update: () => {},
});

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState(DEFAULTS);

  useEffect(() => {
    AsyncStorage.getItem(KEY).then((raw) => {
      if (raw) setSettings({ ...DEFAULTS, ...JSON.parse(raw) });
    });
  }, []);

  const update = (patch: Partial<Settings>) => {
    const next = { ...settings, ...patch };
    setSettings(next);
    AsyncStorage.setItem(KEY, JSON.stringify(next));
  };

  return <SettingsContext.Provider value={{ settings, update }}>{children}</SettingsContext.Provider>;
}

export const useSettings = () => useContext(SettingsContext);

/** "Femur · 股骨", "Femur" or "股骨" per the Names setting */
export function useName() {
  const { names } = useSettings().settings;
  return (en: string, zh: string) => (names === 'en' || !zh ? en : names === 'zh' ? zh : `${en} · ${zh}`);
}

/** keep only the lines the Names setting asks for */
export function useBilingual() {
  const { names } = useSettings().settings;
  return { showEn: names !== 'zh', showZh: names !== 'en' };
}
