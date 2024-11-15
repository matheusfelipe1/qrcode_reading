import 'package:flutter_test/flutter_test.dart';
import 'package:qrcode_reading/qrcode_reading.dart';
import 'package:qrcode_reading/src/qrcode_reading_platform_interface.dart';
import 'package:qrcode_reading/method_channel/qrcode_reading_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockQRCodeReadingPlatform
    with MockPlatformInterfaceMixin
    implements QRCodeReadingPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final QRCodeReadingPlatform initialPlatform = QRCodeReadingPlatform.instance;

  test('$MethodChannelQRCodeReading is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelQRCodeReading>());
  });

  test('getPlatformVersion', () async {
    QRCodeReading qrcodeReadingPlugin = QRCodeReading();
    MockQRCodeReadingPlatform fakePlatform = MockQRCodeReadingPlatform();
    QRCodeReadingPlatform.instance = fakePlatform;

    expect(await qrcodeReadingPlugin.getPlatformVersion(), '42');
  });
}
