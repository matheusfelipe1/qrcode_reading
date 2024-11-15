import 'dart:async';
import 'package:qrcode_reading/enum/qrcode_reading_state.dart';
import 'package:qrcode_reading/src/qrcode_reading_platform_interface.dart';
import 'package:qrcode_reading/utils/base_qrcode_reading_controller.dart';

class QRCodeReadingController extends BaseQRCodeReadingController {
  int? textureId;

  Object? data;

  final StreamController<QRCodeReadingState> _controller =
      StreamController<QRCodeReadingState>();
  @override
  Stream<QRCodeReadingState> get stream => _controller.stream;

  @override
  void onDispose() {
    _controller.close();
    QRCodeReadingPlatform.instance.dispose();
  }

  @override
  void onInit() async {
    _controller.sink.add(QRCodeReadingState.loading);
    textureId = await QRCodeReadingPlatform.instance.getTextureId();
    if (textureId != null) {
      _controller.sink.add(QRCodeReadingState.preview);
    }
    QRCodeReadingPlatform.instance.listenQRCodeRead.listen(_handlerQRCodeRead);
  }

  void _handlerQRCodeRead(String qrcodeValue) {
    data = qrcodeValue;
    _controller.sink.add(QRCodeReadingState.gettingData);
  }

  @override
  void onPause() {
    QRCodeReadingPlatform.instance.pause();
  }

  @override
  void onResume() {
    QRCodeReadingPlatform.instance.resume();
  }
}
