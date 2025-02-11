import 'package:flutter/widgets.dart';
import 'package:qrcode_reading/utils/base_qrcode_reading_controller.dart';

abstract class BaseQRCodeReadingPage<T extends StatefulWidget,
        C extends BaseQRCodeReadingController> extends State<T>
    with WidgetsBindingObserver {
  late final C controller;
  @override
  void initState() {
    super.initState();
    controller = getController();
    controller.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.onResume();
    } else {
      controller.onPause();
    }
  }

  @override
  void dispose() {
    controller.onDispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  C getController();
}
