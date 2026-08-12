import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when an admin edge function returns a non-2xx response. Carries the
/// server's `error` message and `code` so screens can show something useful.
class AdminApiException implements Exception {
  AdminApiException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

/// Thin wrapper over the admin-gated edge functions + the read paths the
/// console needs. All writes go through edge functions (service role,
/// server-side authorization); reads go straight through RLS.
class AdminApi {
  AdminApi(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> _invoke(
    String fn,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke(fn, body: body);
      final data = res.data;
      if (data is Map && data['ok'] == true) {
        return Map<String, dynamic>.from(data);
      }
      // Some functions return a bare object; treat 2xx as success.
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'ok': true};
    } on FunctionException catch (e) {
      final details = e.details;
      String message = 'Request failed';
      String? code;
      if (details is Map) {
        message = (details['error'] ?? message).toString();
        code = details['code']?.toString();
      }
      throw AdminApiException(message, code: code, status: e.status);
    }
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Am I an admin? Reads the caller's own admin_users row (RLS self-read).
  Future<bool> amIAdmin() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await _client
        .from('admin_users')
        .select('user_id')
        .eq('user_id', uid);
    return (rows as List).isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> listTournaments() async {
    final rows = await _client
        .from('tournaments')
        .select(
          'id, name, game_type, format, status, is_official, '
          'start_time, min_participants, max_participants, current_participants, '
          'entry_fee_coins, entry_fee_gems, prize_pool',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ── Recurrence templates (#253) ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listTemplates() async {
    final res = await _invoke('admin-manage-template', {'action': 'list'});
    return List<Map<String, dynamic>>.from(res['templates'] as List? ?? []);
  }

  Future<Map<String, dynamic>> createTemplate(
      Map<String, dynamic> template) async {
    final res = await _invoke(
        'admin-manage-template', {'action': 'create', 'template': template});
    return Map<String, dynamic>.from(res['template'] as Map);
  }

  Future<Map<String, dynamic>> updateTemplate(
      String id, Map<String, dynamic> patch) async {
    final res = await _invoke(
        'admin-manage-template', {'action': 'update', 'id': id, 'patch': patch});
    return Map<String, dynamic>.from(res['template'] as Map);
  }

  Future<Map<String, dynamic>> getEconomyConfig() async {
    final row =
        await _client.from('economy_config').select().eq('id', 1).single();
    return Map<String, dynamic>.from(row);
  }

  // ── Writes (admin edge functions) ────────────────────────────────────────

  Future<Map<String, dynamic>> createTournament(Map<String, dynamic> body) =>
      _invoke('admin-create-tournament', body);

  Future<void> cancelTournament(String id) =>
      _invoke('admin-cancel-tournament', {'tournament_id': id});

  Future<Map<String, dynamic>> forceStartTournament(String id) =>
      _invoke('admin-force-start-tournament', {'tournament_id': id});

  Future<Map<String, dynamic>> updateEconomyConfig(
          Map<String, dynamic> patch) =>
      _invoke('admin-update-economy-config', patch);
}
