import 'dart:async';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:qrcode_reading/src/qrcode_settings.dart';
import 'package:qrcode_reading/enum/qrcode_reading_state.dart';
import 'package:qrcode_reading/utils/base_qrcode_reading_controller.dart';
import 'package:qrcode_reading/src/qrcode_reading_platform_interface.dart';

class QRCodeReadingController extends BaseQRCodeReadingController {
  int? textureId;

  String? data;

  StreamController<QRCodeReadingState>? _controller;

  QRCodeSettings settings = const QRCodeSettings(
    pauseReading: false,
    isFlashLightOn: false,
  );

  @override
  Stream<QRCodeReadingState>? get stream => _controller?.stream;

  @override
  void onDispose() {
    data = null;
    textureId = null;
    _controller?.close();
    _controller = null;
    QRCodeReadingPlatform.instance.dispose();
  }

  @override
  void onInit() {
    _controller = StreamController<QRCodeReadingState>.broadcast();
    _controller?.sink.add(QRCodeReadingState.loading);
    QRCodeReadingPlatform.instance.getTextureId(settings).then((data) {
      textureId = data;
      if (textureId != null) {
        _controller?.sink.add(QRCodeReadingState.preview);
      }
    });
    QRCodeReadingPlatform.instance.handlerResult = _handlerResult;
  }

  Future<dynamic> _handlerResult(Object result) async {
    if (result is String) {
      data = result.trim();
      _controller?.sink.add(QRCodeReadingState.scanned);
    } else if (result is PlatformException) {
      data = null;
      _controller?.sink.add(QRCodeReadingState.error);
      log(result.toString());
    }
  }

  @override
  void onPause() {
    QRCodeReadingPlatform.instance.pause();
  }

  @override
  void onResume() {
    QRCodeReadingPlatform.instance.resume();
    QRCodeReadingPlatform.instance.toggleFlashLight(settings.isFlashLightOn);
  }

  void toggleFlashLight() {
    settings = settings.copyWith(isFlashLightOn: !settings.isFlashLightOn);
    QRCodeReadingPlatform.instance.toggleFlashLight(settings.isFlashLightOn);
  }
}
