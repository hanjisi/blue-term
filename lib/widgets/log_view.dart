import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/log_message.dart';
import '../providers/terminal_provider.dart';

class LogView extends ConsumerStatefulWidget {
  const LogView({super.key, required this.id});

  final DeviceIdentifier id;

  @override
  ConsumerState<LogView> createState() => _LogViewState();
}

class _LogViewState extends ConsumerState<LogView> {
  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // 如果距离底部小于 50 像素，则视为“位于底部”
    if (maxScroll - currentScroll <= 50) {
      if (!_shouldAutoScroll) {
        // 只有在状态改变时才更新状态，以避免不必要的重建
        _shouldAutoScroll = true;
      }
    } else {
      if (_shouldAutoScroll) {
        _shouldAutoScroll = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider(widget.id));
    final logs = state.logs;
    final settings = state.settings;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settings.autoScroll &&
          _shouldAutoScroll &&
          _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      color: Colors.black,
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
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
        prefix = ">";
        break;
      case LogType.received:
        color = Colors.blueAccent;
        prefix = "<";
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
            TextSpan(
              text: "[$prefix] ",
              style: TextStyle(color: color, fontSize: 12),
            ),
            TextSpan(
              text: content,
              style: TextStyle(color: color, fontSize: 12, height: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}
