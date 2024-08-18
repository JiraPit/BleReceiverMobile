import 'package:ble_central_mobile/Screens/HomeScreen/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BluetoothImageTesterApp());
}

class BluetoothImageTesterApp extends StatelessWidget {
  const BluetoothImageTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
