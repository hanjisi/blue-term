import 'package:uuid/uuid.dart';

/// 命令类型
enum CommandType {
  simple, // 简单命令
  input, // 输入命令
  enumSelect, // 枚举命令
}

/// 一个枚举选项
class EnumOption {
  /// 选项名称
  final String name;

  /// 选项值
  final String value;

  EnumOption({required this.name, required this.value});

  factory EnumOption.fromJson(Map<String, dynamic> json) {
    return EnumOption(name: json['name'] ?? '', value: json['value'] ?? '');
  }

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  @override
  String toString() => name;
}

/// 一个命令
class CommandItem {
  final String id;
  String name;
  CommandType type;
  String data; // For simple and input (default value)
  List<EnumOption> enumOptions;
  bool isHex;
  String unit;

  CommandItem({
    String? id,
    required this.name,
    required this.type,
    this.data = '',
    this.enumOptions = const [],
    this.isHex = false,
    this.unit = '',
  }) : id = id ?? const Uuid().v4();

  factory CommandItem.fromJson(Map<String, dynamic> json) {
    return CommandItem(
      id: json['id'],
      name: json['name'],
      type: CommandType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CommandType.simple,
      ),
      data: json['data'] ?? '',
      enumOptions:
          (json['enumOptions'] as List?)
              ?.map(
                (e) => e is String
                    ? EnumOption(name: e, value: e)
                    : EnumOption.fromJson(e),
              )
              .toList() ??
          [], // Handle legacy List<String> potentially
      isHex: json['isHex'] ?? false,
      unit: json['unit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'data': data,
      'enumOptions': enumOptions.map((e) => e.toJson()).toList(),
      'isHex': isHex,
      'unit': unit,
    };
  }
}

/// 一个命令类别
class CommandCategory {
  final String id;
  String name;
  List<CommandItem> items;

  CommandCategory({String? id, required this.name, required this.items})
    : id = id ?? const Uuid().v4();

  factory CommandCategory.fromJson(Map<String, dynamic> json) {
    return CommandCategory(
      id: json['id'],
      name: json['name'],
      items:
          (json['items'] as List?)
              ?.map((e) => CommandItem.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

/// 一个命令配置
class CommandProfile {
  final String id;
  String name;
  List<CommandCategory> categories;

  CommandProfile({String? id, required this.name, required this.categories})
    : id = id ?? const Uuid().v4();

  factory CommandProfile.fromJson(Map<String, dynamic> json) {
    return CommandProfile(
      id: json['id'],
      name: json['name'],
      categories:
          (json['categories'] as List?)
              ?.map((e) => CommandCategory.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categories': categories.map((e) => e.toJson()).toList(),
    };
  }

  // 创建一个默认的空配置文件
  factory CommandProfile.defaultProfile() {
    return CommandProfile(
      name: '默认',
      categories: [CommandCategory(name: '通用', items: [])],
    );
  }
}
