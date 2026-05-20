import 'dart:async';

import 'package:flutter/foundation.dart';

enum UpdateStatus {
  unknown,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  error,
}

/// Manages Shorebird OTA updates.
///
/// In debug mode the service skips update checks automatically.
/// In release builds it checks on startup and exposes a stream for the UI.
class UpdateService {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  final _statusController = StreamController<UpdateStatus>.broadcast();
  UpdateStatus _currentStatus = UpdateStatus.unknown;

  Stream<UpdateStatus> get statusStream => _statusController.stream;
  UpdateStatus get currentStatus => _currentStatus;

  String? _currentPatchNumber;
  String? _availablePatchNumber;
  String? _errorMessage;

  String? get currentPatchNumber => _currentPatchNumber;
  String? get availablePatchNumber => _availablePatchNumber;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    // Skip update checks in debug builds
    if (kDebugMode) {
      _setStatus(UpdateStatus.upToDate);
      return;
    }

    await _checkForUpdate();
  }

  /// Manually trigger an update check.
  Future<void> checkForUpdate() async {
    if (_currentStatus == UpdateStatus.checking ||
        _currentStatus == UpdateStatus.downloading) {
      return; // Already in progress
    }
    await _checkForUpdate();
  }

  /// Download and stage the update for install on next restart.
  Future<bool> downloadAndInstall() async {
    if (_currentStatus != UpdateStatus.updateAvailable) {
      return false;
    }

    _setStatus(UpdateStatus.downloading);

    try {
      // Shorebird integration point:
      // final updater = ShorebirdUpdater();
      // await updater.update();

      // Simulated — replace with actual Shorebird download
      await Future<void>.delayed(const Duration(seconds: 2));

      _setStatus(UpdateStatus.readyToInstall);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(UpdateStatus.error);
      return false;
    }
  }

  String get statusMessage {
    switch (_currentStatus) {
      case UpdateStatus.unknown:
      case UpdateStatus.checking:
        return 'Checking for updates…';
      case UpdateStatus.upToDate:
        return 'App is up to date';
      case UpdateStatus.updateAvailable:
        return 'Update available';
      case UpdateStatus.downloading:
        return 'Downloading update…';
      case UpdateStatus.readyToInstall:
        return 'Restart to apply update';
      case UpdateStatus.error:
        return 'Update check failed';
    }
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Future<void> _checkForUpdate() async {
    _setStatus(UpdateStatus.checking);

    try {
      // Shorebird integration point:
      // final updater = ShorebirdUpdater();
      // final status = await updater.checkForUpdate();
      // final hasUpdate = status == UpdateAvailability.available;

      // Replace with actual Shorebird check
      _setStatus(UpdateStatus.upToDate);
    } catch (e) {
      _errorMessage = e.toString();
      _setStatus(UpdateStatus.error);
    }
  }

  void _setStatus(UpdateStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    await _statusController.close();
  }
}
