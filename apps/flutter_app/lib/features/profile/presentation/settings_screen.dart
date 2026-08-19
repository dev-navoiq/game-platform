import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/asset_registry.dart';
import '../../../core/di/feature_flag_providers.dart';
import '../../../core/di/locale_provider.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/skin_theme_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/feature_flags.dart';
import '../../../core/services/update_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../friends/data/discovery_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final musicEnabled = ref.watch(musicEnabledProvider);
    final cardSkin = ref.watch(cardSkinThemeProvider);
    final roomSkin = ref.watch(roomSkinThemeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(locale == null
                ? l10n.languageSystemDefault
                : localeDisplayName(locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(l10n.darkMode),
            value: themeMode == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          SwitchListTile(
            title: Text(l10n.soundEffects),
            value: soundEnabled,
            onChanged: (value) {
              ref.read(soundEnabledProvider.notifier).state = value;
            },
          ),
          SwitchListTile(
            title: Text(l10n.music),
            value: musicEnabled,
            onChanged: (value) {
              ref.read(musicEnabledProvider.notifier).state = value;
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.cardSkin),
            subtitle: Text(cardSkin.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCardSkinPicker(context, ref),
          ),
          ListTile(
            title: Text(l10n.roomTheme),
            subtitle: Text(roomSkin.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRoomSkinPicker(context, ref),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.preferredSocialMode),
            subtitle: Text(l10n.socialModeFullDescription),
          ),
          ListTile(
            title: Text(l10n.notificationPreferences),
            subtitle: Text(l10n.notificationPreferencesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          const _DiscoverableTile(),
          const Divider(),
          // App version & update status
          _UpdateStatusTile(),

          // Danger zone — account deletion (App Store 5.1.1(v), #270).
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.red),
            title: const Text('Delete account',
                style: TextStyle(color: Colors.red)),
            subtitle:
                const Text('Permanently erase your account and data'),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
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
            ListTile(
              title: const Text('Ad Gallery'),
              subtitle: const Text('Preview house creatives & switch ad mode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.devAds),
            ),
            const _FeatureFlagsList(),
          ],
        ],
      ),
    );
  }

  /// Two-step destructive confirmation: explain the loss, require typing
  /// DELETE, then call the delete-account edge fn and sign out (#270).
  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Delete account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently erases your account: coins, gems, game '
                'history, friends, and progress. It cannot be undone.\n\n'
                'App Store / Play subscriptions must be cancelled separately '
                'in your store account.\n\n'
                'Type DELETE to confirm:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: controller.text.trim() == 'DELETE'
                  ? () async {
                      Navigator.of(dialogContext).pop();
                      await _deleteAccount(context, ref);
                    }
                  : null,
              child: const Text('Delete forever'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseProvider);
    try {
      await supabase.functions.invoke('delete-account', body: {});
      // Server already destroyed the auth user; clear local session state.
      await supabase.auth.signOut();
      if (context.mounted) context.go(AppRoutes.login);
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = (details is Map ? details['error'] : null) ??
          'Deletion failed — try again.';
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$msg')));
      }
    } catch (_) {
      // Auth session may already be invalid post-delete; treat as success.
      await supabase.auth.signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(localeProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.language,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            RadioListTile<String>(
              title: Text(l10n.languageSystemDefault),
              value: '',
              groupValue: current?.languageCode ?? '',
              onChanged: (_) {
                ref.read(localeProvider.notifier).setLocale(null);
                Navigator.pop(context);
              },
            ),
            ...supportedAppLocales.map((locale) => RadioListTile<String>(
                  title: Text(localeDisplayName(locale)),
                  value: locale.languageCode,
                  groupValue: current?.languageCode ?? '',
                  onChanged: (_) {
                    ref.read(localeProvider.notifier).setLocale(locale);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCardSkinPicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final registry = AssetRegistry.instance;
    final currentId = ref.read(selectedCardSkinProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.cardSkin,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...registry.allCardSkins.map((skin) => RadioListTile<String>(
                  title: Text(skin.displayName),
                  subtitle: skin.isFree
                      ? Text(l10n.free)
                      : Text(skin.priceCoins > 0
                          ? l10n.priceCoins(skin.priceCoins)
                          : l10n.priceGems(skin.priceGems)),
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
    final l10n = AppLocalizations.of(context);
    final registry = AssetRegistry.instance;
    final currentId = ref.read(selectedRoomSkinProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.roomTheme,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...registry.allRoomSkins.map((skin) => RadioListTile<String>(
                  title: Text(skin.displayName),
                  subtitle: skin.isFree
                      ? Text(l10n.free)
                      : Text(skin.priceCoins > 0
                          ? l10n.priceCoins(skin.priceCoins)
                          : l10n.priceGems(skin.priceGems)),
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

/// Search-privacy opt-out. Only meaningful for registered users (guests
/// never appear in search); hidden for guests. Friend-code lookups still
/// resolve when off — sharing the code is consent.
class _DiscoverableTile extends ConsumerWidget {
  const _DiscoverableTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null || profile.isGuest) return const SizedBox.shrink();

    return SwitchListTile(
      title: const Text('Discoverable in search'),
      subtitle: const Text(
          'Off: players can only add you with your friend code'),
      value: profile.discoverable,
      onChanged: (value) async {
        try {
          await ref
              .read(discoveryRepositoryProvider)
              .setDiscoverable(value);
          ref.invalidate(userProfileProvider);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Couldn't save — check your connection")),
            );
          }
        }
      },
    );
  }
}

class _UpdateStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
        title: Text(l10n.appVersion),
        subtitle: Text(updateService.statusMessage),
        trailing: status == UpdateStatus.updateAvailable
            ? TextButton(
                onPressed: () => updateService.downloadAndInstall(),
                child: Text(l10n.update),
              )
            : null,
      ),
      loading: () => ListTile(
        title: Text(l10n.appVersion),
        subtitle: Text(l10n.checking),
      ),
      error: (_, __) => ListTile(
        title: Text(l10n.appVersion),
        subtitle: Text(l10n.couldNotCheckForUpdates),
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
