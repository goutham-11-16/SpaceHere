import 'dart:io';

class DeviceInfo {
  const DeviceInfo({
    required this.deviceName,
    required this.platform,
    required this.hostname,
  });

  final String deviceName;
  final String platform;
  final String hostname;
}

class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  DeviceInfo get currentDevice {
    final os = Platform.operatingSystem;
    String name;
    String host;

    try {
      host = Platform.localHostname;
    } catch (_) {
      host = 'localhost';
    }

    if (Platform.isLinux) {
      name = 'Ubuntu Desktop';
    } else if (Platform.isAndroid) {
      name = 'OnePlus CPH2613';
    } else if (Platform.isWindows) {
      name = 'Windows PC';
    } else if (Platform.isMacOS) {
      name = 'macOS Workstation';
    } else if (Platform.isIOS) {
      name = 'iPhone';
    } else {
      name = 'Space Client ($os)';
    }

    return DeviceInfo(deviceName: name, platform: os, hostname: host);
  }

  String get currentDeviceName => currentDevice.deviceName;
  String get currentPlatform => currentDevice.platform;
  String get platform => currentPlatform;
}
