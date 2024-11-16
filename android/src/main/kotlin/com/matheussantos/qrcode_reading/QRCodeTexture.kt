package com.matheussantos.qrcode_reading

import android.util.Size
import android.os.Looper
import android.os.Handler
import android.media.Image
import android.view.Surface
import android.content.Context
import android.os.HandlerThread
import android.media.ImageReader
import android.hardware.camera2.*
import android.graphics.ImageFormat
import com.google.zxing.BinaryBitmap
import android.annotation.SuppressLint
import android.graphics.SurfaceTexture
import com.google.zxing.qrcode.QRCodeReader
import io.flutter.plugin.common.MethodChannel
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.PlanarYUVLuminanceSource

class QRCodeTexture(
    context: Context,
    private val channel: MethodChannel,
    private val surfaceTexture: SurfaceTexture,
) {

    private var imageReader: ImageReader? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var captureRequestBuilder: CaptureRequest.Builder? = null

    private val backgroundThread = HandlerThread(QRCodeConstants.CAMERA_THREAD).apply { start() }
    private val backgroundHandler = Handler(backgroundThread.looper)

    private val cameraManager: CameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

    @SuppressLint("MissingPermission")
    fun startCamera(isFlashLightOn: Boolean) {
        val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: run {
            errorWhenReadingQRCode(java.lang.Exception(QRCodeConstants.CAMERA_REAR_404))
            return
        }

        try {
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession(isFlashLightOn)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            errorWhenReadingQRCode(e)
        }
    }

    @SuppressLint("MissingPermission")
    private fun createCaptureSession(isFlashLightOn: Boolean) {
        val previewSize = Size(QRCodeConstants.PREVIEW_WIDTH, QRCodeConstants.PREVIEW_HEIGHT)
        surfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height)
        val previewSurface = Surface(surfaceTexture)

        imageReader = ImageReader.newInstance(
            previewSize.width,
            previewSize.height,
            ImageFormat.YUV_420_888,
            2
        ).apply {
            setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage()
                if (image != null) {
                    processImage(image)
                    image.close()
                }
            }, backgroundHandler)
        }

        val surfaces = listOf(previewSurface, imageReader!!.surface)
        try {
            cameraDevice?.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (cameraDevice == null) {
                        errorWhenReadingQRCode(java.lang.Exception(QRCodeConstants.CAMERA_DEVICE_NULL))
                        return
                    }

                    captureSession = session
                    captureRequestBuilder = cameraDevice!!.createCaptureRequest(
                        CameraDevice.TEMPLATE_PREVIEW
                    ).apply {
                        addTarget(previewSurface)
                        addTarget(imageReader!!.surface)
                    }

                    try {
                        session.setRepeatingRequest(captureRequestBuilder!!.build(), null, backgroundHandler)
                    } catch (e: CameraAccessException) {
                        errorWhenReadingQRCode(e)
                    }
                    toggleFlash(isFlashLightOn)

                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    errorWhenReadingQRCode(java.lang.Exception(session.toString()))
                }
            }, backgroundHandler)
        } catch (e: CameraAccessException) {
            errorWhenReadingQRCode(e)
        }
    }

    private fun processImage(image: Image) {
        val buffer = image.planes[0].buffer
        val data = ByteArray(buffer.remaining())
        buffer.get(data)

        val source = PlanarYUVLuminanceSource(
            data,
            image.width,
            image.height,
            0,
            0,
            image.width,
            image.height,
            false
        )

        val binaryBitmap = BinaryBitmap(HybridBinarizer(source))

        try {
            val qrCodeReader = QRCodeReader()
            val result = qrCodeReader.decode(binaryBitmap)
            onQRCodeRead(result.text)
        } catch (e: Exception) {
            return;
        }
    }

    fun stopCamera() {
        try {
            captureSession?.stopRepeating()
            captureSession?.close()
            cameraDevice?.close()
            imageReader?.close()
            backgroundThread.quitSafely()
        } catch (e: Exception) {
            errorWhenReadingQRCode(e)
        }
    }

    fun pauseCamera() {
        try {
            captureSession?.stopRepeating()
        } catch (e: CameraAccessException) {
            errorWhenReadingQRCode(e)
        }
    }

    fun toggleFlash(enableFlash: Boolean) {
        if (captureRequestBuilder == null) return
        val newFlashMode = if (enableFlash) {
            CaptureRequest.FLASH_MODE_TORCH
        } else {
            CaptureRequest.FLASH_MODE_OFF
        }
        captureRequestBuilder!!.set(CaptureRequest.FLASH_MODE, newFlashMode)
        try {
            captureSession?.setRepeatingRequest(captureRequestBuilder!!.build(), null, backgroundHandler)
        } catch (e: CameraAccessException) {
            errorWhenReadingQRCode(e)
        }
    }


    fun resumeCamera() {
        if (captureRequestBuilder == null || captureSession == null) return

        try {
            captureSession?.setRepeatingRequest(captureRequestBuilder!!.build(), null, backgroundHandler)
        } catch (e: CameraAccessException) {
            errorWhenReadingQRCode(e)
        }
    }

    private fun onQRCodeRead(qrCode: String) {
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod(QRCodeConstants.METHOD_ON_QRCODE_READ, qrCode)
        }
    }

    private fun errorWhenReadingQRCode(e: java.lang.Exception) {
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod(QRCodeConstants.METHOD_ON_ERROR, e.message)
        }
    }

}
