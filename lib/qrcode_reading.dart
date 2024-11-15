
import 'qrcode_reading_platform_interface.dart';

class QrcodeReading {
  Future<String?> getPlatformVersion() {
    return QrcodeReadingPlatform.instance.getPlatformVersion();
  }
}
