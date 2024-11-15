import 'package:flutter/material.dart';
import 'package:qrcode_reading/src/qrcode_settings.dart';
import 'package:qrcode_reading/enum/qrcode_reading_state.dart';
import 'package:qrcode_reading/src/qrcode_reading_controller.dart';
import 'package:qrcode_reading/utils/base_qrcode_reading_page.dart';

class QRCodeReading extends StatefulWidget {
  const QRCodeReading({
    super.key,
    this.errorWidget,
    this.loadingWidget,
    this.overlayWidget,
    required this.onRead,
    this.pauseReading = false,
    this.isFlashLightOn = false,
  });

  /// This widget will be displayed on top of the camera view
  final Widget? overlayWidget;

  /// Widget to show when the camera is loading
  final Widget? loadingWidget;

  /// This function will be called when a QR code is read.
  /// The [Object] parameter is the result of the QR code read.
  final Function(String) onRead;

  /// Widget to show when an error occurs
  final Widget? errorWidget;

  /// Pause the QR code reading
  final bool pauseReading;

  /// The current state of the flashlight
  /// If true, the flashlight is on
  /// If false, the flashlight is off
  /// Default value is false
  final bool isFlashLightOn;

  @override
  State<QRCodeReading> createState() => _QRCodeReadingState();
}

class _QRCodeReadingState
    extends BaseQRCodeReadingPage<QRCodeReading, QRCodeReadingController> {
  @override
  void initState() {
    super.initState();
    controller.settings = QRCodeSettings(
      pauseReading: widget.pauseReading,
      isFlashLightOn: widget.isFlashLightOn,
    );
  }

  @override
  void didUpdateWidget(covariant QRCodeReading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlashLightOn != widget.isFlashLightOn) {
      controller.toggleFlashLight();
    }

    if (oldWidget.pauseReading != widget.pauseReading) {
      if (widget.pauseReading) {
        controller.onPause();
      } else {
        controller.onResume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QRCodeReadingState>(
      stream: controller.stream,
      initialData: QRCodeReadingState.loading,
      builder: (_, snapshot) {
        final state = snapshot.data as QRCodeReadingState;
        switch (state) {
          case QRCodeReadingState.loading:
            return widget.loadingWidget ?? _buildDefaultLoadingWidget();

          case QRCodeReadingState.preview:
            return _buildPreviewWidget();
          case QRCodeReadingState.scanned when controller.data != null:
            widget.onRead(controller.data!);
            return _buildPreviewWidget();
          case QRCodeReadingState.error:
            return _buildErrorWidget();
          default:
            return widget.errorWidget ?? _buildErrorWidget();
        }
      },
    );
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildPreviewWidget() {
    if (controller.textureId == null) {
      return _buildDefaultLoadingWidget();
    }
    return Stack(
      children: [
        Texture(textureId: controller.textureId!),
        if (widget.overlayWidget != null) widget.overlayWidget!,
      ],
    );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? _buildDefaultLoadingWidget();
  }

  @override
  QRCodeReadingController getController() {
    return QRCodeReadingController();
  }
}
