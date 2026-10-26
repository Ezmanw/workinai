import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppState extends ChangeNotifier {
  static const storageKey = 'workinai_state_v2';

  static const profileColors = <int>[
    0xFF6750A4,
    0xFF0B57D0,
    0xFF006D3B,
    0xFFB3261E,
    0xFF7D5260,
    0xFF006A6A,
    0xFF8B5000,
  ];

  static const seedColors = <int>[
    0xFF6750A4,
    0xFF0B57D0,
    0xFF006D3B,
    0xFFB3261E,
    0xFF7D5260,
    0xFF006A6A,
    0xFF8B5000,
  ];

  final List<Profile> profiles = [];
  final List<Worksheet> worksheets = [];
  String currentProfileId = '';
  AiSettings ai = AiSettings();
  ThemeMode themeMode = ThemeMode.system;
  int seedValue = 0xFF6750A4;
  bool loaded = false;

  Timer? _saveTimer;

  Profile get currentProfile {
    if (profiles.isEmpty) {
      return Profile(
        id: 'default',
        name: 'Learner',
        colorValue: profileColors.first,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return profiles.firstWhere(
      (profile) => profile.id == currentProfileId,
      orElse: () => profiles.first,
    );
  }

  Color get seedColor => Color(seedValue);

  List<Worksheet> get currentWorksheets {
    final list =
        worksheets
            .where((worksheet) => worksheet.profileId == currentProfile.id)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Worksheet> worksheetsFor(String profileId) {
    final list =
        worksheets
            .where((worksheet) => worksheet.profileId == profileId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final rawProfiles = map['profiles'];
          if (rawProfiles is List) {
            for (final item in rawProfiles.whereType<Map>()) {
              final profile = Profile.fromJson(Map<String, dynamic>.from(item));
              if (profile.id.isNotEmpty) profiles.add(profile);
            }
          }
          final rawWorksheets = map['worksheets'];
          if (rawWorksheets is List) {
            for (final item in rawWorksheets.whereType<Map>()) {
              worksheets.add(
                Worksheet.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
          currentProfileId = map['currentProfileId'] as String? ?? '';
          if (map['ai'] is Map) {
            ai = AiSettings.fromJson(
              Map<String, dynamic>.from(map['ai'] as Map),
            );
          }
          final mode = (map['themeMode'] as String? ?? 'system').toLowerCase();
          themeMode = switch (mode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          seedValue = (map['seedValue'] as num?)?.toInt() ?? 0xFF6750A4;
        }
      }
    } catch (error) {
      debugPrint('Could not load saved data: $error');
    }

    if (profiles.isEmpty) {
      final id = _newId('p');
      profiles.add(
        Profile(
          id: id,
          name: 'Learner',
          colorValue: profileColors.first,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      currentProfileId = id;
    }
    if (profiles.every((profile) => profile.id != currentProfileId)) {
      currentProfileId = profiles.first.id;
    }
    loaded = true;
    notifyListeners();
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final prefsFuture = SharedPreferences.getInstance();
    prefsFuture
        .then((prefs) {
          final payload = jsonEncode({
            'profiles': profiles.map((profile) => profile.toJson()).toList(),
            'currentProfileId': currentProfileId,
            'worksheets': worksheets
                .map((worksheet) => worksheet.toJson())
                .toList(),
            'ai': ai.toJson(),
            'themeMode': themeMode.name,
            'seedValue': seedValue,
          });
          prefs.setString(storageKey, payload).catchError((Object error) {
            debugPrint('Could not save data: $error');
            return false;
          });
        })
        .catchError((Object error) {
          debugPrint('Could not open storage: $error');
        });
  }

  void saveNow() => _persist();

  void scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), _persist);
  }

  void touch() {
    notifyListeners();
    scheduleSave();
  }

  Profile addProfile(String name) {
    final trimmed = name.trim();
    final profile = Profile(
      id: _newId('p'),
      name: trimmed.isEmpty ? 'Learner' : trimmed,
      colorValue: profileColors[profiles.length % profileColors.length],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    profiles.add(profile);
    currentProfileId = profile.id;
    touch();
    return profile;
  }

  void switchProfile(String id) {
    if (profiles.every((profile) => profile.id != id)) return;
    currentProfileId = id;
    touch();
  }

  void addWorksheet(Worksheet worksheet) {
    worksheets.add(worksheet);
    touch();
  }

  Worksheet? worksheetById(String id) {
    for (final worksheet in worksheets) {
      if (worksheet.id == id) return worksheet;
    }
    return null;
  }

  void deleteWorksheet(String id) {
    worksheets.removeWhere((worksheet) => worksheet.id == id);
    touch();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    touch();
  }

  void setSeed(int value) {
    seedValue = value;
    touch();
  }

  void setAiSettings(AiSettings settings) {
    ai = settings;
    touch();
  }

  Future<void> resetEverything() async {
    profiles.clear();
    worksheets.clear();
    ai = AiSettings();
    themeMode = ThemeMode.system;
    seedValue = 0xFF6750A4;
    final id = _newId('p');
    profiles.add(
      Profile(
        id: id,
        name: 'Learner',
        colorValue: profileColors.first,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    currentProfileId = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // Ignore storage failures on reset.
    }
    notifyListeners();
  }

  String _newId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${profiles.length}';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
