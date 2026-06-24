import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HanassikStore extends ChangeNotifier {
  static const _templatesKey = 'hanassik.templates';
  static const _runsKey = 'hanassik.runs';

  HanassikStore(this._preferences);

  final SharedPreferences _preferences;
  final List<WorkTemplate> templates = [];
  final List<WorkRun> runs = [];

  static Future<HanassikStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);
    store._loadTemplates();
    store._loadRuns();

    if (store.templates.isEmpty) {
      store.templates.add(
        WorkTemplate(
          id: _newId(),
          title: '신규 고객 온보딩',
          steps: [
            '고객 요청 내용 확인',
            '필요 자료 체크',
            '담당자 배정',
            '진행 상태 공유',
            '완료 후 결과 기록',
          ],
        ),
      );
      await store._saveTemplates();
    }

    return store;
  }

  Future<void> addTemplate(String title, List<String> steps) async {
    templates.insert(
      0,
      WorkTemplate(id: _newId(), title: title, steps: steps),
    );
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    templates.removeWhere((template) => template.id == id);
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> startRun(WorkTemplate template) async {
    runs.insert(
      0,
      WorkRun(
        id: _newId(),
        templateTitle: template.title,
        steps: List<String>.from(template.steps),
        checked: List<bool>.filled(template.steps.length, false),
        startedAt: DateTime.now(),
      ),
    );
    await _saveRuns();
    notifyListeners();
  }

  Future<void> toggleStep(String runId, int index, bool value) async {
    final runIndex = runs.indexWhere((run) => run.id == runId);
    if (runIndex == -1 || index < 0 || index >= runs[runIndex].checked.length) {
      return;
    }

    final checked = List<bool>.from(runs[runIndex].checked);
    checked[index] = value;
    runs[runIndex] = runs[runIndex].copyWith(checked: checked);
    await _saveRuns();
    notifyListeners();
  }

  Future<void> deleteRun(String id) async {
    runs.removeWhere((run) => run.id == id);
    await _saveRuns();
    notifyListeners();
  }

  void _loadTemplates() {
    final raw = _preferences.getString(_templatesKey);
    if (raw == null) {
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    templates
      ..clear()
      ..addAll(
        decoded.map(
          (item) => WorkTemplate.fromJson(item as Map<String, dynamic>),
        ),
      );
  }

  void _loadRuns() {
    final raw = _preferences.getString(_runsKey);
    if (raw == null) {
      return;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    runs
      ..clear()
      ..addAll(
        decoded.map(
          (item) => WorkRun.fromJson(item as Map<String, dynamic>),
        ),
      );
  }

  Future<void> _saveTemplates() async {
    await _preferences.setString(
      _templatesKey,
      jsonEncode(templates.map((template) => template.toJson()).toList()),
    );
  }

  Future<void> _saveRuns() async {
    await _preferences.setString(
      _runsKey,
      jsonEncode(runs.map((run) => run.toJson()).toList()),
    );
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
