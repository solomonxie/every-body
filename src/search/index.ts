import type { Href } from 'expo-router';

import { ORGAN_NAMES, type OrganId } from '@/data/anatomy';
import { SCHEMATIC_PARTS, type LayerId } from '@/data/body';
import { REFLEX_CHARTS } from '@/data/reflex-charts';
import { POINTS_BY_SYSTEM } from '@/data/system-points';
import { ILLUSTRATIONS } from '@/illustrations';
import { BODY_SYSTEMS } from '@/types/BodySystem';

export type ResultKind = 'system' | 'illustration' | 'zone' | 'point' | 'part';

export interface SearchEntry {
  kind: ResultKind;
  key: string;
  name: string;
  nameZh: string;
  detail: string;
  href: Href;
  /** lower-cased haystack */
  text: string;
}

export const KIND_TITLES: Record<ResultKind, string> = {
  system: 'SYSTEMS 系统',
  illustration: 'ILLUSTRATIONS 图解',
  zone: 'REFLEX CHART ZONES 反射区',
  point: 'POINTS 穴位',
  part: 'BODY PARTS 部位',
};

const LAYER_SYSTEM: Record<LayerId, string> = {
  skin: 'organs',
  muscular: 'muscular',
  skeletal: 'skeletal',
  circulatory: 'circulatory',
  nervous: 'nervous',
  organs: 'organs',
};

const entry = (e: Omit<SearchEntry, 'text'>, ...extra: string[]): SearchEntry => ({
  ...e,
  text: [e.name, e.nameZh, e.detail, ...extra].join(' ').toLowerCase(),
});

function build(): SearchEntry[] {
  const out: SearchEntry[] = [];
  for (const system of BODY_SYSTEMS) {
    out.push(entry({ kind: 'system', key: `s-${system.id}`, name: system.name, nameZh: '', detail: 'System', href: `/viewer/${system.id}` }));
  }
  for (const s of ILLUSTRATIONS) {
    out.push(
      entry(
        { kind: 'illustration', key: `i-${s.id}`, name: s.title.en, nameZh: s.title.zh, detail: `${s.steps.length} steps`, href: `/illustration/${s.id}` },
        ...s.steps.map((step) => `${step.caption.en} ${step.caption.zh}`),
      ),
    );
  }
  for (const chart of Object.values(REFLEX_CHARTS)) {
    for (const face of chart.faces) {
      for (const zone of face.zones) {
        out.push(
          entry(
            {
              kind: 'zone',
              key: `z-${chart.id}-${zone.id}`,
              name: zone.name,
              nameZh: zone.nameZh,
              detail: `${chart.titleZh} · ${face.labelZh}${zone.side ? (zone.side === 'left' ? ' · 左' : ' · 右') : ''}`,
              href: { pathname: '/reflex/[chart]', params: { chart: chart.id, face: face.id, zone: zone.id, side: zone.side ?? 'right' } },
            },
            zone.effect,
            zone.effectZh,
          ),
        );
      }
    }
  }
  for (const [systemId, { points }] of Object.entries(POINTS_BY_SYSTEM)) {
    for (const point of points) {
      out.push(
        entry(
          {
            kind: 'point',
            key: `p-${systemId}-${point.id}`,
            name: point.name,
            nameZh: point.nameZh,
            detail: point.description,
            href: { pathname: '/viewer/[id]', params: { id: systemId, point: point.id } },
          },
          point.target?.name ?? '',
          point.target?.nameZh ?? '',
        ),
      );
    }
  }
  for (const part of SCHEMATIC_PARTS) {
    out.push(
      entry({
        kind: 'part',
        key: `b-${part.id}`,
        name: part.name,
        nameZh: part.nameZh,
        detail: part.layer,
        href: { pathname: '/viewer/[id]', params: { id: LAYER_SYSTEM[part.layer], part: part.id } },
      }),
    );
  }
  for (const [id, names] of Object.entries(ORGAN_NAMES) as [OrganId, [string, string]][]) {
    out.push(
      entry({
        kind: 'part',
        key: `o-${id}`,
        name: names[0],
        nameZh: names[1],
        detail: 'organ',
        href: { pathname: '/viewer/[id]', params: { id: 'organs', part: id } },
      }),
    );
  }
  return out;
}

const INDEX = build();

const ORDER: ResultKind[] = ['system', 'illustration', 'zone', 'point', 'part'];

/** Every term must appear (EN or 中文); name matches rank first. */
export function search(query: string) {
  const terms = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
  if (terms.length === 0) return [];
  const hits = INDEX.filter((e) => terms.every((term) => e.text.includes(term)));
  const nameHit = (e: SearchEntry) => terms.some((term) => `${e.name} ${e.nameZh}`.toLowerCase().includes(term));
  return ORDER.map((kind) => ({
    kind,
    title: KIND_TITLES[kind],
    data: hits.filter((e) => e.kind === kind).sort((a, b) => Number(nameHit(b)) - Number(nameHit(a))).slice(0, 30),
  })).filter((section) => section.data.length > 0);
}
