package com.matheussantos.qrcode_reading

object QRCodeConstants {
    const val CHANNEL_NAME = "qrcode_reading_channel"
    // methods
    const val METHOD_ON_ERROR= "on_error"
    const val METHOD_ON_QRCODE_READ = "on_qrcode_read"
    const val METHOD_ON_PAUSE = "pause_qrcode_reading"
    const val METHOD_STOP_CAMERA = "stop_qrcode_reading"
    const val METHOD_ON_RESUME = "resume_qrcode_reading"
    const val METHOD_START_CAMERA = "start_qrcode_reading"
    const val METHOD_TOGGLE_FLASH_LIGHT = "toggle_flash_light"

    // Camera settings
    const val PREVIEW_WIDTH = 1920
    const val PREVIEW_HEIGHT = 1080

    // Messages
    const val MISSING_CONTEXT = "MISSING_CONTEXT"
    const val MISSING_CONTEXT_CONTENT = "Activity context or texture registry is missing."

    const val CAMERA_THREAD = "CameraThread"
    const val CAMERA_REAR_404 = "Camera rear not found"
    const val CAMERA_DEVICE_NULL = "Camera device is null"
}