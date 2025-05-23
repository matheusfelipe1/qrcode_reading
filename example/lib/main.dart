import 'package:flutter/material.dart';
import 'package:qrcode_reading/qrcode_reading.dart';
import 'package:qrcode_reading_example/styles/shape_qecode_view.dart';

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
  const _FirstScreen();

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
            Navigator.pushNamed(context, "/second");
          },
          child: const Text("Next"),
        ),
      ),
    );
  }
}

class _SecondScreen extends StatefulWidget {
  const _SecondScreen();

  @override
  State<_SecondScreen> createState() => __SecondScreenState();
}

class __SecondScreenState extends State<_SecondScreen> {
  var _isFlashLightOn = false;

  var pause = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isFlashLightOn = !_isFlashLightOn;
              });
            },
            icon: Icon(
              _isFlashLightOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: QRCodeReading(
              isFlashLightOn: _isFlashLightOn,
              pauseReading: pause,
              onRead: (data) {
                WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(data),
                    ),
                  );
                });
              },
              overlayWidget: (constraints) => SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Material(
                  shape: ShapeQrCodeView(
                    borderRadius: 32,
                    borderLength: 40,
                    borderColor: Colors.white,
                  ),
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
