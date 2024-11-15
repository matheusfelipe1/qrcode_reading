import 'package:flutter_test/flutter_test.dart';
import 'package:qrcode_reading/qrcode_reading.dart';
import 'package:qrcode_reading/src/qrcode_reading_platform_interface.dart';
import 'package:qrcode_reading/method_channel/qrcode_reading_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQrcodeReadingPlatform
    with MockPlatformInterfaceMixin
    implements QrcodeReadingPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QrcodeReadingPlatform initialPlatform = QrcodeReadingPlatform.instance;

  test('$MethodChannelQrcodeReading is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQrcodeReading>());
  });

  test('getPlatformVersion', () async {
    QrcodeReading qrcodeReadingPlugin = QrcodeReading();
    MockQrcodeReadingPlatform fakePlatform = MockQrcodeReadingPlatform();
    QrcodeReadingPlatform.instance = fakePlatform;

    expect(await qrcodeReadingPlugin.getPlatformVersion(), '42');
  });
}
