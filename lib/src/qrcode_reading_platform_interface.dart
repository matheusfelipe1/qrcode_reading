import 'dart:async';
import 'package:qrcode_reading/src/qrcode_settings.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../method_channel/qrcode_reading_method_channel.dart';

abstract class QRCodeReadingPlatform extends PlatformInterface {
  /// Constructs a QRCodeReadingPlatform.
  QRCodeReadingPlatform() : super(token: _token);

  static final Object _token = Object();

  static QRCodeReadingPlatform _instance = MethodChannelQRCodeReading();

  /// The default instance of [QRCodeReadingPlatform] to use.
  ///
  /// Defaults to [MethodChannelQRCodeReading].
  static QRCodeReadingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [QRCodeReadingPlatform] when
  /// they register themselves.
  static set instance(QRCodeReadingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<int?> getTextureId(QRCodeSettings settings) {
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

  Future<void> toggleFlashLight(bool isFlashLightOn) {
    throw UnimplementedError('setFlashLight() has not been implemented.');
  }

  Future<dynamic> Function(Object) handlerResult = (result) async {};
}
