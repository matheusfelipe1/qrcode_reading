import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../method_channel/qrcode_reading_method_channel.dart';

abstract class QRCodeReadingPlatform extends PlatformInterface {
  /// Constructs a QrcodeReadingPlatform.
  QRCodeReadingPlatform() : super(token: _token);

  static final Object _token = Object();

  static QRCodeReadingPlatform _instance = MethodChannelQrcodeReading();

  /// The default instance of [QrcodeReadingPlatform] to use.
  ///
  /// Defaults to [MethodChannelQrcodeReading].
  static QRCodeReadingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QrcodeReadingPlatform] when
  /// they register themselves.
  static set instance(QRCodeReadingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int?> getTextureId() {
    throw UnimplementedError('getTextureId() has not been implemented.');
  }

  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> resume() {
    throw UnimplementedError('resume() has not been implemented.');
  }

  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Stream<String> get listenQRCodeRead => throw UnimplementedError('onQRCodeRead has not been implemented.');
}
