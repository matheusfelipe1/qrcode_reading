import UIKit
import Flutter

public class QRCodeReadingPlugin: NSObject, FlutterPlugin {
    
    var qrcodeTexture: QrcodeTexture?
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: QRCodeConstants.qrcodeReadingChannel, binaryMessenger: registrar.messenger())
    let instance = QRCodeReadingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)    
    instance.qrcodeTexture = QrcodeTexture(registry: registrar.textures(), messenger: registrar.messenger())     
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case QRCodeConstants.resumeQRCodeReading:
      self.qrcodeTexture?.resumeCamera()
    case QRCodeConstants.pauseQRCodeReading:
      self.qrcodeTexture?.pauseCamera()
    case QRCodeConstants.stopQRCodeReading:
      self.qrcodeTexture?.stopCamera()
    case QRCodeConstants.toggleFlashLightMethod:
        if let flashLight = call.arguments as? Bool {
            self.qrcodeTexture?.toggleFlash(flashLight: flashLight)
        }
    case QRCodeConstants.startQRCodeReading:
    if let args = call.arguments as? [String: Any] {
        guard let qrcodeSettings = QRCodeSettings(from: args) else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "The arguments provided for QRCodeSettings are invalid.",
                details: nil
            ))
            return
        }
        
        guard let textureId = self.qrcodeTexture?.startCameraAndGetTextureId(settings: qrcodeSettings) else {
            result(FlutterError(
                code: "CAMERA_ERROR",
                message: "Unable to launch camera or get textureId.",
                details: nil
            ))
            return
        }
        
        result(textureId)
    } else {
        result(FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "The arguments provided are not of the expected type.",
            details: nil
        ))
    }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
