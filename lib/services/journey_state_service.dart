import 'package:flutter/foundation.dart';

class TaskState {
  final bool isCompleted;
  final bool canClaim;

  TaskState({required this.isCompleted, required this.canClaim});
}

class JourneyStateService extends ChangeNotifier {
  static final JourneyStateService _instance = JourneyStateService._internal();

  factory JourneyStateService() => _instance;

  JourneyStateService._internal();

  Set<int> _activatedButtonIndices = {};
  Map<String, TaskState> _taskStates = {};

  Set<int> get activatedButtonIndices => _activatedButtonIndices;

  int get activatedButtonsCount => _activatedButtonIndices.length;

  Map<String, TaskState> get taskStates => Map.from(_taskStates);

  void updateActivatedButtons(Set<int> indices) {
    _activatedButtonIndices = Set.from(indices);
    notifyListeners();
  }

  void addActivatedButton(int index) {
    _activatedButtonIndices.add(index);
    notifyListeners();
  }

  void clearActivatedButtons() {
    _activatedButtonIndices.clear();
    notifyListeners();
  }

  void initializeTaskStates(Map<String, TaskState> states) {
    _taskStates = Map.from(states);
    notifyListeners();
  }

  void updateTaskState(String taskId, TaskState state) {
    _taskStates[taskId] = state;
    notifyListeners();
  }

  TaskState? getTaskState(String taskId) {
    return _taskStates[taskId];
  }

  bool isTaskCompleted(String taskId) {
    return _taskStates[taskId]?.isCompleted ?? false;
  }

  bool canClaimTask(String taskId) {
    return _taskStates[taskId]?.canClaim ?? false;
  }
}