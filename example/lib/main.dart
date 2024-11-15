import 'package:flutter/material.dart';
import 'package:qrcode_reading/qrcode_reading.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: QrcodeReading(
            overlayWidget: Container(
              color: Colors.red,
              child: const Center(
                child: Text('Overlay'),
              ),
            ),
            onRead: (data) {
              print(data);
            },

          ),
        ),
      ),
    );
  }
}
