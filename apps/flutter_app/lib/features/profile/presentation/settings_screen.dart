import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_registry.dart';
import '../../../core/di/feature_flag_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/skin_theme_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/feature_flags.dart';
import '../../../core/services/update_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final musicEnabled = ref.watch(musicEnabledProvider);
    final cardSkin = ref.watch(cardSkinThemeProvider);
    final roomSkin = ref.watch(roomSkinThemeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          SwitchListTile(
            title: const Text('Sound Effects'),
            value: soundEnabled,
            onChanged: (value) {
              ref.read(soundEnabledProvider.notifier).state = value;
            },
          ),
          SwitchListTile(
            title: const Text('Music'),
            value: musicEnabled,
            onChanged: (value) {
              ref.read(musicEnabledProvider.notifier).state = value;
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Card Skin'),
            subtitle: Text(cardSkin.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCardSkinPicker(context, ref),
          ),
          ListTile(
            title: const Text('Room Theme'),
            subtitle: Text(roomSkin.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRoomSkinPicker(context, ref),
          ),
          const Divider(),
          const ListTile(
            title: Text('Preferred Social Mode'),
            subtitle: Text('Full — Chat + Voice + Emotes'),
          ),
          ListTile(
            title: const Text('Notification Preferences'),
            subtitle: const Text('Manage alerts, quiet hours'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          const Divider(),
          // App version & update status
          _UpdateStatusTile(),
          // Developer section (debug builds only)
          if (kDebugMode) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                'Developer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            const _FeatureFlagsList(),
          ],
        ],
      ),
    );
  }

  void _showCardSkinPicker(BuildContext context, WidgetRef ref) {
    final registry = AssetRegistry.instance;
    final currentId = ref.read(selectedCardSkinProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Card Skin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...registry.allCardSkins.map((skin) => RadioListTile<String>(
                  title: Text(skin.displayName),
                  subtitle: skin.isFree
                      ? const Text('Free')
                      : Text(skin.priceCoins > 0
                          ? '${skin.priceCoins} coins'
                          : '${skin.priceGems} gems'),
                  value: skin.id,
                  groupValue: currentId,
                  onChanged: skin.isFree || skin.id == currentId
                      ? (value) {
                          if (value != null) {
                            ref.read(selectedCardSkinProvider.notifier).state =
                                value;
                          }
                          Navigator.pop(context);
                        }
                      : null,
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRoomSkinPicker(BuildContext context, WidgetRef ref) {
    final registry = AssetRegistry.instance;
    final currentId = ref.read(selectedRoomSkinProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Room Theme',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...registry.allRoomSkins.map((skin) => RadioListTile<String>(
                  title: Text(skin.displayName),
                  subtitle: skin.isFree
                      ? const Text('Free')
                      : Text(skin.priceCoins > 0
                          ? '${skin.priceCoins} coins'
                          : '${skin.priceGems} gems'),
                  value: skin.id,
                  groupValue: currentId,
                  onChanged: skin.isFree || skin.id == currentId
                      ? (value) {
                          if (value != null) {
                            ref.read(selectedRoomSkinProvider.notifier).state =
                                value;
                          }
                          Navigator.pop(context);
                        }
                      : null,
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _UpdateStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(updateStatusProvider);
    final updateService = ref.read(updateServiceProvider);

    return statusAsync.when(
      data: (status) => ListTile(
        leading: Icon(
          status == UpdateStatus.upToDate
              ? Icons.check_circle_outline
              : status == UpdateStatus.updateAvailable
                  ? Icons.system_update
                  : Icons.info_outline,
          color: status == UpdateStatus.upToDate ? Colors.green : null,
        ),
        title: const Text('App Version'),
        subtitle: Text(updateService.statusMessage),
        trailing: status == UpdateStatus.updateAvailable
            ? TextButton(
                onPressed: () => updateService.downloadAndInstall(),
                child: const Text('Update'),
              )
            : null,
      ),
      loading: () => const ListTile(
        title: Text('App Version'),
        subtitle: Text('Checking…'),
      ),
      error: (_, __) => const ListTile(
        title: Text('App Version'),
        subtitle: Text('Could not check for updates'),
      ),
    );
  }
}

class _FeatureFlagsList extends StatelessWidget {
  const _FeatureFlagsList();

  @override
  Widget build(BuildContext context) {
    final ff = FeatureFlags.instance;
    final allFlags = ff.getAllFlags();

    if (allFlags.isEmpty) {
      return const ListTile(
        title: Text('No feature flags loaded'),
        dense: true,
      );
    }

    return Column(
      children: allFlags.entries.map((entry) {
        return SwitchListTile(
          title: Text(
            entry.key,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          ),
          value: entry.value,
          dense: true,
          onChanged: (value) {
            ff.setOverride(entry.key, value);
            // Force rebuild
            (context as Element).markNeedsBuild();
          },
        );
      }).toList(),
    );
  }
}
