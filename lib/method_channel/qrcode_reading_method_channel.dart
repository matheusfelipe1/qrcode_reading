import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:qrcode_reading/src/qrcode_settings.dart';
import 'package:qrcode_reading/constants/qrcode_reading_constants.dart';

import '../src/qrcode_reading_platform_interface.dart';

/// An implementation of [QRCodeReadingPlatform] that uses method channels.
class MethodChannelQRCodeReading extends QRCodeReadingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(qrcodeReadingChannel);

  @override
  Future<int?> getTextureId(QRCodeSettings settings) async {
    try {
      methodChannel.setMethodCallHandler(callHandler);
      return await methodChannel.invokeMethod<int>(
        startQRCodeReading,
        settings.toMap(),
      );
    } catch (error) {
      if (error is PlatformException) {
        handlerResult(error); 
      }
      return null;
    }
  }


  Future<dynamic> callHandler(MethodCall call) async {
    if (call.method == onQRCodeRead) {
      handlerResult(call.arguments);
    }
  }

  @override
  Future<void> pause() async {
    try {
      await methodChannel.invokeMethod<void>(pauseQRCodeReading);
    } on PlatformException catch (error) {
      handlerResult(error);
    }
  }

  @override
  Future<void> resume() async {
    try {
      await methodChannel.invokeMethod<void>(resumeQRCodeReading);
    } on PlatformException catch (error) {
      handlerResult(error);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await methodChannel.invokeMethod<void>(stopQRCodeReading);
    } on PlatformException catch (error) {
      handlerResult(error);
    }
  }

  @override
  Future<void> toggleFlashLight(bool isFlashLightOn) async {
    try {
      await methodChannel.invokeMethod<void>(
        toggleFlashLightMethod,
        isFlashLightOn,
      );
    } on PlatformException catch (error) {
      handlerResult(error);
    }
  }

}
