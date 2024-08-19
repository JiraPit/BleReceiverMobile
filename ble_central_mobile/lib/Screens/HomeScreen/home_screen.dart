import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ble_central_mobile/Screens/HomeScreen/image_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

final Uuid kPeripheralServiceUuid =
    Uuid.parse("0000181C00001000800000805F9B34FB");
final Uuid kPeripheralCharacteristicUuid =
    Uuid.parse("00002AC400001000800000805F9B34FB");

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Uint8List?> _imageData = [];
  StreamSubscription<Uint8List?>? _imageDataSubscription;

  @override
  void initState() {
    super.initState();
    _imageDataSubscription = listenToPeripheral().listen((data) {
      setState(() {
        _imageData.add(data);
      });
    });
  }

  @override
  void dispose() {
    _imageDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Expanded(
          child: GridView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _imageData.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              return ImageItem(imageData: _imageData[index]);
            },
          ),
        ),
      ),
    );
  }

  /// Listen for device events through BLE and yield the results
  static Stream<Uint8List?> listenToPeripheral() async* {
    FlutterReactiveBle ble = FlutterReactiveBle();
    ble.logLevel = LogLevel.verbose;
    DiscoveredDevice? bleDevice;
    StreamSubscription<ConnectionStateUpdate>? connectionStateSub;
    StreamSubscription<List<int>>? notificationSub;
    List<int>? latestNotification;
    bool connected = false;

    while (true) {
      // Clear GATT cache
      try {
        await ble.clearGattCache(bleDevice?.id ?? "");
      } catch (_) {}

      // Setup a scan subscription to find the device
      try {
        await for (DiscoveredDevice discovered in ble.scanForDevices(
          withServices: [kPeripheralServiceUuid],
          scanMode: ScanMode.lowLatency,
        )) {
          if (discovered.name == "pop-os") {
            debugPrint("Device found - ${discovered.name}");
            bleDevice = discovered;
            break;
          }
        }
      } catch (e) {
        // If scan fails, try again
        debugPrint("Scan failed: $e");
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }

      try {
        // Connect to device and keep the connection alive
        connectionStateSub = ble
            .connectToAdvertisingDevice(
          id: bleDevice!.id,
          withServices: [kPeripheralServiceUuid],
          prescanDuration: const Duration(seconds: 5),
          connectionTimeout: const Duration(seconds: 10),
        )
            .listen(
          (event) {
            if (event.connectionState == DeviceConnectionState.connected) {
              connected = true;
            } else {
              connected = false;
            }
          },
        );
      } on TimeoutException {
        // Connection timeout
        connectionStateSub?.cancel();
        connectionStateSub = null;
        continue;
      } catch (e) {
        // Other errors
        debugPrint("Connection failed: $e");
        connectionStateSub?.cancel();
        connectionStateSub = null;
        continue;
      }

      // Wait for the device to connect
      while (!connected) {
        await Future.delayed(const Duration(seconds: 1));
      }

      try {
        // As long as the device is connected, stay in the main loop
        while (connected) {
          // Get the characteristic
          QualifiedCharacteristic characteristic = QualifiedCharacteristic(
            serviceId: kPeripheralServiceUuid,
            characteristicId: kPeripheralCharacteristicUuid,
            deviceId: bleDevice.id,
          );

          // Subscribe to the characteristic for notifications
          notificationSub =
              ble.subscribeToCharacteristic(characteristic).listen((event) {
            latestNotification = event;
            debugPrint("Received notification: $latestNotification");
          });

          // Send device id and wait for confirmation
          await ble.writeCharacteristicWithoutResponse(
            characteristic,
            value: utf8.encode("Ready"),
          );

          // Continuously read the image data from the peripheral device
          while (true) {
            // Wait for the device to respond with the device id
            while (connected) {
              if (latestNotification != null) {
                yield Uint8List.fromList(latestNotification!);
                // Send device id and wait for confirmation
                await ble.writeCharacteristicWithoutResponse(
                  characteristic,
                  value: utf8.encode("Ready"),
                );
                latestNotification = null;
              }
              await Future.delayed(const Duration(milliseconds: 100));
            }
            if (!connected) {
              continue;
            }
          }
        }
      } on TimeoutException {
        // Write timeout
        debugPrint("Device timed out");
      } on GenericFailure catch (e) {
        // Device disconnected
        debugPrint("Device disconnected: $e");
      } catch (e) {
        // Other errors
        debugPrint("Error: $e");
      }

      // Cleanup
      connected = false;
      connectionStateSub.cancel();
      connectionStateSub = null;
      notificationSub?.cancel();
      notificationSub = null;
      latestNotification = null;
      ble.deinitialize();

      // Wait for 3 seconds before trying to connect again
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
