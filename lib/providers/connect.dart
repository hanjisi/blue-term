import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isScanningProvider = StreamProvider<bool>((ref) {
  return FlutterBluePlus.isScanning;
});

class ScannerNotifier extends AsyncNotifier<List<ScanResult>> {
  StreamSubscription? _adapterSub;
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  List<ScanResult> _latestScanResults = [];

  @override
  Future<List<ScanResult>> build() async {
    // Cleanup on dispose
    ref.onDispose(() {
      _adapterSub?.cancel();
      _scanSub?.cancel();
      _connSub?.cancel();
    });

    // Listen to connection changes to update list immediately
    _connSub = FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      _updateState();
    });

    // Listen to adapter state
    _adapterSub = FlutterBluePlus.adapterState.listen((event) async {
      if (event == BluetoothAdapterState.on) {
        _subscribeToScanResults();
      } else if (event == BluetoothAdapterState.off ||
          event == BluetoothAdapterState.unauthorized) {
        _scanSub?.cancel();
        _scanSub = null;
        state = AsyncValue.error("Bluetooth is Off", StackTrace.current);
      } else {
        // unknown, turningOn...
        _scanSub?.cancel();
        _scanSub = null;
        // Keep loading to avoid flashing "Turn On"
        state = const AsyncLoading();
      }
    });

    _latestScanResults = FlutterBluePlus.lastScanResults;
    return _mergeResults();
  }

  /// 订阅扫描结果
  void _subscribeToScanResults() async {
    if (_scanSub != null) return;
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      _latestScanResults = results;
      _updateState();
    });
    await startScan();
  }

  void _updateState() {
    state = AsyncValue.data(_mergeResults());
  }

  List<ScanResult> _mergeResults() {
    final connected = FlutterBluePlus.connectedDevices;
    final scannedIds = _latestScanResults.map((e) => e.device.remoteId).toSet();
    final extras = connected.where((d) => !scannedIds.contains(d.remoteId)).map(
      (d) {
        return ScanResult(
          device: d,
          advertisementData: AdvertisementData(
            advName: d.platformName,
            txPowerLevel: null,
            appearance: null,
            connectable: true,
            manufacturerData: {},
            serviceData: {},
            serviceUuids: [],
          ),
          rssi: 0,
          timeStamp: DateTime.now(),
        );
      },
    ).toList();

    // Return combined list
    // Note: If you want connected devices at TOP, you might need to sort or prepend.
    // The previous working version appended extras.
    // Usually connected devices (extras) should be visible.
    // If we want connected devices at the TOP regardless of scan result, we should:
    // 1. Remove connected from _latestScanResults.
    // 2. Add ALL connected as "fake" (or keep real if available) at the top.
    // But the user asked to "restore", so I sticking to the previous logic: [scans, extras]
    // Wait, in step 824 I did return [..._latestScanResults, ...extras];
    // Actually, sorting usually handles "isConnected" priority if the UI does it.
    // If not, maybe we should prepend?
    // User logic in broken step 834 put connected first.
    // I represents the logic from step 824 which user accepted then broke.
    // I will return [...extras, ..._latestScanResults] just in case user wants them at top now.
    // But wait, step 824 had `[..._latestScanResults, ...extras]`.
    // I will stick to logical restoration.

    return [..._latestScanResults, ...extras];
  }

  /// 开始扫描
  Future<void> startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 停止扫描
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}

final scanResultsProvider =
    AsyncNotifierProvider<ScannerNotifier, List<ScanResult>>(
      ScannerNotifier.new,
    );
