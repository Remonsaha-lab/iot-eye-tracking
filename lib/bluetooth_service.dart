import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class ESP32BluetoothService {
  fbp.BluetoothDevice? _device;
  fbp.BluetoothCharacteristic? _characteristic;

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  Stream<String> get messages => _messageController.stream;

  bool get isConnected => _characteristic != null;

  // Start scanning for ESP32 devices
  Future<List<fbp.BluetoothDevice>> startScan() async {
    List<fbp.BluetoothDevice> espDevices = [];

    // Start scanning
    await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Listen to scan results
    fbp.FlutterBluePlus.scanResults.listen((results) {
      for (fbp.ScanResult r in results) {
        // Filter for ESP32 devices - you might need to adjust this filter
        // based on how your ESP32 advertises itself
        if (r.device.platformName.contains('ESP32') ||
            r.device.platformName.contains('ESP')) {
          if (!espDevices.contains(r.device)) {
            espDevices.add(r.device);
          }
        }
      }
    });

    // Wait for the scan to complete
    await Future.delayed(const Duration(seconds: 5));
    await fbp.FlutterBluePlus.stopScan();

    return espDevices;
  }

  // Connect to an ESP32 device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      _messageController.add('Connecting to ${device.platformName}...');

      // Connect to the device
      await device.connect();
      _device = device;

      _messageController.add('Connected to ${device.platformName}');

      // Discover services
      _messageController.add('Discovering services...');
      List<fbp.BluetoothService> services = await device.discoverServices();

      // Find the service and characteristic we need
      // Note: You'll need to replace these UUIDs with the ones your ESP32 is using
      for (fbp.BluetoothService service in services) {
        // This is a placeholder UUID - replace with your actual service UUID
        if (service.uuid.toString() == '0000180a-0000-1000-8000-00805f9b34fb') {
          for (fbp.BluetoothCharacteristic characteristic
              in service.characteristics) {
            // This is a placeholder UUID - replace with your actual characteristic UUID
            if (characteristic.uuid.toString() ==
                '00002a56-0000-1000-8000-00805f9b34fb') {
              _characteristic = characteristic;

              // Subscribe to notifications if the characteristic supports it
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  _messageController.add('Received: ${utf8.decode(value)}');
                });
              }

              _messageController.add('Ready to communicate');
              return true;
            }
          }
        }
      }

      _messageController.add('Failed to find the right service/characteristic');
      return false;
    } catch (e) {
      _messageController.add('Error connecting: $e');
      return false;
    }
  }

  // Disconnect from the device
  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
      _device = null;
      _characteristic = null;
      _messageController.add('Disconnected');
    }
  }

  // Send motor angle command to ESP32
  Future<bool> sendMotorAngle(int angle) async {
    if (_characteristic == null) {
      _messageController.add('Not connected to ESP32');
      return false;
    }

    try {
      // Format the command for the ESP32
      // We'll use a simple format: "ANGLE:X" where X is the angle value
      String command = "ANGLE:$angle";
      List<int> bytes = utf8.encode(command);

      await _characteristic!.write(bytes);
      _messageController.add('Sent command: $command');
      return true;
    } catch (e) {
      _messageController.add('Error sending command: $e');
      return false;
    }
  }

  // Send action command when double-blink is detected
  Future<bool> sendSelectCommand() async {
    if (_characteristic == null) {
      _messageController.add('Not connected to ESP32');
      return false;
    }

    try {
      // Send a select command
      String command = "SELECT";
      List<int> bytes = utf8.encode(command);

      await _characteristic!.write(bytes);
      _messageController.add('Sent command: $command');
      return true;
    } catch (e) {
      _messageController.add('Error sending command: $e');
      return false;
    }
  }

  // Dispose of resources
  void dispose() {
    _messageController.close();
    disconnect();
  }
}
