import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/log_message.dart';
import '../providers/terminal_provider.dart';

class LogView extends ConsumerWidget {
  const LogView({super.key, required this.id});

  final DeviceIdentifier id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(terminalProvider(id));
    final logs = state.logs;
    final settings = state.settings;

    // Auto-scroll logic could be added with a ScrollController and post frame callback
    // For now, using reverse ListView is a simple trick if we want newest at bottom?
    // Usually terminals have oldest at top. We need a ScrollController to jump to bottom.

    final ScrollController scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settings.autoScroll && scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      color: Colors.black,
      child: SelectionArea(
        child: ListView.builder(
          controller: scrollController,
          itemCount: logs.length,
          padding: const EdgeInsets.all(0),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildLogItem(log, settings);
          },
        ),
      ),
    );
  }

  Widget _buildLogItem(LogMessage log, TerminalSettings settings) {
    Color color;
    String prefix;
    switch (log.type) {
      case LogType.sent:
        color = Colors.greenAccent;
        prefix = "TX";
        break;
      case LogType.received:
        color = Colors.blueAccent;
        prefix = "RX";
        break;
      case LogType.error:
        color = Colors.redAccent;
        prefix = "ERR";
        break;
      case LogType.info:
        color = Colors.grey;
        prefix = "INF";
        break;
    }

    String content = log.text;
    if (settings.hexMode && log.rawData != null) {
      content = log.rawData!
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Text.rich(
        TextSpan(
          children: [
            // if (settings.showTimestamp)
            //   WidgetSpan(
            //     alignment: PlaceholderAlignment.middle,
            //     child: SizedBox(
            //       width: 75,
            //       child: Text(
            //         "[${log.timeString}]",
            //         style: const TextStyle(
            //           color: Colors.grey,
            //           fontSize: 12,
            //           fontFamily: 'monospace',
            //         ),
            //       ),
            //     ),
            //   ),
            // const TextSpan(text: " "),
            TextSpan(
              text: "[$prefix] ",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: content,
              style: TextStyle(
                color: color,
                fontFamily: 'Courier',
                fontSize: 14,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
