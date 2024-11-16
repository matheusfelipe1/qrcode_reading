package com.matheussantos.qrcode_reading

import android.content.Context
import io.flutter.view.TextureRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import java.lang.ref.WeakReference

/** QRCodeReadingPlugin */
class QRCodeReadingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private var activityContext: Context? = null
  private var qrCodeReading: QRCodeTexture? = null
  private var textureRegistry: TextureRegistry? = null
  private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, QRCodeConstants.CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    textureRegistry = flutterPluginBinding.textureRegistry
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      QRCodeConstants.METHOD_ON_PAUSE -> qrCodeReading?.pauseCamera()

      QRCodeConstants.METHOD_TOGGLE_FLASH_LIGHT -> qrCodeReading?.toggleFlash(call.arguments as Boolean)

      QRCodeConstants.METHOD_ON_RESUME -> qrCodeReading?.resumeCamera()

      QRCodeConstants.METHOD_STOP_CAMERA -> {
        qrCodeReading?.stopCamera()
        qrCodeReading = null
        textureEntry?.release()
        textureEntry = null
        result.success(null)
      }

      QRCodeConstants.METHOD_START_CAMERA -> {
        if (activityContext == null || textureRegistry == null) {
          result.error(QRCodeConstants.MISSING_CONTEXT, QRCodeConstants.MISSING_CONTEXT_CONTENT, null)
          return
        }

        textureEntry = textureRegistry!!.createSurfaceTexture()
        val textureId = textureEntry!!.id()
        val weakContext = WeakReference(activityContext!!)

        qrCodeReading = QRCodeTexture(
          channel = channel,
          context = weakContext.get()!!,
          surfaceTexture = textureEntry!!.surfaceTexture(),
        )

        val isFlashLightOn = (call.arguments as Map<String, Any>)["isFlashLightOn"] as Boolean
        qrCodeReading?.startCamera(isFlashLightOn)
        result.success(textureId)
      }

      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityContext = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityContext = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activityContext = binding.activity
  }

  override fun onDetachedFromActivity() {
    activityContext = null
  }
}
