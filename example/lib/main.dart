import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qrcode_reading/qrcode_reading.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        "/": (_) => const _FirstScreen(),
        "/second": (_) => const _SecondScreen(),
      },
    );
  }
}

class _FirstScreen extends StatefulWidget {
  const _FirstScreen({super.key});

  @override
  State<_FirstScreen> createState() => __FirstScreenState();
}

class __FirstScreenState extends State<_FirstScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            await Permission.camera.request();
            Navigator.pushNamed(context, "/second");
          },
          child: const Text("Next"),
        ),
      ),
    );
  }
}

class _SecondScreen extends StatefulWidget {
  const _SecondScreen({super.key});

  @override
  State<_SecondScreen> createState() => __SecondScreenState();
}

class __SecondScreenState extends State<_SecondScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: QRCodeReading(
        pauseReading: false,
        isFlashLightOn: false,
        overlayWidget: Material(
          color: Colors.black.withOpacity(.5),
          child: const Text("Testing..."),
        ),
        onRead: (data) {
          debugPrint(data);
        },
      ),
    );
  }
}
