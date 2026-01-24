import 'package:blueterm/pages/terminal.dart';
import 'package:blueterm/providers/connect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectPage extends ConsumerWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final adapterState = ref.watch(adapterStateProvider);
    final isScanning = ref.watch(isScanningProvider);
    final scanResults = ref.watch(scanResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: buildScanStatusWidget(
          isScanning.value!,
          scanResults.value?.length ?? 0,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
        },
        child: ListView.separated(
          itemCount: scanResults.value?.length ?? 0,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final scanResult = scanResults.value?[index];
            return ListTile(
              dense: true,
              title: _buildTitle(scanResult!),
              subtitle: _buildSubtitle(scanResult),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (true) _connectedBadge(),
                  const SizedBox(width: 0),
                  _rssiText(scanResult),
                ],
              ),
              onTap: () async {
                // Stop scanning before connecting
                if (isScanning.value == true) {
                  await FlutterBluePlus.stopScan();
                }

                // Show loading? simplified for now
                try {
                  //await scanResult.device.connect(license: License.free);
                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TerminalPage(device: scanResult.device),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Connection failed: $e")),
                    );
                  }
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget buildScanStatusWidget(bool isScanning, int deviceCount) {
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
