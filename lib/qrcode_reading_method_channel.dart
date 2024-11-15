import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'qrcode_reading_platform_interface.dart';

/// An implementation of [QrcodeReadingPlatform] that uses method channels.
class MethodChannelQrcodeReading extends QrcodeReadingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('qrcode_reading');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
