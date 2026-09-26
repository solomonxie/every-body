import Svg, { Ellipse, G, Path, Rect, Text } from 'react-native-svg';

import { ZONE_GROUPS, type ChartFace, type ReflexChart, type ReflexZone, type Side } from '@/data/reflex-charts';

const SKIN = '#F5D7BF';
const SKIN_LINE = '#C9A58A';
const INK = '#2B2250';

type Props = {
  chart: ReflexChart;
  face: ChartFace;
  side: Side;
  selectedId?: string;
  showLabels: boolean;
  onSelect: (zone: ReflexZone) => void;
};

export function zonesFor(face: ChartFace, side: Side) {
  return face.zones.filter((zone) => !zone.side || zone.side === side);
}

function zoneLabel(zone: ReflexZone) {
  return zone.label ?? zone.nameZh.split('·')[0];
}

/** Hand or ear drawing with tappable colored zones; the other side is the drawing mirrored. */
export function ChartView({ chart, face, side, selectedId, showLabels, onSelect }: Props) {
  const mirrored = side !== face.drawnSide;
  const mirrorX = (x: number) => (mirrored ? chart.mirrorWidth - x : x);
  const zones = zonesFor(face, side);

  return (
    <Svg width="100%" height="100%" viewBox={chart.viewBox.join(' ')} preserveAspectRatio="xMidYMid meet">
      <G transform={mirrored ? `translate(${chart.mirrorWidth} 0) scale(-1 1)` : undefined}>
        {face.outline.map((shape, i) =>
          shape.kind === 'rect' ? (
            <Rect
              key={i}
              x={shape.x}
              y={shape.y}
              width={shape.w}
              height={shape.h}
              rx={shape.r}
              fill={SKIN}
              stroke={SKIN_LINE}
              strokeWidth={2}
              transform={shape.rot ? `rotate(${shape.rot} ${shape.ox} ${shape.oy})` : undefined}
            />
          ) : (
            <Path key={i} d={shape.d} fill={SKIN} stroke={SKIN_LINE} strokeWidth={2} />
          ),
        )}
        {face.bones.map((d, i) => (
          <Path key={`b${i}`} d={d} fill="none" stroke={SKIN_LINE} strokeWidth={1.2} strokeDasharray="4 4" />
        ))}
        {face.guides.map((d, i) => (
          <Path key={`g${i}`} d={d} fill="none" stroke={SKIN_LINE} strokeWidth={2} strokeLinecap="round" />
        ))}
        {zones.map((zone) => {
          const selected = zone.id === selectedId;
          const dimmed = selectedId !== undefined && !selected;
          return zone.shapes.map((shape, i) => (
            <Ellipse
              key={`${zone.id}-${i}`}
              cx={shape.cx}
              cy={shape.cy}
              rx={shape.rx}
              ry={shape.ry}
              transform={shape.rot ? `rotate(${shape.rot} ${shape.cx} ${shape.cy})` : undefined}
              fill={ZONE_GROUPS[zone.group].color}
              fillOpacity={selected ? 0.95 : dimmed ? 0.3 : 0.65}
              stroke={selected ? INK : '#FFFFFF'}
              strokeWidth={selected ? 2.5 : 1.2}
              onPress={() => onSelect(zone)}
            />
          ));
        })}
      </G>
      {showLabels &&
        zones.map((zone) => {
          const shape = zone.shapes[0];
          const below = zone.point || shape.rx < 10;
          return (
            <Text
              key={`t-${zone.id}`}
              x={mirrorX(shape.cx)}
              y={shape.cy + (below ? shape.ry + chart.labelSize : chart.labelSize / 3)}
              fontSize={chart.labelSize}
              fontWeight={zone.id === selectedId ? 'bold' : 'normal'}
              fill={INK}
              textAnchor="middle"
              onPress={() => onSelect(zone)}
            >
              {zoneLabel(zone)}
            </Text>
          );
        })}
    </Svg>
  );
}
