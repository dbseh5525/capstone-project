import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dog_state.dart';

abstract interface class DogSaveService {
  Future<DogState?> load();
  Future<void> save(DogState state);
}

class SharedPreferencesDogSaveService implements DogSaveService {
  static const _stateKey = 'dog_state_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<DogState?> load() async {
    final encoded = await _preferences.getString(_stateKey);
    if (encoded == null) return null;
    try {
      return DogState.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(DogState state) =>
      _preferences.setString(_stateKey, jsonEncode(state.toJson()));
}
