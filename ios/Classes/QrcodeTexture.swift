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
    
    init(registry: FlutterTextureRegistry, messenger: FlutterBinaryMessenger) {
        self.registry = registry
        self.commandChannel = FlutterMethodChannel(name: QRCodeConstants.qrcodeReadingChannel, binaryMessenger: messenger)
        super.init()
    }
    
    func startCameraAndGetTextureId(settings: QRCodeSettings) -> Int64 {
        textureId = registry.register(self)

        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return -1 }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return -1 }
        
        self.videoCaptureDevice = videoCaptureDevice

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return -1
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return -1
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_queue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        self.captureSession = captureSession
        DispatchQueue.global(qos: .background).async {
            self.resumeCamera()
        }
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            self.toggleFlash(flashLight: settings.isFlashLightOn)
        }

        return textureId
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

}

