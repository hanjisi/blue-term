import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/log_message.dart';

enum LineEnding { none, cr, lf, crlf }

class TerminalSettings {
  final bool hexMode;
  final LineEnding lineEnding;
  final bool autoScroll;
  final bool showTimestamp;
  final int loopInterval; // ms
  final bool isLooping;

  const TerminalSettings({
    this.hexMode = false,
    this.lineEnding = LineEnding.crlf,
    this.autoScroll = true,
    this.showTimestamp = true,
    this.loopInterval = 1000,
    this.isLooping = false,
  });

  TerminalSettings copyWith({
    bool? hexMode,
    LineEnding? lineEnding,
    bool? autoScroll,
    bool? showTimestamp,
    int? loopInterval,
    bool? isLooping,
  }) {
    return TerminalSettings(
      hexMode: hexMode ?? this.hexMode,
      lineEnding: lineEnding ?? this.lineEnding,
      autoScroll: autoScroll ?? this.autoScroll,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      loopInterval: loopInterval ?? this.loopInterval,
      isLooping: isLooping ?? this.isLooping,
    );
  }
}

class TerminalState {
  final List<LogMessage> logs;
  final TerminalSettings settings;

  TerminalState({required this.logs, required this.settings});

  TerminalState copyWith({List<LogMessage>? logs, TerminalSettings? settings}) {
    return TerminalState(
      logs: logs ?? this.logs,
      settings: settings ?? this.settings,
    );
  }
}

class TerminalNotifier extends Notifier<TerminalState> {
  @override
  TerminalState build() {
    return TerminalState(logs: [], settings: const TerminalSettings());
  }

  void addLog(LogMessage log) {
    state = state.copyWith(logs: [...state.logs, log]);
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  void updateSettings(TerminalSettings newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  void toggleHexMode() {
    state = state.copyWith(
      settings: state.settings.copyWith(hexMode: !state.settings.hexMode),
    );
  }

  void setLineEnding(LineEnding ending) {
    state = state.copyWith(
      settings: state.settings.copyWith(lineEnding: ending),
    );
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(
  TerminalNotifier.new,
);
