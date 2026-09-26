import type { ImageSourcePropType } from 'react-native';

// Rendered from the schematic body by scripts/thumbnails/render.sh.
export const TILE_IMAGES: Record<string, ImageSourcePropType> = {
  skeletal: require('@/assets/images/tiles/skeletal.png'),
  muscular: require('@/assets/images/tiles/muscular.png'),
  circulatory: require('@/assets/images/tiles/circulatory.png'),
  nervous: require('@/assets/images/tiles/nervous.png'),
  organs: require('@/assets/images/tiles/organs.png'),
  digestive: require('@/assets/images/tiles/digestive.png'),
  'acupoint-reflex-map': require('@/assets/images/tiles/acupoint-reflex-map.png'),
};
