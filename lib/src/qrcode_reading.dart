import 'package:flutter/material.dart';
import 'package:qrcode_reading/enum/qrcode_reading_state.dart';
import 'package:qrcode_reading/src/qrcode_reading_controller.dart';
import 'package:qrcode_reading/utils/base_qrcode_reading_page.dart';

class QrcodeReading extends StatefulWidget {
  const QrcodeReading({
    super.key,
    this.errorWidget,
    this.loadingWidget,
    this.overlayWidget,
    required this.onRead,
  });

  /// Widget to show when an error occurs
  final Widget? errorWidget;

  /// This widget will be displayed on top of the camera view
  final Widget? overlayWidget;

  /// Widget to show when the camera is loading
  final Widget? loadingWidget;

  /// This function will be called when a QR code is read.
  /// The [Object] parameter is the result of the QR code read.
  final Function(Object?) onRead;

  @override
  State<QrcodeReading> createState() => _QrcodeReadingState();
}

class _QrcodeReadingState
    extends BaseQRCodeReadingPage<QrcodeReading, QRCodeReadingController> {
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
          case QRCodeReadingState.gettingData:
            widget.onRead(controller.data);
            return _buildPreviewWidget();

          case QRCodeReadingState.error:
            return widget.errorWidget ?? _buildDefaultErrorWidget();

          default:
            return _buildDefaultErrorWidget();
        }
      },
    );
  }

  Widget _buildDefaultLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return const Center(
      child: Text('Error'),
    );
  }

  Widget _buildPreviewWidget() {
    if (controller.textureId == null) {
      return _buildDefaultErrorWidget();
    }

    return Stack(
      children: [
        Texture(textureId: controller.textureId!),
        if (widget.overlayWidget != null) widget.overlayWidget!,
      ],
    );
  }

  @override
  QRCodeReadingController getController() {
    return QRCodeReadingController();
  }
}
