import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav.dart';
import '../providers/bluetooth_provider.dart';
import '../services/bluetooth_native_service.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  bool isScanning = false;
  List<ScanResult> scanResults = [];

  // Service Instance
  final _nativeService = BluetoothNativeService();

  // Stream subscriptions
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;

  @override
  void initState() {
    super.initState();

    // Listen to scan results
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filter only Movesense devices
          scanResults = results.where((r) {
            final name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.localName;
            return name.startsWith("Movesense");
          }).toList();
        });
      }
    });

    // Listen to scanning state
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          isScanning = state;
        });
      }
    });

    // Listen to Bluetooth adapter state
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        if (state == BluetoothAdapterState.off) {
          // Bluetooth turned off - clean up
          debugPrint("Bluetooth turned OFF - cleaning up");
          setState(() {
            scanResults.clear();
            isScanning = false;
          });
          // Stop scan and disconnect
          _stopScan();
          Provider.of<BluetoothProvider>(context, listen: false).disconnect();
        }
      }
    });
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    _adapterStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Basic permissions for Android 12+ (Scan/Connect) & Location
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
    ].request();

    // Note: In real app, check statuses and show dialog if denied.
  }

  void _startScan() async {
    await _checkPermissions();

    // Check if adapter is on
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please turn on Bluetooth')));
      return;
    }

    setState(() {
      scanResults.clear();
    });

    // Clear connection via provider
    Provider.of<BluetoothProvider>(context, listen: false).disconnect();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Scan Error: $e')));
    }
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  void _connectDevice(BluetoothDevice device) async {
    // 1. Stop scanning
    await _stopScan();

    // 2. Mock connecting UI
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Connecting...')));

    try {
      // 3. Call Native Mds Connect
      // Note: We pass the MAC Id.
      // FlutterBluePlus device.remoteId is the MAC address on Android.
      await _nativeService.connect(device.remoteId.str);

      final deviceName = device.platformName.isNotEmpty
          ? device.platformName
          : "Unknown Movesense";

      // Update via provider
      if (mounted) {
        Provider.of<BluetoothProvider>(
          context,
          listen: false,
        ).connect(deviceName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $deviceName'),
            backgroundColor: Colors.green,
          ),
        );

        // Auto navigate to Monitoring Screen
        Navigator.pushReplacementNamed(context, AppRoutes.monitoring);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnect() {
    Provider.of<BluetoothProvider>(context, listen: false).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        final connectedDevice = bluetoothProvider.connectedDevice;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bluetooth Devices'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _stopScan();
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              },
            ),
          ),

          bottomNavigationBar: const BottomNav(currentIndex: 0),

          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  connectedDevice == null
                                      ? Icons.link_off
                                      : Icons.link,
                                  color: connectedDevice == null
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    connectedDevice == null
                                        ? 'Not Connected'
                                        : 'Connected to $connectedDevice',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: connectedDevice == null
                                          ? Colors.red
                                          : Colors.green.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (connectedDevice != null)
                            TextButton(
                              onPressed: _disconnect,
                              child: const Text("Disconnect"),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Scan Button
                SizedBox(
                  height: 56,
                  child: isScanning
                      ? ElevatedButton.icon(
                          icon: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          label: const Text(
                            'Scanning...',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _stopScan,
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.bluetooth_searching, size: 28),
                          label: const Text(
                            'Scan Movesense Devices',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _startScan,
                        ),
                ),

                const SizedBox(height: 24),

                // Device List
                Expanded(
                  child: scanResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isScanning
                                    ? "Searching for devices..."
                                    : "Tap 'Scan' to find devices",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _startScan(),
                          child: ListView.builder(
                            itemCount: scanResults.length,
                            itemBuilder: (context, index) {
                              final r = scanResults[index];
                              final deviceName =
                                  r.device.platformName.isNotEmpty
                                  ? r.device.platformName
                                  : r.advertisementData.localName;
                              final deviceMac = r.device.remoteId.str;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _connectDevice(r.device),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.device_hub,
                                            color: Colors.blue,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                deviceName.isNotEmpty
                                                    ? deviceName
                                                    : "Unknown Device",
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                deviceMac,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
