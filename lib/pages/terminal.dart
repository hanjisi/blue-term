import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/terminal_provider.dart';
import '../widgets/command_panel.dart';
import '../widgets/log_view.dart';
import '../widgets/resizable_split_view.dart';

class TerminalPage extends ConsumerStatefulWidget {
  final BluetoothDevice device;

  const TerminalPage({super.key, required this.device});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(terminalProvider(widget.device.remoteId).notifier).connect();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _sendData(String data, bool isHex) async {
    ref
        .read(terminalProvider(widget.device.remoteId).notifier)
        .write(data, isHex);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider(widget.device.remoteId));
    final notifier = ref.read(
      terminalProvider(widget.device.remoteId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName.isEmpty
              ? "未知名称"
              : widget.device.platformName,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: "断开连接",
            onPressed: () async {
              await widget.device.disconnect();
              if (context.mounted) {
                notifier.disconnect();
                ref.invalidate(terminalProvider(widget.device.remoteId));
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            height: 30,
            color: Colors.grey.shade200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildToggle(
                  "Hex",
                  state.settings.hexMode,
                  () => notifier.toggleHexMode(),
                ),
                const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<LineEnding>(
                    value: state.settings.lineEnding,
                    isDense: true,
                    iconSize: 20,
                    alignment: AlignmentDirectional.center,
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
                    onChanged: (v) => notifier.setLineEnding(v!),
                  ),
                ),
                const VerticalDivider(width: 10, indent: 8, endIndent: 8),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, size: 20),
                  tooltip: "清除日志",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  splashRadius: 15,
                  onPressed: notifier.clearLogs,
                ),
              ],
            ),
          ),
          Expanded(
            child: ResizableSplitView(
              topChild: LogView(id: widget.device.remoteId),
              bottomChild: CommandPanel(onSend: _sendData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 2),
        SizedBox(
          width: 35,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              value: value,
              onChanged: (_) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
