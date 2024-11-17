# QRCode Reading Plugin

A Flutter plugin for scanning QR codes with ease. This plugin provides a seamless camera view with customizable widgets and functionalities to enhance the QR code scanning experience.

## Features

- **Overlay Widget**: Display a custom function widget on top of the camera view to enhance the user interface.
- **Loading Widget**: Show a widget while the camera is initializing.
- **On QR Code Read**: Trigger a callback function when a QR code is successfully scanned. The scanned result is passed as a `String`.
- **Error Widget**: Display a widget when an error occurs during QR code scanning.
- **Pause QR Code Reading**: Pause and resume the QR code scanning process with the `pauseReading` property.
- **Flashlight Control**: Control the flashlight with the `isFlashLightOn` property. Enable or disable the flashlight to improve scanning in low-light environments.

  <img src="https://github.com/matheusfelipe1/qrcode_reading/raw/main/img_qrcode_reading.jpeg" alt="Exemplo de imagem" width="120"/>

## Installation

1. **Add Dependencies**

   Add the following dependencies to your `pubspec.yaml` file:

   ```yaml
   dependencies:
     qrcode_reading: ^1.0.0
     permission_handler: ^10.2.0
   ```

2. **Install Packages**

   Run the following command to install the packages:

   ```bash
   flutter pub get
   ```

## Configuration

### Android

1. **Update `AndroidManifest.xml`**

   Add the following permissions inside the `<manifest>` tag:

   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   
   <application
       ...
       >
       <!-- Add this inside the <application> tag -->
       <meta-data
           android:name="flutterEmbedding"
           android:value="2" />
   </application>
   ```

2. **Enable Camera Privacy**

   Ensure that the camera feature is declared (optional but recommended):

   ```xml
   <uses-feature android:name="android.hardware.camera" android:required="false" />
   ```

### iOS

1. **Update `Info.plist`**

   Add the following keys to your `Info.plist` file to request camera access:

   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app requires camera access to scan QR codes.</string>
   ```

## Usage

Import the plugin and the `permission_handler` package in your Dart file:

```dart
import 'package:qrcode_reading/qrcode_reading.dart';
import 'package:permission_handler/permission_handler.dart';
```

### Example

```dart
QRCodeReader(
  isFlashLightOn: false, // Initial state of the flashlight
  pauseReading: false, // Control to pause the QR code reading
  errorWidget: Text("An error occurred"), // Widget shown when an error occurs
  loadingWidget: CircularProgressIndicator(), // Widget shown while the camera is loading
  overlayWidget: (constraints) => MyCustomOverlay(), // Widget displayed on top of the camera view
  onRead: (result) {
    print("QR Code: $result");
  }, // Callback when a QR code is read
);
```

### Handling Permissions

Before using the `QRCodeReader`, ensure that you have requested and granted camera permissions using the `permission_handler` package:

```dart
Future<void> _requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
    if (!status.isGranted) {
      // Handle the permission denial
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera permission is required to scan QR codes')),
      );
    }
  }
}
```

Call the `_requestCameraPermission` method before initializing the `QRCodeReader`.

## Permissions

This plugin requires camera access to function correctly. Ensure that you have handled the permissions as outlined in the [Configuration](#configuration) section.

- **Android**: Permissions are declared in `AndroidManifest.xml`.
- **iOS**: Permissions are declared in `Info.plist`.

## Contributing

Contributions are welcome! Please ensure that you follow the existing code style and include tests for any new features or bug fixes.
