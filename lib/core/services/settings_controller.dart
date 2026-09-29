library;

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/core/services/sync/sync_timestamps.dart';

/// Controller de preferencias do usuario (tema, acento, interacao, glass).
///
/// Fonte: pianolouvorja/app/src/modules/settings/composables/useAppearanceSettings.ts
///
/// Persiste em SharedPreferences (chave-valor no disco).
/// Notifica listeners quando uma preferencia muda.
class SettingsController extends ChangeNotifier {
  static const _keyThemeMode = 'themeMode';
  static const _keyAccent = 'accent';
  static const _keyInteraction = 'interaction';
  static const _keyGlassIntensity = 'glassIntensity';

  ThemeMode _themeMode = ThemeMode.system;
  AccentKey _accent = AccentKey.orange;
  InteractionKey _interaction = InteractionKey.dynamic_;
  int _glassIntensity = 60;

  ThemeMode get themeMode => _themeMode;
  AccentKey get accent => _accent;
  InteractionKey get interaction => _interaction;
  int get glassIntensity => _glassIntensity;

  /// Carrega preferencias salvas. Chamado no startup do app.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_keyThemeMode),
      orElse: () => ThemeMode.system,
    );
    _accent = AccentKey.values.firstWhere(
      (a) => a.name == prefs.getString(_keyAccent),
      orElse: () => AccentKey.orange,
    );
    _interaction = InteractionKey.values.firstWhere(
      (i) => i.name == prefs.getString(_keyInteraction),
      orElse: () => InteractionKey.dynamic_,
    );
    _glassIntensity = prefs.getInt(_keyGlassIntensity) ?? 60;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
    unawaited(SyncTimestamps.touch('settings'));
  }

  Future<void> setAccent(AccentKey key) async {
    _accent = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccent, key.name);
    unawaited(SyncTimestamps.touch('settings'));
  }

  Future<void> setInteraction(InteractionKey key) async {
    _interaction = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInteraction, key.name);
    unawaited(SyncTimestamps.touch('settings'));
  }

  Future<void> setGlassIntensity(int value) async {
    _glassIntensity = value.clamp(0, 100);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGlassIntensity, _glassIntensity);
    unawaited(SyncTimestamps.touch('settings'));
  }
}

/// Chaves de acento (identicas ao Electron accents.ts).
enum AccentKey {
  azure,
  sky,
  teal,
  emerald,
  apricot,
  orange,
  coral,
  rose,
  violet,
  slate,
}

/// Chaves de perfil de interacao (identicas ao Electron page.ts).
enum InteractionKey { dynamic_, soft, mist }
