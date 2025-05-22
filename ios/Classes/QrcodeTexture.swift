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
    private var consecutiveLowEdges: Int = 0
    private let maxEdges: Int = 50
    
    
    init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
        self.registry = registry
        self.commandChannel = FlutterMethodChannel(name: QRCodeConstants.qrcodeReadingChannel, binaryMessenger: messenger)
        super.init()
    }
    
    func getTextureId() -> Int64 {
        return textureId
    }
    
    @available(iOS 13.0, *)
    func startCamera(settings: QRCodeSettings) -> Void {
        textureId = registry.register(self)
        pixelBuffer = nil
        registry.textureFrameAvailable(textureId)

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1280x720
        
        let videoCaptureDevice: AVCaptureDevice
        
        if let device = findCamera() {
            videoCaptureDevice = device
        } else {
            guard let defaultDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            videoCaptureDevice = defaultDevice
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        
        self.videoCaptureDevice = videoCaptureDevice
        
        self.captureSession = captureSession
        
        self.resumeCamera()

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
        
        
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            self.toggleFlash(flashLight: settings.isFlashLightOn)
        }
        
    }
    
    func stopCamera() {
        isScanning = false
        self.captureSession?.stopRunning()
        self.pixelBuffer = nil
        self.registry.unregisterTexture(self.textureId)
        self.textureId = 0
        self.captureSession = nil
        self.videoCaptureDevice = nil
    }
    
    func pauseCamera() {
        isScanning = false
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }
    
    func resumeCamera() {
        isScanning = true
        
        pixelBuffer = nil
        registry.textureFrameAvailable(textureId)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            if !session.isRunning {
                session.startRunning()
            }
            self.registry.textureFrameAvailable(self.textureId)
        }
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
    
    private var lastFrameProcessed: TimeInterval = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isScanning {
            if output is AVCaptureVideoDataOutput {
                DispatchQueue.main.sync {
                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        if let videoOrientation = currentVideoOrientation() {
                            connection.videoOrientation = videoOrientation
                        }
                        self.pixelBuffer = imageBuffer
                        self.registry.textureFrameAvailable(self.textureId)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.checkFrameSharpness(sampleBuffer)
            }

            let currentTime = CACurrentMediaTime()
            if currentTime - lastFrameProcessed >= 0.5 {
                lastFrameProcessed = currentTime

                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

                }
            }
            
            if consecutiveLowEdges >= maxEdges {
                if #available(iOS 13.0, *) {
                    switchToAngleWideCamera()
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
    private func findCamera() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.default(for: .video)
        return discoverySession
    }

    @available(iOS 13.0, *)
    private func switchToAngleWideCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            
            session.stopRunning()
            
            for input in session.inputs {
                session.removeInput(input)
            }
            
            let newCamera: AVCaptureDevice? = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .back
            ).devices.first
            
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
                    camera.videoZoomFactor = min(1.0, camera.activeFormat.videoMaxZoomFactor)
                    camera.unlockForConfiguration()
                }
            } catch {
                print("Error on configure camera \(error.localizedDescription)")
            }
            
            session.startRunning()
        }
    }
    
    private func checkFrameSharpness(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
        let sampleSize = 20
        var edgeCount = 0
        
        for y in (height/2 - sampleSize)...(height/2 + sampleSize) {
            guard y >= 0 && y < height else { continue }
            
            let row = baseAddress + y * bytesPerRow
            for x in (width/2 - sampleSize)...(width/2 + sampleSize) {
                guard x >= 0 && x < width else { continue }
                
                let pixel = row.load(fromByteOffset: x * 4, as: UInt32.self)
                let r = Float((pixel >> 16) & 0xFF)
                let g = Float((pixel >> 8) & 0xFF)
                let b = Float(pixel & 0xFF)
                let luminance = (0.299 * r + 0.587 * g + 0.114 * b)
                
                if luminance < 30 || luminance > 220 { // Thresholds otimizados
                    edgeCount += 1
                }
            }
        }
        
        if edgeCount == 0 {
            consecutiveLowEdges += 1
        } else {
            consecutiveLowEdges = 0
        }
    }

}

