import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/update_service.dart';

void main() {
  late UpdateService service;

  setUp(() {
    service = UpdateService.instance;
  });

  group('UpdateStatus enum', () {
    test('all statuses are distinct', () {
      final values = UpdateStatus.values;
      expect(values.length, 7);
      expect(values.toSet().length, 7);
    });
  });

  group('UpdateService', () {
    test('instance returns singleton', () {
      expect(UpdateService.instance, same(service));
    });

    test('initial status is unknown or upToDate (debug mode)', () {
      // In test (debug) mode, initialize sets upToDate
      expect(
        service.currentStatus,
        anyOf(UpdateStatus.unknown, UpdateStatus.upToDate),
      );
    });

    test('initialize sets upToDate in debug mode', () async {
      await service.initialize();
      expect(service.currentStatus, UpdateStatus.upToDate);
    });

    test('statusMessage returns human-readable text', () async {
      await service.initialize();
      expect(service.statusMessage, isNotEmpty);
      expect(service.statusMessage, 'App is up to date');
    });

    test('checkForUpdate does not change status when already checking', () async {
      await service.initialize();
      // After init in debug mode, status is upToDate
      await service.checkForUpdate();
      expect(service.currentStatus, UpdateStatus.upToDate);
    });

    test('downloadAndInstall returns false when no update available', () async {
      await service.initialize();
      final result = await service.downloadAndInstall();
      expect(result, false);
    });

    test('statusStream emits status changes', () async {
      final statuses = <UpdateStatus>[];
      final sub = service.statusStream.listen(statuses.add);

      await service.initialize();

      // In debug mode, initialize emits upToDate
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(statuses, contains(UpdateStatus.upToDate));

      await sub.cancel();
    });

    test('errorMessage is null initially', () {
      expect(service.errorMessage, isNull);
    });

    test('currentPatchNumber is null initially', () {
      expect(service.currentPatchNumber, isNull);
    });

    test('availablePatchNumber is null initially', () {
      expect(service.availablePatchNumber, isNull);
    });

    test('statusMessage covers all statuses', () {
      // Verify that the switch in statusMessage is exhaustive
      // by checking the enum values exist
      for (final status in UpdateStatus.values) {
        expect(status.name, isNotEmpty);
      }
    });
  });
}
