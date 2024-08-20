import 'package:ble_central_mobile/Screens/HomeScreen/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BluetoothImageTesterApp());
}

class BluetoothImageTesterApp extends StatelessWidget {
  const BluetoothImageTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ble Receiver Mobile',
      home: HomeScreen(),
    );
  }
}
