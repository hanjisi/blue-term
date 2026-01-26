import 'dart:io';

import 'package:blueterm/pages/terminal.dart';
import 'package:blueterm/providers/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  bool _showFilter = false;
  bool _hideUnnamed = true;
  final TextEditingController _filterCtrl = TextEditingController(text: "SSTD");

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = ref.watch(isScanningProvider);
    final scanResults = ref.watch(scanResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: _buildScanStatusWidget(
          isScanning.value ?? false,
          scanResults.value?.length ?? 0,
        ),
        actions: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      "v${snapshot.data!.version}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: Icon(_showFilter ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilter = !_showFilter;
                if (!_showFilter) {
                  // Optional: clear filter when closing? No, keep state.
                  FocusScope.of(context).unfocus();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: _showFilter ? null : 0,
              child: Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _filterCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '按名称过滤',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        // contentPadding: EdgeInsets.symmetric(
                        //   horizontal: 8,
                        //   vertical: 8,
                        // ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _hideUnnamed,
                            onChanged: (v) =>
                                setState(() => _hideUnnamed = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("隐藏未知名称设备"),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: scanResults.when(
              data: (results) {
                // Filter
                final filtered = results.where((r) {
                  final name = r.device.platformName;
                  if (_hideUnnamed && name.isEmpty) {
                    return false;
                  }
                  if (_filterCtrl.text.isNotEmpty) {
                    if (!name.toLowerCase().contains(
                      _filterCtrl.text.toLowerCase(),
                    )) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                // Sort
                filtered.sort((a, b) {
                  final aConn = a.device.isConnected ? 1 : 0;
                  final bConn = b.device.isConnected ? 1 : 0;
                  if (aConn != bConn) {
                    return bConn - aConn;
                  }
                  return b.rssi.compareTo(a.rssi);
                });
                return RefreshIndicator(
                  onRefresh: () async {
                    if (isScanning.value != true) {
                      await ref.read(scanResultsProvider.notifier).startScan();
                    }
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final scanResult = filtered[index];
                      return ListTile(
                        dense: true,
                        title: _buildTitle(scanResult),
                        subtitle: _buildSubtitle(scanResult),
                        trailing: scanResult.device.isConnected
                            ? _connectedBadge()
                            : _rssiText(scanResult),
                        onTap: () async {
                          if (isScanning.value == true) {
                            await ref
                                .read(scanResultsProvider.notifier)
                                .stopScan();
                          }
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TerminalPage(device: scanResult.device),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
              error: (err, stack) {
                return _buildBluetoothOffWidget(context);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatusWidget(bool isScanning, int deviceCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isScanning)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(),
            ),
          ),
        Text("设备连接 $deviceCount"),
      ],
    );
  }

  Widget _buildBluetoothOffWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text("请开启蓝牙以开始扫描设备", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (Platform.isAndroid) {
                FlutterBluePlus.turnOn();
              }
            },
            child: const Text("开启蓝牙"),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(ScanResult r) {
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : '未知名称';
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSubtitle(ScanResult r) {
    return Text(
      r.device.remoteId.str,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }

  Widget _connectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '已连接',
        style: TextStyle(
          fontSize: 10,
          color: Colors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _rssiText(ScanResult r) {
    final isConnected = r.device.isConnected;
    return SizedBox(
      width: 40,
      child: Text(
        r.rssi.toString(),
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isConnected ? Colors.grey.shade700 : _rssiColor(r.rssi),
        ),
      ),
    );
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -60) {
      return Colors.green;
    } else if (rssi >= -75) {
      return Colors.orange;
    } else {
      return Colors.redAccent;
    }
  }
}
