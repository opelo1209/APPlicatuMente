import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutor_step.dart';

class TutorService extends ChangeNotifier {
  static const String _prefKey = 'tcg_tutorial_completed';

  bool _completed = false;
  bool _active = false;
  int _currentStep = 0;
  List<TutorStep> _steps = [];

  bool get completed => _completed;
  bool get active => _active;
  int get currentStepIndex => _currentStep;
  TutorStep? get currentStep =>
      _steps.isNotEmpty && _currentStep < _steps.length
          ? _steps[_currentStep]
          : null;
  bool get isLastStep => _currentStep >= _steps.length - 1;
  double get progress => _steps.isEmpty ? 0 : (_currentStep / _steps.length);
  int get stepsLength => _steps.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(_prefKey) ?? false;
    notifyListeners();
  }

  void start(List<TutorStep> steps) {
    _steps = steps;
    _currentStep = 0;
    _active = true;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < _steps.length - 1) {
      _currentStep++;
      notifyListeners();
    } else {
      finish();
    }
  }

  Future<void> finish() async {
    _active = false;
    _completed = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    notifyListeners();
  }

  void skip() {
    _active = false;
    notifyListeners();
  }

  Future<void> restart(List<TutorStep> steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    _completed = false;
    start(steps);
  }
}
