import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ble_central_mobile/Screens/HomeScreen/image_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

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
  StreamSubscription<List<int>>? _imageDataSubscription;

  @override
  void initState() {
    super.initState();
    _imageDataSubscription = listenToPeripheral().listen((data) {
      setState(() {
        _imageData.add(Uint8List.fromList(data));
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
        child: GridView.builder(
          scrollDirection: Axis.vertical,
          itemCount: _imageData.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            return ImageItem(imageData: _imageData[index]);
          },
        ),
      ),
    );
  }

  /// Listen for device events through BLE and yield the results
  static Stream<List<int>> listenToPeripheral() async* {
    FlutterReactiveBle ble = FlutterReactiveBle();
    ble.logLevel = LogLevel.verbose;
    DiscoveredDevice? bleDevice;
    StreamSubscription<ConnectionStateUpdate>? connectionStateSub;
    StreamSubscription<List<int>>? notificationSub;
    List<List<int>> receivedPackets = [];
    int? messageLength;
    List<int> messageBuffer = [];
    bool connected = false;

    // Check permissions
    Map<Permission, PermissionStatus> permissionStatus = {};

    // Request permissions as long as they are denied
    while (true) {
      permissionStatus = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      if (permissionStatus.values.every((element) => element.isGranted)) {
        break;
      }
    }

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
          //if (discovered.name == "pop-os") {
          //  debugPrint("Device found - ${discovered.name}");
          bleDevice = discovered;
          break;
          //}
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
              ble.subscribeToCharacteristic(characteristic).listen((packet) {
            receivedPackets.add(packet);
            debugPrint("Received notification of length ${packet.length}");
          });

          // Send device id and wait for confirmation
          await ble.writeCharacteristicWithResponse(
            characteristic,
            value: utf8.encode("Ready"),
          );

          // Continuously read the image data from the peripheral device
          while (true) {
            // Wait for the device to respond with the device id
            while (connected) {
              if (receivedPackets.isNotEmpty) {
                List<int> packet = receivedPackets.removeAt(0);
                if (messageLength == null) {
                  messageLength = int.tryParse(utf8.decode(packet));
                } else {
                  // Append the latest packet to the message buffer
                  messageBuffer.addAll(packet);

                  if (messageBuffer.length >= messageLength) {
                    // Yield the image data
                    yield messageBuffer;

                    // Clear the message buffer and reset the message length
                    messageLength = null;
                    messageBuffer.clear();

                    // Send device id and wait for confirmation
                    await ble.writeCharacteristicWithResponse(
                      characteristic,
                      value: utf8.encode("Ready"),
                    );
                  }
                }
              } else {
                // Wait for 50ms before checking again
                await Future.delayed(const Duration(milliseconds: 50));
              }
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
      ble.deinitialize();

      // Wait for 3 seconds before trying to connect again
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
