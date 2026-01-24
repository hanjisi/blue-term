import 'package:intl/intl.dart';

enum LogType { sent, received, info, error }

class LogMessage {
  final DateTime timestamp;
  final String text; // For info/error, or fallback text
  final List<int>? rawData; // For TX/RX binary data
  final LogType type;

  LogMessage({
    required this.text,
    required this.type,
    this.rawData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get timeString => DateFormat('HH:mm:ss.SSS').format(timestamp);
}
