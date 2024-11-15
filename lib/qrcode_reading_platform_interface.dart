import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'qrcode_reading_method_channel.dart';

abstract class QrcodeReadingPlatform extends PlatformInterface {
  /// Constructs a QrcodeReadingPlatform.
  QrcodeReadingPlatform() : super(token: _token);

  static final Object _token = Object();

  static QrcodeReadingPlatform _instance = MethodChannelQrcodeReading();

  /// The default instance of [QrcodeReadingPlatform] to use.
  ///
  /// Defaults to [MethodChannelQrcodeReading].
  static QrcodeReadingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QrcodeReadingPlatform] when
  /// they register themselves.
  static set instance(QrcodeReadingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
