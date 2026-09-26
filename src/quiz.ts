import { ORGAN_NAMES, type OrganId } from '@/data/anatomy';
import { DEFAULT_LAYERS, SCHEMATIC_PARTS, type LayerId } from '@/data/body';

export interface QuizItem {
  /** a representative part to highlight */
  partId: string;
  name: string;
  nameZh: string;
}

const base = (s: string) => s.replace(/ \((L|R)\)$/, '').replace(/^[左右]/, '');

/** one entry per anatomical name (left/right collapsed), from the system's layers */
export function quizPool(systemId: string): QuizItem[] {
  const layers: LayerId[] = (DEFAULT_LAYERS[systemId] ?? ['organs']).filter((l) => l !== 'skin');
  const seen = new Set<string>();
  const items: QuizItem[] = [];
  for (const part of SCHEMATIC_PARTS) {
    if (!layers.includes(part.layer)) continue;
    const name = base(part.name).replace(/^(C|T|L)\d+ vertebra$/, 'Vertebra').replace(/^Rib \d+$/, 'Rib');
    const nameZh = base(part.nameZh).replace(/^第\d+(颈椎|胸椎|腰椎)$/, '椎骨').replace(/^第\d+肋$/, '肋骨');
    if (seen.has(name)) continue;
    seen.add(name);
    items.push({ partId: part.id, name, nameZh });
  }
  if (layers.includes('organs')) {
    for (const [id, [name, nameZh]] of Object.entries(ORGAN_NAMES) as [OrganId, [string, string]][]) {
      const n = base(name.replace(/^(Left|Right) /, '').replace(/^\w/, (c) => c.toUpperCase()));
      if (seen.has(n)) continue;
      seen.add(n);
      items.push({ partId: id, name: n, nameZh: base(nameZh) });
    }
  }
  return items;
}

const shuffle = <T,>(xs: T[], rand: () => number) => {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

/** small seeded PRNG so a round is stable across re-renders */
export function mulberry32(seed: number) {
  let t = seed >>> 0;
  return () => {
    t = (t + 0x6d2b79f5) >>> 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

export function makeQuestions(pool: QuizItem[], count: number, seed: number) {
  const rand = mulberry32(seed);
  return shuffle(pool, rand)
    .slice(0, Math.min(count, pool.length))
    .map((answer) => ({
      answer,
      options: shuffle([answer, ...shuffle(pool.filter((p) => p.name !== answer.name), rand).slice(0, 3)], rand),
    }));
}
