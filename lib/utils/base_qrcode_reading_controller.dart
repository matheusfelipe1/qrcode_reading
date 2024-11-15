import 'dart:async';

import 'package:qrcode_reading/enum/qrcode_reading_state.dart';

abstract class BaseQRCodeReadingController {

  late final Stream<QRCodeReadingState> stream;

  void onInit();
  void onDispose();
  void onPause();
  void onResume();  
}