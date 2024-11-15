import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:qrcode_reading/constants/qrcode_reading_constants.dart';

import '../src/qrcode_reading_platform_interface.dart';

/// An implementation of [QrcodeReadingPlatform] that uses method channels.
class MethodChannelQrcodeReading extends QRCodeReadingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(qrcodeReadingChannel);

  final StreamController<String> _onQRCodeReadController = StreamController<String>();

  @override
  Future<int?> getTextureId() async {
    try {
      methodChannel.setMethodCallHandler(_handleMethodCall);
      return await methodChannel.invokeMethod<int>(startQRCodeReading);
    } catch (error) {
      return null;
    }
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod<void>(pauseQRCodeReading);
  }

  @override
  Future<void> resume() async {
    await methodChannel.invokeMethod<void>(resumeQRCodeReading);
  }

  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod<void>(stopQRCodeReading);
    _onQRCodeReadController.close();
  }

  @override
  Stream<String> get listenQRCodeRead => _onQRCodeReadController.stream;


  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case onQRCodeRead when call.arguments is String:
        _onQRCodeReadController.add(call.arguments);
        break;
      default:
    }
  }

}
