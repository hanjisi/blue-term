import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/log_message.dart';
import '../providers/terminal_provider.dart';
import '../widgets/command_panel.dart';
import '../widgets/log_view.dart';
import '../widgets/resizable_split_view.dart';

class TerminalPage extends ConsumerStatefulWidget {
  final BluetoothDevice? device; // Nullable for testing UI without device

  const TerminalPage({super.key, this.device});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  StreamSubscription? _notifySub;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _connectAndDiscover();
    }
  }

  Future<void> _connectAndDiscover() async {
    try {
      // Assuming already connected or connect now
      // await widget.device!.connect();

      // Discover services
      List<BluetoothService> services = await widget.device!.discoverServices();

      // Find UART service or writable characteristic
      // Simple logic: find first char with WRITE and first with NOTIFY
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            _writeChar = c;
          }
          if (c.properties.notify || c.properties.indicate) {
            _notifyChar = c;
          }
        }
      }

      if (_notifyChar != null) {
        if (!_notifyChar!.isNotifying) {
          await _notifyChar!.setNotifyValue(true);
        }
        _notifySub = _notifyChar!.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final hexMode = ref.read(terminalProvider).settings.hexMode;
            ref
                .read(terminalProvider.notifier)
                .addLog(
                  LogMessage(
                    text: hexMode
                        ? ""
                        : String.fromCharCodes(
                            value,
                          ), // Wait, rawData handles the hex display
                    rawData: value,
                    type: LogType.received,
                  ),
                );
          }
        });
      }

      ref
          .read(terminalProvider.notifier)
          .addLog(
            LogMessage(
              text: "Connected to ${widget.device!.platformName}. Ready.",
              type: LogType.info,
            ),
          );
    } catch (e) {
      ref
          .read(terminalProvider.notifier)
          .addLog(
            LogMessage(text: "Connection Error: $e", type: LogType.error),
          );
    }
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _loopTimer?.cancel();
    super.dispose();
  }

  void _sendData(String data, bool isHex) async {
    final settings = ref.read(terminalProvider).settings;

    List<int> bytesToSend = [];

    if (isHex) {
      // Parse hex string (ignore spaces)
      final clean = data.replaceAll(RegExp(r'\s+'), '');
      if (clean.length % 2 != 0) {
        ref
            .read(terminalProvider.notifier)
            .addLog(LogMessage(text: "Invalid Hex", type: LogType.error));
        return;
      }
      for (int i = 0; i < clean.length; i += 2) {
        bytesToSend.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
    } else {
      bytesToSend = utf8.encode(data);
      // Append line ending
      if (settings.lineEnding == LineEnding.cr) bytesToSend.add(13);
      if (settings.lineEnding == LineEnding.lf) bytesToSend.add(10);
      if (settings.lineEnding == LineEnding.crlf) bytesToSend.addAll([13, 10]);
    }

    // Add to log
    ref
        .read(terminalProvider.notifier)
        .addLog(
          LogMessage(
            text: isHex ? "" : data,
            rawData: bytesToSend,
            type: LogType.sent,
          ),
        );

    // Send to device
    if (_writeChar != null) {
      try {
        await _writeChar!.write(
          bytesToSend,
          withoutResponse: _writeChar!.properties.writeWithoutResponse,
        );
      } catch (e) {
        ref
            .read(terminalProvider.notifier)
            .addLog(LogMessage(text: "Write Error: $e", type: LogType.error));
      }
    } else {
      ref
          .read(terminalProvider.notifier)
          .addLog(
            LogMessage(
              text: "Write Characteristic not found (Simulated Send)",
              type: LogType.info,
            ),
          );
    }

    // Handle Looping
    if (settings.isLooping && _loopTimer == null) {
      _loopTimer = Timer.periodic(Duration(milliseconds: settings.loopInterval), (
        _,
      ) {
        if (!settings.isLooping) {
          _loopTimer?.cancel();
          _loopTimer = null;
          return;
        }
        // Re-send same data?
        // Recursion might double-log if we call _sendData.
        // Better to just write to device and log.
        // Or just call _sendData? But _sendData does logic again.
        // Let's just call _sendData but avoid loop-trigger logic recursion.
        // Actually, if isLooping is ON, _sendData is called manually ONCE, then timer starts?
        // User "Loop send" toggle usually means "Next send will loop" or "Start sending this repeatedly".
        // Let's assume toggle ON means "Start repeating last message" ??
        // Or "Any message sent is repeated".
        // Implementation: If `isLooping` is checked, start timer.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device?.platformName ?? "Terminal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => ref.read(terminalProvider.notifier).clearLogs(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 38, // Reduced height
            color: Colors.grey.shade200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildToggle(
                  "Hex",
                  state.settings.hexMode,
                  () => ref.read(terminalProvider.notifier).toggleHexMode(),
                ),
                const VerticalDivider(width: 20, indent: 8, endIndent: 8),
                DropdownButton<LineEnding>(
                  value: state.settings.lineEnding,
                  isDense: true, // Compact
                  underline: const SizedBox(), // Remove underline
                  items: LineEnding.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.name.toUpperCase(),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      ref.read(terminalProvider.notifier).setLineEnding(v!),
                ),
                const VerticalDivider(width: 20, indent: 8, endIndent: 8),
                Row(
                  children: [
                    const Text("Loop", style: TextStyle(fontSize: 13)),
                    Transform.scale(
                      scale: 0.8,
                      child: Checkbox(
                        value: state.settings.isLooping,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) {
                          ref
                              .read(terminalProvider.notifier)
                              .updateSettings(
                                state.settings.copyWith(isLooping: v),
                              );
                          if (v == false) {
                            _loopTimer?.cancel();
                            _loopTimer = null;
                          }
                        },
                      ),
                    ),
                    if (state.settings.isLooping)
                      SizedBox(
                        width: 50,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            suffixText: "ms",
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            isDense: true,
                            border: UnderlineInputBorder(),
                          ),
                          onSubmitted: (val) {
                            ref
                                .read(terminalProvider.notifier)
                                .updateSettings(
                                  state.settings.copyWith(
                                    loopInterval: int.tryParse(val) ?? 1000,
                                  ),
                                );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ResizableSplitView(
              topChild: const LogView(),
              bottomChild: CommandPanel(onSend: _sendData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, VoidCallback onTap) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: (_) => onTap(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
