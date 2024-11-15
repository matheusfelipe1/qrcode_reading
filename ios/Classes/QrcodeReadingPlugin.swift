import UIKit
import Flutter

public class QrcodeReadingPlugin: NSObject, FlutterPlugin {
    
  var qrcodeTexture: QrcodeTexture?
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: QRCodeConstants.qrcodeReadingChannel, binaryMessenger: registrar.messenger())
    let instance = QrcodeReadingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)    
    instance.qrcodeTexture = QrcodeTexture(registry: registrar.textures(), messenger: registrar.messenger())     
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case QRCodeConstants.startQRCodeReading:
      if let textureId = self.qrcodeTexture?.startCameraAndGetTextureId() {
          result(textureId)
      } else {
          result(FlutterError(code: "404", message: "Texture ID not found", details: nil))
      }
    case QRCodeConstants.resumeQRCodeReading:
      self.qrcodeTexture?.resumeCamera()
    case QRCodeConstants.pauseQRCodeReading:
      self.qrcodeTexture?.pauseCamera()
    case QRCodeConstants.stopQRCodeReading:
      self.qrcodeTexture?.stopCamera()
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
