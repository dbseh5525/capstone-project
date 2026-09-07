import 'package:flutter/foundation.dart';

import '../models/dog_state.dart';
import '../services/dog_save_service.dart';

enum CareAction { feed, wash, play, sleep }

class DogController extends ChangeNotifier {
  DogController(this._saveService)
    : _state = DogState(lastUpdated: DateTime.now());

  final DogSaveService _saveService;
  DogState _state;
  bool _isLoading = true;
  String _message = '반가워! 오늘도 같이 놀자.';

  DogState get state => _state;
  bool get isLoading => _isLoading;
  String get message => _message;

  Future<void> initialize() async {
    final saved = await _saveService.load();
    if (saved != null) _state = applyOfflineDecay(saved, DateTime.now());
    _isLoading = false;
    notifyListeners();
    await _saveService.save(_state);
  }

  Future<bool> care(CareAction action) async {
    final now = DateTime.now();
    switch (action) {
      case CareAction.feed:
        _state = _state.copyWith(
          hunger: _add(_state.hunger, 24),
          energy: _add(_state.energy, 3),
          affection: _state.affection + 2,
          experience: _state.experience + 12,
          lastUpdated: now,
        );
        _message = '냠냠! 맛있게 잘 먹었어.';
      case CareAction.wash:
        _state = _state.copyWith(
          cleanliness: _add(_state.cleanliness, 30),
          happiness: _add(_state.happiness, 2),
          affection: _state.affection + 2,
          experience: _state.experience + 12,
          lastUpdated: now,
        );
        _message = '보송보송 깨끗해졌어!';
      case CareAction.play:
        if (_state.energy < 10) {
          _message = '지금은 너무 피곤해. 먼저 재워 줘!';
          notifyListeners();
          return false;
        }
        _state = _state.copyWith(
          happiness: _add(_state.happiness, 25),
          energy: _add(_state.energy, -10),
          hunger: _add(_state.hunger, -5),
          affection: _state.affection + 4,
          experience: _state.experience + 18,
          lastUpdated: now,
        );
        _message = '신나게 놀았어! 또 놀자.';
      case CareAction.sleep:
        _state = _state.copyWith(
          energy: _add(_state.energy, 35),
          hunger: _add(_state.hunger, -3),
          affection: _state.affection + 1,
          experience: _state.experience + 8,
          lastUpdated: now,
        );
        _message = '푹 자고 기운이 났어!';
    }
    notifyListeners();
    await _saveService.save(_state);
    return true;
  }

  Future<void> addDebugExperience() async {
    _state = _state.copyWith(
      experience: _state.experience + 100,
      lastUpdated: DateTime.now(),
    );
    _message = '성장 테스트 경험치 +100!';
    notifyListeners();
    await _saveService.save(_state);
  }

  @visibleForTesting
  static DogState applyOfflineDecay(DogState state, DateTime now) {
    final intervals = now.difference(state.lastUpdated).inMinutes ~/ 10;
    if (intervals <= 0) return state.copyWith(lastUpdated: now);
    final capped = intervals.clamp(0, 144);
    return state.copyWith(
      hunger: _add(state.hunger, -2 * capped),
      cleanliness: _add(state.cleanliness, -capped),
      happiness: _add(state.happiness, -capped),
      energy: _add(state.energy, -capped),
      lastUpdated: now,
    );
  }

  static int _add(int value, int delta) => (value + delta).clamp(0, 100);
}
