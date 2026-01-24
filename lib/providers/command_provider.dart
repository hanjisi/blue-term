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
    // Start loading immediately
    _init();
    return CommandState();
  }

  Future<void> _init() async {
    await _loadProfiles();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${directory.path}/blueterm_profiles');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return profileDir.path;
  }

  Future<void> _loadProfiles() async {
    // Note: state might be accessed after disposal if we aren't careful,
    // but in Notifier build it's usually safe or we check mounted.
    // Notifier doesn't expose mounted check easily, but we can try.

    try {
      final path = await _localPath;
      final dir = Directory(path);
      final List<CommandProfile> loaded = [];

      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            loaded.add(CommandProfile.fromJson(json));
          } catch (e) {
            print('Error loading profile ${entity.path}: $e');
          }
        }
      }

      if (loaded.isEmpty) {
        // Create default profile
        final defaultProfile = CommandProfile.defaultProfile();
        await saveProfile(defaultProfile);
        loaded.add(defaultProfile);
      }

      // Load last selected profile ID
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString('last_profile_id') ?? loaded.first.id;

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

  Future<void> saveProfile(CommandProfile profile) async {
    final path = await _localPath;
    final file = File('$path/${profile.id}.json');
    await file.writeAsString(jsonEncode(profile.toJson()));

    // Update local state
    final index = state.profiles.indexWhere((p) => p.id == profile.id);
    List<CommandProfile> newProfiles = [...state.profiles];
    if (index >= 0) {
      newProfiles[index] = profile;
    } else {
      newProfiles.add(profile);
    }

    // If it's the current profile, we might want to refresh UI? well copyWith updates state ref.
    state = state.copyWith(profiles: newProfiles);
  }

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

  Future<void> setCurrentProfile(String id) async {
    state = state.copyWith(currentProfileId: id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_profile_id', id);
  }

  Future<void> importProfile(String jsonString) async {
    try {
      final json = jsonDecode(jsonString);
      final profile = CommandProfile.fromJson(json);
      await saveProfile(profile);
    } catch (e) {
      print("Import failed: $e");
      rethrow;
    }
  }
}

final commandProvider = NotifierProvider<CommandNotifier, CommandState>(
  CommandNotifier.new,
);
