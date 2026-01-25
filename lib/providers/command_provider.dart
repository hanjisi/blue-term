import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/command_model.dart';

class CommandState {
  final List<CommandProfile> profiles;
  final String? currentProfileId;
  final bool isLoading;

  CommandState({
    this.profiles = const [],
    this.currentProfileId,
    this.isLoading = true,
  });

  CommandProfile? get currentProfile {
    if (currentProfileId == null) return null;
    try {
      return profiles.firstWhere((p) => p.id == currentProfileId);
    } catch (_) {
      return null;
    }
  }

  CommandState copyWith({
    List<CommandProfile>? profiles,
    String? currentProfileId,
    bool? isLoading,
  }) {
    return CommandState(
      profiles: profiles ?? this.profiles,
      currentProfileId: currentProfileId ?? this.currentProfileId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class CommandNotifier extends Notifier<CommandState> {
  @override
  CommandState build() {
    _init();
    return CommandState();
  }

  Future<void> _init() async {
    await _loadProfiles();
  }

  /// 获取配置文件的本地路径
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/blueterm_profiles');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return profileDir.path;
  }

  /// 加载配置文件
  Future<void> _loadProfiles() async {
    try {
      final path = await _localPath;
      final dir = Directory(path);
      final List<CommandProfile> loaded = [];
      print("加载配置文件 $path");
      final profiles = dir.list();
      await for (final entity in profiles) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            loaded.add(CommandProfile.fromJson(json));
          } catch (e) {
            print('加载配置文件时出错 ${entity.path}: $e');
          }
        }
      }

      if (loaded.isEmpty) {
        // 创建默认配置文件
        print("创建默认配置文件");
        final defaultProfile = CommandProfile.defaultProfile();
        await saveProfile(defaultProfile);
        loaded.add(defaultProfile);
      }

      // 加载最后选择的配置文件
      final prefs = await SharedPreferences.getInstance();
      String? lastId = prefs.getString('last_profile_id');
      print("上一次选择的配置id ${lastId ?? "空"}");

      final profile = loaded.where((p) => p.id == lastId).firstOrNull;
      if (profile == null) {
        print("上一次选择的配置文件不存在，使用第一个配置文件");
        await prefs.setString('last_profile_id', loaded.first.id);
        lastId = loaded.first.id;
      }

      state = state.copyWith(
        profiles: loaded,
        currentProfileId: lastId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('Error init profiles: $e');
    }
  }

  /// 保存配置文件
  Future<void> saveProfile(CommandProfile profile) async {
    final path = await _localPath;
    final file = File('$path/${profile.id}.json');
    await file.writeAsString(jsonEncode(profile.toJson()));

    // 更新本地状态
    final index = state.profiles.indexWhere((p) => p.id == profile.id);
    List<CommandProfile> newProfiles = [...state.profiles];
    if (index >= 0) {
      newProfiles[index] = profile;
    } else {
      newProfiles.add(profile);
    }

    state = state.copyWith(profiles: newProfiles);
  }

  /// 删除配置文件
  Future<void> deleteProfile(String id) async {
    final path = await _localPath;
    final file = File('$path/$id.json');
    if (await file.exists()) {
      await file.delete();
    }

    final newProfiles = state.profiles.where((p) => p.id != id).toList();
    String? newCurrentId = state.currentProfileId;
    if (state.currentProfileId == id) {
      newCurrentId = newProfiles.isNotEmpty ? newProfiles.first.id : null;
    }

    state = state.copyWith(
      profiles: newProfiles,
      currentProfileId: newCurrentId,
    );
    if (newCurrentId != null) {
      await setCurrentProfile(newCurrentId);
    }
  }

  /// 设置当前配置文件
  Future<void> setCurrentProfile(String id) async {
    state = state.copyWith(currentProfileId: id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_profile_id', id);
  }

  /// 导入配置文件
  Future<void> importProfile(String jsonString) async {
    try {
      final json = jsonDecode(jsonString);
      final profile = CommandProfile.fromJson(json);
      await saveProfile(profile);
    } catch (e) {
      print("导入配置文件失败: $e");
      rethrow;
    }
  }
}

final commandProvider = NotifierProvider<CommandNotifier, CommandState>(
  CommandNotifier.new,
);
