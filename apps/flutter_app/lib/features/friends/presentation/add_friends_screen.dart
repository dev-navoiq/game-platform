import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../social/widgets/profile_peek_sheet.dart';
import '../data/discovery_repository.dart';

/// Find players: username / friend-code search, your own shareable code,
/// and "played with recently" suggestions. Guests see the registration
/// upsell — the social graph is registered-only.
class AddFriendsScreen extends ConsumerStatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  ConsumerState<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends ConsumerState<AddFriendsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Add Friends'),
        body: profile == null
            ? const Center(child: CircularProgressIndicator())
            : profile.isGuest
                ? _GuestUpsell()
                : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      children: [
        _MyCodeCard(),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autocorrect: false,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textOnFelt),
          decoration: InputDecoration(
            hintText: 'Search username or friend code',
            hintStyle: GoogleFonts.inter(color: AppColors.textFeltMuted),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textFeltMuted),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_query.length >= 3)
          _SearchResults(query: _query)
        else ...[
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Type at least 3 characters',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textFeltMuted),
              ),
            ),
          _SuggestedSection(),
        ],
      ],
    );
  }
}

class _MyCodeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final code = profile?.friendCodeDisplay;
    if (code == null) return const SizedBox.shrink();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My friend code',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 20, color: AppColors.accent),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Friend code copied')),
              );
            },
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share, size: 20, color: AppColors.accent),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    "Add me on Gathr! My friend code is $code — enter it under Friends → Add Friends.",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;

  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(playerSearchProvider(query));
    return results.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search failed — try again',
          style: GoogleFonts.inter(color: AppColors.textFeltMuted),
        ),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No players found for "$query"',
              style: GoogleFonts.inter(color: AppColors.textFeltMuted),
            ),
          );
        }
        return Column(
          children: [
            for (final p in players)
              _PlayerTile(player: p, key: ValueKey(p.id)),
          ],
        );
      },
    );
  }
}

class _SuggestedSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(recentPlayersProvider);
    final players = suggested.valueOrNull ?? const <DiscoveredPlayer>[];
    final addable = players.where((p) => !p.isFriend).toList();
    if (addable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Played with recently',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnFelt,
            ),
          ),
        ),
        for (final p in addable) _PlayerTile(player: p, key: ValueKey(p.id)),
      ],
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  final DiscoveredPlayer player;

  const _PlayerTile({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: InkWell(
          onTap: () => ProfilePeekSheet.show(context, player),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accent.withOpacity(0.15),
                backgroundImage: player.avatarUrl != null
                    ? NetworkImage(player.avatarUrl!)
                    : null,
                child: player.avatarUrl == null
                    ? Text(
                        player.name.isNotEmpty
                            ? player.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      player.gamesTogether > 0
                          ? '@${player.username} · ${player.gamesTogether} game${player.gamesTogether == 1 ? '' : 's'} together'
                          : '@${player.username} · Level ${player.level}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (player.isFriend)
                const Icon(Icons.check_circle,
                    size: 20, color: AppColors.success)
              else if (player.requestPending)
                const Icon(Icons.hourglass_top,
                    size: 20, color: AppColors.textMuted)
              else
                const Icon(Icons.person_add_alt,
                    size: 20, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestUpsell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_add, size: 40, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(
                'Friends are for members',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a free account to add friends, chat, and keep your coins and level forever.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => context.push(AppRoutes.register),
                child: const Text('Create free account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
