//
//  QrcodeTexture.swift
//  qrcode_reading
//
//  Created by Matheus Felipe on 15/11/24.
//

//
//  QrcodeTexture.swift
//
//
//  Created by Matheus Felipe on 15/11/24.
//

import UIKit
import Flutter
import CoreImage
import AVFoundation

class QrcodeTexture: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {

    private var textureId: Int64 = 0
    private var isScanning: Bool = false
    private var isProcessingQRCode = false
    private var pixelBuffer: CVPixelBuffer?
    private var registry: FlutterTextureRegistry
    private var captureSession: AVCaptureSession?
    private var commandChannel: FlutterMethodChannel
    private var videoCaptureDevice: AVCaptureDevice?
    
    
    init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
        self.registry = registry
        self.commandChannel = FlutterMethodChannel(name: QRCodeConstants.qrcodeReadingChannel, binaryMessenger: messenger)
        super.init()
    }
    
    func getTextureId() -> Int64 {
        textureId = registry.register(self)
        return textureId
    }
    
    @available(iOS 13.0, *)
    func startCamera(settings: QRCodeSettings) -> Void {

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd4K3840x2160
        
        let videoCaptureDevice: AVCaptureDevice
        
        if let device = findUltraWideCamera() {
            videoCaptureDevice = device
            self.isBlurry = true
        } else {
            guard let defaultDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            videoCaptureDevice = defaultDevice
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        
        self.videoCaptureDevice = videoCaptureDevice

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_queue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        self.captureSession = captureSession
        
        self.resumeCamera()
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            self.toggleFlash(flashLight: settings.isFlashLightOn)
        }
        
    }
    
    func stopCamera() {
        isScanning = false
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
        DispatchQueue.main.async {
            self.registry.unregisterTexture(self.textureId)
            self.textureId = 0
        }
        self.isBlurry = false
    }
    
    func pauseCamera() {
        isScanning = false
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }
    
    func resumeCamera() {
        isScanning = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let session = self.captureSession, !session.isRunning else { return }
            session.startRunning()
        }
        DispatchQueue.main.async {
            self.registry.textureFrameAvailable(self.textureId)
        }
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
    
    private var lastFrameProcessed: TimeInterval = 0
    private var isBlurry: Bool = false

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isScanning {
            if output is AVCaptureVideoDataOutput {
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    if let videoOrientation = currentVideoOrientation() {
                        connection.videoOrientation = videoOrientation
                    }

                    pixelBuffer = imageBuffer
                    registry.textureFrameAvailable(textureId)
                }
            }
            
            if isBlurry { return; }

            let currentTime = CACurrentMediaTime()
            if currentTime - lastFrameProcessed >= 0.5 {
                lastFrameProcessed = currentTime

                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

                    let luminance = self.averageLuminance(from: ciImage)

                    if luminance < 0.2 {
                        return
                    }

                    isBlurry = self.isImageBlurry(ciImage, luminance)
                    
                    if isBlurry {
                        DispatchQueue.main.async {
                            if #available(iOS 13.0, *) {
                                self.switchToUltraWideCamera()
                            }
                        }
                    }
                }
            }
        }
    }


    
    func currentVideoOrientation() -> AVCaptureVideoOrientation? {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            return .portrait
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isProcessingQRCode else { return }
        isProcessingQRCode = true

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            for metadataObject in metadataObjects {
                if let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                   let stringValue = readableObject.stringValue {

                    DispatchQueue.main.async {
                        self.commandChannel.invokeMethod(QRCodeConstants.onQRCodeRead, arguments: stringValue)
                    }

                    break
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isProcessingQRCode = false
            }
        }
    }
    
    func toggleFlash(flashLight: Bool) {
        guard let device = videoCaptureDevice, device.hasTorch else {
            print("Device does not have a flashlight.")
            return
        }

        do {
            try device.lockForConfiguration()

            if flashLight {
                if device.isTorchModeSupported(.on) {
                    device.torchMode = .on
                } else {
                    print("Flashlight mode not supported.")
                }
            } else {
                device.torchMode = .off
            }

            device.unlockForConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    @available(iOS 13.0, *)
    private func findUltraWideCamera() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInUltraWideCamera]
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        return discoverySession.devices.first
    }

    @available(iOS 13.0, *)
    private func switchToUltraWideCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            
            session.stopRunning()
            
            for input in session.inputs {
                session.removeInput(input)
            }
            
            let newCamera: AVCaptureDevice? = self.findUltraWideCamera()
            
            guard let camera = newCamera else {
                print("Camera not found")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.videoCaptureDevice = camera
                    
                    try camera.lockForConfiguration()
                    camera.videoZoomFactor = min(1.35, camera.activeFormat.videoMaxZoomFactor)
                    camera.unlockForConfiguration()
                }
            } catch {
                print("Error on configure camera \(error.localizedDescription)")
            }
            
            session.startRunning()
        }
    }

    
    func isImageBlurry(_ image: CIImage, _ luminance: CGFloat) -> Bool {
        let context = CIContext()

        if let edgeDetectionFilter = CIFilter(name: "CISobelEdgeDetection", parameters: [
            kCIInputImageKey: image
        ])?.outputImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(edgeDetectionFilter, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
            
            let edgeValue = Float(bitmap[0]) / 255.0
            
            if edgeValue < 0.4 {
                return true
            }
        }

        guard let grayscaleImage = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: image,
            kCIInputSaturationKey: 0.0
        ])?.outputImage else { return false }

        guard let averageFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: grayscaleImage,
            kCIInputExtentKey: CIVector(x: 0, y: 0, z: image.extent.width, w: image.extent.height)
        ])?.outputImage else { return false }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(averageFilter, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let brightness = Float(bitmap[0]) / 255.0
        
        if brightness > 4.5, luminance > 4.0 {
            
            return true
        }

        return brightness < 0.3
    }


    
    
    private func averageLuminance(from ciImage: CIImage) -> CGFloat {
        let extent = ciImage.extent
        let context = CIContext(options: nil)
        let inputImage = ciImage.clampedToExtent()

        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.0 }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height), forKey: "inputExtent")

        guard let outputImage = filter.outputImage else { return 0.0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        let result = 0.299 * red + 0.587 * green + 0.114 * blue
        return result
    }


}


