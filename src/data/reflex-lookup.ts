import type { Href } from 'expo-router';

import type { OrganId } from '@/data/anatomy';
import { REFLEX_CHARTS } from '@/data/reflex-charts';

export interface ZoneLink {
  key: string;
  label: string;
  href: Href;
}

/** every chart zone said to act on an organ — the reverse of zone → organs */
export function zonesForOrgan(organId: string): ZoneLink[] {
  const out: ZoneLink[] = [];
  for (const chart of Object.values(REFLEX_CHARTS)) {
    for (const face of chart.faces) {
      for (const zone of face.zones) {
        if (!zone.organIds.includes(organId as OrganId)) continue;
        out.push({
          key: `${chart.id}-${zone.id}`,
          label: `${chart.titleZh.replace('反射区', '').replace('穴', '')}·${zone.nameZh}`,
          href: { pathname: '/reflex/[chart]', params: { chart: chart.id, face: face.id, zone: zone.id, side: zone.side ?? 'right' } },
        });
      }
    }
  }
  return out;
}
