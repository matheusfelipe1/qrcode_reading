//
//  QrcodeTexture.swift
//  qrcode_reading
//
//  Created by Matheus Felipe on 15/11/24.
//

import UIKit
import Flutter
import CoreImage
import AVFoundation

class QrcodeTexture: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    // ✅ OTIMIZAÇÃO 1: Filas dedicadas com prioridades adequadas
    private let cameraQueue = DispatchQueue(
        label: "camera.queue",
        qos: .userInteractive,
        autoreleaseFrequency: .workItem
    )
    private let metadataQueue = DispatchQueue(
        label: "metadata.queue",
        qos: .userInteractive
    )
    
    // ✅ OTIMIZAÇÃO 2: Contexto CIContext reutilizável
    private let ciContext = CIContext(options: [
        .workingColorSpace: NSNull(),
        .outputColorSpace: NSNull(),
        .useSoftwareRenderer: false
    ])
    
    private var textureId: Int64 = 0
    private var isScanning: Bool = false
    private var isProcessingQRCode = false
    private var pixelBuffer: CVPixelBuffer?
    private var registry: FlutterTextureRegistry
    private var captureSession: AVCaptureSession?
    private var commandChannel: FlutterMethodChannel
    private var videoCaptureDevice: AVCaptureDevice?
    
    // ✅ OTIMIZAÇÃO 3: Controle de taxa de detecção
    private var lastQRCodeRead: String?
    private var lastReadTime: TimeInterval = 0
    private let deBounceInterval: TimeInterval = 0.1  // 10 detecções/segundo
    
    init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
        self.registry = registry
        self.commandChannel = FlutterMethodChannel(
            name: QRCodeConstants.qrcodeReadingChannel,
            binaryMessenger: messenger
        )
        super.init()
    }
    
    func getTextureId() -> Int64 {
        textureId = registry.register(self)
        return textureId
    }
    
    @available(iOS 13.0, *)
    func startCamera(settings: QRCodeSettings) -> Void {
        let captureSession = AVCaptureSession()
        
        // ✅ OTIMIZAÇÃO 4: Configuração otimizada de resolução
        captureSession.sessionPreset = .hd1280x720  // 720p para melhor performance
        if #available(iOS 16.0, *) {
            captureSession.usesApplicationAudioSession = false
        }
        
        // ✅ OTIMIZAÇÃO 5: Seleção do dispositivo com prioridade para wide angle
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        print("Versão 5")

        
        self.videoCaptureDevice = videoCaptureDevice
        
        // ✅ OTIMIZAÇÃO 6: Configurações de hardware
        configureDeviceFormatAndZoom(device: videoCaptureDevice)
        configureFocusAndExposure(device: videoCaptureDevice)
        
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            print("Failed to create video input")
            return
        }
        
        captureSession.addInput(videoInput)
        
        // ✅ OTIMIZAÇÃO 7: Configuração de ROI (Região de Interesse)
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataQueue)
            metadataOutput.metadataObjectTypes = [.qr]
            
            // Definir área de detecção central (60% da tela)
            let roiRect = CGRect(
                x: 0.2,
                y: 0.2,
                width: 0.6,
                height: 0.6
            )
            metadataOutput.rectOfInterest = roiRect
        }
        
        // ✅ OTIMIZAÇÃO 8: Configuração de saída de vídeo otimizada
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation() ?? .portrait
            }
        }
        
        self.captureSession = captureSession
        self.resumeCamera()
        
        // ✅ OTIMIZAÇÃO 9: Flash com atraso otimizado
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.toggleFlash(flashLight: settings.isFlashLightOn)
        }
    }
    
    func stopCamera() {
        isScanning = false
        lastQRCodeRead = nil
        cameraQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession?.inputs.forEach { self?.captureSession?.removeInput($0) }
            self?.captureSession?.outputs.forEach { self?.captureSession?.removeOutput($0) }
        }
        DispatchQueue.main.async {
            self.registry.unregisterTexture(self.textureId)
            self.textureId = 0
        }
    }
    
    func pauseCamera() {
        isScanning = false
        cameraQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    func resumeCamera() {
        guard !isScanning else { return }
        isScanning = true
        
        // ✅ OTIMIZAÇÃO 10: Prioridade de thread elevada
        cameraQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            if !session.isRunning {
                session.startRunning()
            }
            DispatchQueue.main.async {
                self.registry.textureFrameAvailable(self.textureId)
            }
        }
    }
    
    // MARK: - Video Processing
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard isScanning else { return }
        
        if output is AVCaptureVideoDataOutput {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                pixelBuffer = imageBuffer
                registry.textureFrameAvailable(textureId)
            }
        }
    }
    
    
    // MARK: - Metadata Processing
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !isProcessingQRCode else { return }
        guard Date().timeIntervalSince1970 - lastReadTime > deBounceInterval else { return }
        
        isProcessingQRCode = true
        
        // ✅ OTIMIZAÇÃO 13: Processamento mínimo de metadados
        if let code = metadataObjects
            .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .first(where: { $0.type == .qr && $0.stringValue != nil }) {
            
            let currentTime = Date().timeIntervalSince1970
            let newValue = code.stringValue!
            
            if newValue != lastQRCodeRead {
                lastQRCodeRead = newValue
                lastReadTime = currentTime
                
                DispatchQueue.main.async { [weak self] in
                    self?.commandChannel.invokeMethod(
                        QRCodeConstants.onQRCodeRead,
                        arguments: newValue
                    )
                }
            }
        }
        
        isProcessingQRCode = false
    }
    
    // MARK: - Helper Methods
    private func currentVideoOrientation() -> AVCaptureVideoOrientation? {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }
    
    // ✅ OTIMIZAÇÃO 14: Configuração de dispositivo aprimorada
    @available(iOS 13.0, *)
    private func findBestCameraDevice() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .back
        )
        
        return discoverySession.devices.first
    }
    
    @available(iOS 13.0, *)
    private func configureDeviceFormatAndZoom(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // ✅ OTIMIZAÇÃO 15: Formato de dispositivo prioritário
            if let format = device.formats.first(where: {
                $0.isMultiCamSupported &&
                CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            }) {
                device.activeFormat = format
            }
            
            device.videoZoomFactor = min(1.35, device.activeFormat.videoMaxZoomFactor)
            device.unlockForConfiguration()
        } catch {
            print("Device configuration error: \(error)")
        }
    }
    
    private func configureFocusAndExposure(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .continuousAutoFocus
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Focus configuration error: \(error)")
        }
    }
    
    func toggleFlash(flashLight: Bool) {
        guard let device = videoCaptureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = flashLight ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}
