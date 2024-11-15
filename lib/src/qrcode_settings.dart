final class QRCodeSettings {
  final bool pauseReading;
  final bool isFlashLightOn;

  const QRCodeSettings({
    required this.pauseReading,
    required this.isFlashLightOn,
  });

  Map<String, dynamic> toMap() {
    return {
      'pauseReading': pauseReading,
      'isFlashLightOn': isFlashLightOn,
    };
  }

  QRCodeSettings copyWith({
    double? delay,
    bool? pauseReading,
    bool? isFlashLightOn,
  }) {
    return QRCodeSettings(
      pauseReading: pauseReading ?? this.pauseReading,
      isFlashLightOn: isFlashLightOn ?? this.isFlashLightOn,
    );
  }
}
