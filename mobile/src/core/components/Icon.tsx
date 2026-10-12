import { Ionicons, MaterialCommunityIcons } from '@expo/vector-icons';

const glyphs = {
  football: 'football',
  yes: 'checkmark-circle',
  maybe: 'help-circle',
  no: 'close-circle',
  waitlist: 'time',
  offline: 'cloud-offline-outline',
  undo: 'arrow-undo',
  calendar: 'calendar-outline',
  location: 'location-outline',
  forward: 'arrow-forward',
  refresh: 'refresh',
  trash: 'trash',
  hourglass: 'hourglass-outline',
  person: 'person',
  warning: 'warning-outline',
  menu: 'ellipsis-horizontal-circle',
  groups: 'people-outline',
  add: 'add',
  profile: 'person-circle-outline',
  settings: 'settings-outline',
  checkmark: 'checkmark',
  circle: 'ellipse-outline',
  photos: 'images-outline',
  adjust: 'options-outline',
  reset: 'arrow-undo-outline',
  cards: 'albums-outline',
  clock: 'time-outline',
  close: 'close',
} as const satisfies Record<string, keyof typeof Ionicons.glyphMap>;

export type IconName = keyof typeof glyphs | 'pitch';

/** Icons are decorative: the accessible name always comes from the surrounding control or label. */
export function Icon({ name, size = 20, color }: { name: IconName; size?: number; color: string }) {
  const hidden = { accessible: false, importantForAccessibility: 'no', accessibilityElementsHidden: true } as const;
  if (name === 'pitch') {
    return <MaterialCommunityIcons name="soccer-field" size={size} color={color} {...hidden} />;
  }
  return <Ionicons name={glyphs[name]} size={size} color={color} {...hidden} />;
}
