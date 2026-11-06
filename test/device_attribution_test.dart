import 'package:flutter_test/flutter_test.dart';
import 'package:spacehere/models/space_node.dart';
import 'package:spacehere/services/database/database_service.dart';
import 'package:spacehere/services/device/device_service.dart';

void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initialize();
  });

  group('DeviceService & Multiplatform Origin Tests', () {
    test('DeviceService reports recognized identity and platform', () {
      final deviceName = DeviceService.instance.currentDeviceName;
      final platform = DeviceService.instance.platform;

      expect(deviceName, isNotEmpty);
      expect(platform, isNotEmpty);
      expect(platform, 'linux');
      expect(deviceName, 'Ubuntu Desktop');
    });

    test('SpaceNode creates with default and custom origin device', () {
      final defaultNode = SpaceNode(
        uuid: 'test-default-node',
        parentUuid: null,
        name: 'DefaultNode',
        sizeBytes: 1024,
        mimeType: 'text/plain',
        isFolder: false,
        chunkMessageIds: [101],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(defaultNode.originDevice, 'Local Workspace');
      expect(defaultNode.originPlatform, 'unknown');

      final oneplusNode = defaultNode.copyWith(
        originDevice: 'OnePlus CPH2613',
        originPlatform: 'android',
      );
      expect(oneplusNode.originDevice, 'OnePlus CPH2613');
      expect(oneplusNode.originPlatform, 'android');

      final json = oneplusNode.toJson();
      expect(json['originDevice'], 'OnePlus CPH2613');
      expect(json['originPlatform'], 'android');

      final deserialized = SpaceNode.fromJson(json);
      expect(deserialized.originDevice, 'OnePlus CPH2613');
      expect(deserialized.originPlatform, 'android');
    });

    test(
      'DatabaseService filters nodes by device and lists registered devices',
      () async {
        // Create folder on Ubuntu
        final ubuntuFolder = await db.createFolder('Ubuntu_Backups', null);
        expect(ubuntuFolder.originDevice, 'Ubuntu Desktop');

        // Insert custom node tagged with OnePlus Android
        final androidPhoto = SpaceNode(
          uuid: 'android-photo-1',
          parentUuid: null,
          name: 'IMG_2026_OnePlus.jpg',
          sizeBytes: 3145728,
          mimeType: 'image/jpeg',
          isFolder: false,
          chunkMessageIds: [901, 902],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          originDevice: 'OnePlus CPH2613',
          originPlatform: 'android',
        );
        await db.upsertNode(androidPhoto);

        // Verify listRegisteredDevices
        final devices = await db.listRegisteredDevices();
        expect(devices, contains('Ubuntu Desktop'));
        expect(devices, contains('OnePlus CPH2613'));

        // Filter by Ubuntu Desktop
        final ubuntuItems = await db.filterByDevice('Ubuntu Desktop');
        expect(ubuntuItems.any((n) => n.name == 'Ubuntu_Backups'), isTrue);
        expect(
          ubuntuItems.any((n) => n.name == 'IMG_2026_OnePlus.jpg'),
          isFalse,
        );

        // Filter by OnePlus
        final oneplusItems = await db.filterByDevice('OnePlus CPH2613');
        expect(
          oneplusItems.any((n) => n.name == 'IMG_2026_OnePlus.jpg'),
          isTrue,
        );
        expect(oneplusItems.any((n) => n.name == 'Ubuntu_Backups'), isFalse);
      },
    );
  });
}
