import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/audio_service.dart';

// Supabase client (raw)
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  try {
    final supabase = ref.watch(supabaseProvider);
    return supabase.auth.onAuthStateChange
        .map((event) => event.session?.user);
  } catch (_) {
    // Supabase not initialized (e.g. in tests) — return empty stream
    return const Stream.empty();
  }
});

// Current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Tracks whether the user has logged in this session (set by login screen)
final isLoggedInProvider = StateProvider<bool>((ref) {
  // Also check if Supabase auth reports a user
  final authUser = ref.watch(authStateProvider).valueOrNull;
  return authUser != null;
});

// Theme mode
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
  }

  void toggle() {
    setThemeMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

// Sound settings
final soundEnabledProvider = StateProvider<bool>((ref) => true);
final musicEnabledProvider = StateProvider<bool>((ref) => true);

// Audio service
final audioProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});

// Selected skins
final selectedCardSkinProvider = StateProvider<String>((ref) => 'default');
final selectedRoomSkinProvider = StateProvider<String>((ref) => 'default');

// Connection status
final connectionStatusProvider = StreamProvider<bool>((ref) {
  return Stream.value(true); // Placeholder — real connectivity monitoring later
});
