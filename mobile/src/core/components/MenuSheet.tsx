import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useTranslation, type StringKey } from '@/core/i18n';
import { Layout, Radius, Spacing, Typography, useTheme } from '@/core/theme/SentraTheme';

import { Icon, type IconName } from './Icon';

export interface MenuItem {
  title: StringKey;
  icon: IconName;
  onPress: () => void;
}

/** A small action list presented from the bottom edge; tapping outside dismisses it. */
export function MenuSheet({ visible, items, onClose }: { visible: boolean; items: MenuItem[]; onClose: () => void }) {
  const { colors } = useTheme();
  const { t } = useTranslation();
  const insets = useSafeAreaInsets();
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable accessibilityRole="button" accessibilityLabel={t('card.photo.cancel')} style={styles.scrim} onPress={onClose} />
      <View
        accessibilityRole="menu"
        style={[styles.sheet, { backgroundColor: colors.surface, paddingBottom: insets.bottom + Spacing.small }]}
      >
        {items.map((item) => (
          <Pressable
            key={item.title}
            accessibilityRole="menuitem"
            onPress={() => {
              onClose();
              item.onPress();
            }}
            style={({ pressed }) => [styles.item, { opacity: pressed ? 0.6 : 1 }]}
          >
            <Icon name={item.icon} size={22} color={colors.primary} />
            <Text style={[Typography.body, { color: colors.ink }]}>{t(item.title)}</Text>
          </Pressable>
        ))}
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  scrim: { flex: 1, backgroundColor: 'rgba(0, 0, 0, 0.35)' },
  sheet: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    paddingTop: Spacing.small,
    borderTopLeftRadius: Radius.card * 2,
    borderTopRightRadius: Radius.card * 2,
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.medium,
    minHeight: Layout.buttonHeight,
    paddingHorizontal: Spacing.xLarge,
  },
});
