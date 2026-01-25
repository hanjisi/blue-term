import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  static final Guid sppServiceGuid = Guid('FFE0');
  static final Guid sppWriteGuid = Guid('FFE2');
  static final Guid sppNotifyGuid = Guid('FFE1');

  final DeviceIdentifier remoteId;
  TerminalNotifier(this.remoteId);

  bool isConnecting = false;
  StreamSubscription? _notifySub;
  Timer? _loopTimer;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  @override
  TerminalState build() {
    return TerminalState(logs: [], settings: const TerminalSettings());
  }

  Future<void> connect() async {
    final device = BluetoothDevice(remoteId: remoteId);
    try {
      if (!device.isConnected) {
        if (isConnecting) {
          return;
        }
        addInfo("正在连接...");
        isConnecting = true;
        await device.connect(license: License.free);

        var services = await device.discoverServices();
        var sspService = services.firstWhere(
          (element) => element.uuid == sppServiceGuid,
        );
        _writeChar = sspService.characteristics.firstWhere(
          (element) => element.uuid == sppWriteGuid,
        );
        _notifyChar = sspService.characteristics.firstWhere(
          (element) => element.uuid == sppNotifyGuid,
        );

        var status = await _notifyChar!.setNotifyValue(true);
        if (!status) {
          throw Exception("订阅响应特征失败");
        }

        _notifySub?.cancel();
        _notifySub = _notifyChar!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final hexMode = state.settings.hexMode;
            addLog(
              LogMessage(
                text: hexMode ? "" : String.fromCharCodes(value),
                rawData: value,
                type: LogType.received,
              ),
            );
          }
        });

        addInfo("连接成功");
        addSent('''====== OEM T Recorder======
Softvar:02.04.00.01
Hardvar:02.03.00.00

ID:    	 1710     SN:       	    0
Cycle:	 1s
Delay:	 500ms    PgaSize:	 0

Temp calib time:
Temp coef:
T0 = 0.000000E+00
T1 = 0.000000E+00
T2 = 0.000000E+00
T3 = 0.000000E+00
T4 = 0.000000E+00


slable
llable''');
      }
    } catch (e) {
      addError("连接失败: $e");
      if (device.isConnected) {
        device.disconnect();
      }
    } finally {
      isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _loopTimer?.cancel();
    _notifySub = null;
    _loopTimer = null;
    _writeChar = null;
    _notifyChar = null;
  }

  Future<void> write(String data, bool isHex) async {
    final settings = state.settings;
    List<int> bytes = [];
    if (isHex) {
      final clean = data.replaceAll(RegExp(r'\s+'), '');
      if (clean.length % 2 != 0) {
        addError("无效的Hex格式");
        return;
      }
      for (int i = 0; i < clean.length; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
    } else {
      bytes = utf8.encode(data);
      if (settings.lineEnding == LineEnding.cr) bytes.add(13);
      if (settings.lineEnding == LineEnding.lf) bytes.add(10);
      if (settings.lineEnding == LineEnding.crlf) bytes.addAll([13, 10]);
    }

    addLog(
      LogMessage(text: isHex ? "" : data, rawData: bytes, type: LogType.sent),
    );

    if (_writeChar != null) {
      try {
        await _writeChar!.write(
          bytes,
          withoutResponse: _writeChar!.properties.writeWithoutResponse,
        );
      } catch (e) {
        addError("写入失败: $e");
      }
    } else {
      addInfo("未找到写入特征值 (模拟发送)");
    }
  }

  void addInfo(String text) {
    addLog(LogMessage(text: text, type: LogType.info));
  }

  void addError(String text) {
    addLog(LogMessage(text: text, type: LogType.error));
  }

  void addReceived(String text) {
    addLog(LogMessage(text: text, type: LogType.received));
  }

  void addSent(String text) {
    addLog(LogMessage(text: text, type: LogType.sent));
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

final terminalProvider =
    NotifierProvider.family<TerminalNotifier, TerminalState, DeviceIdentifier>(
      TerminalNotifier.new,
    );
