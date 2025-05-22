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

import AVFoundation
import UIKit
import Flutter

class QrcodeTexture: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate  {
    
    private var textureId: Int64 = 0
    private var isScanning: Bool = false
    private var isProcessingQRCode = false
    private var pixelBuffer: CVPixelBuffer?
    private var registry: FlutterTextureRegistry
    private var captureSession: AVCaptureSession?
    private var commandChannel: FlutterMethodChannel
    private var videoCaptureDevice: AVCaptureDevice?
    
    // ✅ Controle de nitidez e câmera
    private var lastSharpDetection = Date()
    private let sharpnessTimeout: TimeInterval = 1.5
    private let sharpnessCheckInterval: TimeInterval = 0.3
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var sharpnessTimer: Timer?
    private let sharpnessQueue = DispatchQueue(label: "sharpness.queue", qos: .utility)
    private var consecutiveLowEdges = 0
    private let maxConsecutiveFails = 50
    private var isAnotherCamera = false
    
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

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
       
        self.configureCamera(videoCaptureDevice, zoom: 1.5)
        
    }
    
    @available(iOS 13.0, *)
    private func configureCamera(_ videoCaptureDevice: AVCaptureDevice, zoom: Double) {
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1280x720
        self.currentCameraPosition = videoCaptureDevice.position
        
        do {
            try videoCaptureDevice.lockForConfiguration()
            
            if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
                videoCaptureDevice.focusMode = .continuousAutoFocus
            }
            
            if videoCaptureDevice.isFocusPointOfInterestSupported {
                videoCaptureDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            
            if let format = videoCaptureDevice.formats.first(where: {
                $0.isMultiCamSupported &&
                CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            }) {
                videoCaptureDevice.activeFormat = format
            }
            
            videoCaptureDevice.videoZoomFactor = min(zoom, videoCaptureDevice.activeFormat.videoMaxZoomFactor)
            
            videoCaptureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
            videoCaptureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            
            videoCaptureDevice.unlockForConfiguration()
        } catch {
            print("Erro na configuração do dispositivo: \(error)")
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
        resumeCamera()
        startSharpnessMonitoring()
    }
    
    func stopCamera() {
        isScanning = false
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
            self.captureSession?.stopRunning()
            self.captureSession?.inputs.forEach { self.captureSession?.removeInput($0) }
            self.captureSession?.outputs.forEach { self.captureSession?.removeOutput($0) }
        }
        DispatchQueue.main.async {
            self.registry.unregisterTexture(self.textureId)
            self.textureId = -1
        }
        consecutiveLowEdges = 0
        isAnotherCamera = false
    }
    
    func pauseCamera() {
        isScanning = false
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }
    
    func resumeCamera() {
        isScanning = true
        DispatchQueue.global(qos: .background).async {
            if let session = self.captureSession, !session.isRunning {
                self.isScanning = true
                session.startRunning()
            }
        }
        DispatchQueue.main.async {
            self.registry.textureFrameAvailable(self.textureId)
        }
        
    }
    

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if isScanning {
            if output is AVCaptureVideoDataOutput {
                sharpnessQueue.async {
                    self.checkFrameSharpness(sampleBuffer)
                }
                        
                if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    if let videoOrientation = currentVideoOrientation() {
                        connection.videoOrientation = videoOrientation
                    }
                    
                    pixelBuffer = imageBuffer
                    registry.textureFrameAvailable(textureId)
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
    
    private func startSharpnessMonitoring() {
        sharpnessTimer?.invalidate()
        sharpnessTimer = Timer.scheduledTimer(
            withTimeInterval: sharpnessCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkSharpnessConditions()
        }
    }
    
    private func checkSharpnessConditions() {
            sharpnessQueue.async { [weak self] in
                guard let self = self, self.isScanning else { return }
                
                if consecutiveLowEdges >= maxConsecutiveFails {
                    if #available(iOS 13.0, *) {
                        self.switchToWideAngleCamera()
                    }
                }
            }
        }
        
    @available(iOS 13.0, *)
    private func switchToWideAngleCamera() {
        guard let wideDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentCameraPosition
        ) else { return }
        
        self.configureCamera(wideDevice, zoom: 1.0)
    }
        
   
    
    private func checkFrameSharpness(_ sampleBuffer: CMSampleBuffer) {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
            
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
            guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return }
            
            // Amostra central rápida (5% da imagem)
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


