import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HanassikStore extends ChangeNotifier {
  static const _templatesKey = 'hanassik.templates';
  static const _runsKey = 'hanassik.runs';
  static const _hasSeededDefaultsKey = 'hanassik.hasSeededDefaults';

  static const maxTitleLength = 80;
  static const maxStepLength = 160;
  static const maxRunNoteLength = 1000;
  static const maxAttachmentNameLength = 120;
  static const maxStepsPerTemplate = 20;
  static const maxAttachmentsPerRun = 5;
  static const maxAttachmentBytes = 2 * 1024 * 1024;
  static const maxSavedTemplates = 100;
  static const maxSavedRuns = 100;

  HanassikStore(this._preferences);

  final SharedPreferences _preferences;
  final List<WorkTemplate> templates = [];
  final List<WorkRun> runs = [];
  bool recoveredFromStorage = false;

  static Future<HanassikStore> load() async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);
    final hasSeededDefaults =
        preferences.getBool(_hasSeededDefaultsKey) ?? false;
    final hasStoredTemplates = preferences.containsKey(_templatesKey);
    final recoveredTemplates = store._loadTemplates();
    final recoveredRuns = store._loadRuns();
    store.recoveredFromStorage = recoveredTemplates || recoveredRuns;

    if (!hasSeededDefaults && !hasStoredTemplates) {
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
    if (!hasSeededDefaults) {
      await preferences.setBool(_hasSeededDefaultsKey, true);
    }

    if (recoveredTemplates) {
      await store._saveTemplates();
    }
    if (recoveredRuns) {
      await store._saveRuns();
    }

    return store;
  }

  Future<void> addTemplate(String title, List<String> steps) async {
    final template = _buildTemplate(title: title, steps: steps);
    if (template == null) {
      return;
    }

    final nextTemplates = [
      template,
      ...templates,
    ].take(maxSavedTemplates).toList();

    await _saveTemplates(nextTemplates);
    templates
      ..clear()
      ..addAll(nextTemplates);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    final nextTemplates =
        templates.where((template) => template.id != id).toList();
    if (nextTemplates.length == templates.length) {
      return;
    }

    await _saveTemplates(nextTemplates);
    templates
      ..clear()
      ..addAll(nextTemplates);
    notifyListeners();
  }

  Future<bool> updateTemplate(
    String id,
    String title,
    List<String> steps,
  ) async {
    final templateIndex = templates.indexWhere((template) => template.id == id);
    if (templateIndex == -1) {
      return false;
    }

    final template = _buildTemplate(title: title, steps: steps, id: id);
    if (template == null) {
      return false;
    }

    final nextTemplates = List<WorkTemplate>.from(templates);
    nextTemplates[templateIndex] = template;

    await _saveTemplates(nextTemplates);
    templates
      ..clear()
      ..addAll(nextTemplates);
    notifyListeners();
    return true;
  }

  Future<void> startRun(
    WorkTemplate template, {
    String? title,
    String note = '',
  }) async {
    final normalizedTemplate = _buildTemplate(
      title: template.title,
      steps: template.steps,
      id: template.id,
    );
    if (normalizedTemplate == null) {
      return;
    }

    final normalizedTitle = _normalizeOptionalText(title, maxTitleLength) ??
        normalizedTemplate.title;
    final normalizedNote = _normalizeOptionalText(note, maxRunNoteLength) ?? '';

    final nextRuns = [
      WorkRun(
        id: _newId(),
        title: normalizedTitle,
        templateTitle: normalizedTemplate.title,
        note: normalizedNote,
        steps: List<String>.from(normalizedTemplate.steps),
        checked: List<bool>.filled(normalizedTemplate.steps.length, false),
        startedAt: DateTime.now(),
      ),
      ...runs,
    ].take(maxSavedRuns).toList();

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
  }

  Future<bool> updateRunDetails(
    String runId, {
    required String title,
    required String note,
  }) async {
    final runIndex = runs.indexWhere((run) => run.id == runId);
    if (runIndex == -1 || runs[runIndex].isDone) {
      return false;
    }

    final normalizedTitle = _normalizeRequiredText(title, maxTitleLength);
    if (normalizedTitle == null) {
      return false;
    }
    final normalizedNote = _normalizeOptionalText(note, maxRunNoteLength) ?? '';

    final nextRuns = List<WorkRun>.from(runs);
    nextRuns[runIndex] = runs[runIndex].copyWith(
      title: normalizedTitle.value,
      note: normalizedNote,
    );

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
    return true;
  }

  Future<void> toggleStep(String runId, int index, bool value) async {
    final runIndex = runs.indexWhere((run) => run.id == runId);
    if (runIndex == -1 || index < 0 || index >= runs[runIndex].checked.length) {
      return;
    }

    final checked = List<bool>.from(runs[runIndex].checked);
    checked[index] = value;

    final wasDone = runs[runIndex].isDone;
    final updatedRun = runs[runIndex].copyWith(checked: checked);
    final nextRuns = List<WorkRun>.from(runs);
    nextRuns[runIndex] = updatedRun.isDone
        ? updatedRun.copyWith(
            endedAt: wasDone ? runs[runIndex].endedAt : DateTime.now(),
          )
        : updatedRun.copyWith(clearEndedAt: true);

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
  }

  Future<bool> addAttachments(
    String runId,
    List<WorkAttachment> attachments,
  ) async {
    final runIndex = runs.indexWhere((run) => run.id == runId);
    if (runIndex == -1 || attachments.isEmpty) {
      return false;
    }

    final run = runs[runIndex];
    final remainingSlots = maxAttachmentsPerRun - run.attachments.length;
    if (remainingSlots <= 0) {
      return false;
    }

    final normalizedAttachments = <WorkAttachment>[];
    final seenIds = {
      for (final attachment in run.attachments) attachment.id,
    };
    for (final attachment in attachments) {
      if (normalizedAttachments.length == remainingSlots) {
        break;
      }

      final normalized = _normalizeAttachment(attachment, seenIds);
      if (normalized == null) {
        continue;
      }
      normalizedAttachments.add(normalized.value);
    }

    if (normalizedAttachments.isEmpty) {
      return false;
    }

    final nextRuns = List<WorkRun>.from(runs);
    nextRuns[runIndex] = run.copyWith(
      attachments: [
        ...run.attachments,
        ...normalizedAttachments,
      ],
    );

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
    return true;
  }

  Future<bool> removeAttachment(String runId, String attachmentId) async {
    final runIndex = runs.indexWhere((run) => run.id == runId);
    if (runIndex == -1) {
      return false;
    }

    final run = runs[runIndex];
    final nextAttachments = run.attachments
        .where((attachment) => attachment.id != attachmentId)
        .toList();
    if (nextAttachments.length == run.attachments.length) {
      return false;
    }

    final nextRuns = List<WorkRun>.from(runs);
    nextRuns[runIndex] = run.copyWith(attachments: nextAttachments);

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
    return true;
  }

  Future<void> deleteRun(String id) async {
    final nextRuns = runs.where((run) => run.id != id).toList();
    if (nextRuns.length == runs.length) {
      return;
    }

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
  }

  Future<int> deleteCompletedRuns() async {
    final nextRuns = runs.where((run) => !run.isDone).toList();
    final deletedCount = runs.length - nextRuns.length;
    if (deletedCount == 0) {
      return 0;
    }

    await _saveRuns(nextRuns);
    runs
      ..clear()
      ..addAll(nextRuns);
    notifyListeners();
    return deletedCount;
  }

  void dismissRecoveryNotice() {
    if (!recoveredFromStorage) {
      return;
    }

    recoveredFromStorage = false;
    notifyListeners();
  }

  bool _loadTemplates() {
    final raw = _preferences.getString(_templatesKey);
    if (raw == null) {
      return false;
    }

    final decoded = _decodeList(raw);
    if (decoded == null) {
      templates.clear();
      return true;
    }

    var recovered = false;
    final loadedTemplates = <WorkTemplate>[];
    final seenIds = <String>{};
    for (final item in decoded) {
      final template = _templateFromStorage(item, seenIds);
      if (template == null) {
        recovered = true;
        continue;
      }
      recovered = recovered || template.recovered;
      loadedTemplates.add(template.value);
    }
    if (loadedTemplates.length > maxSavedTemplates) {
      loadedTemplates.removeRange(maxSavedTemplates, loadedTemplates.length);
      recovered = true;
    }

    templates
      ..clear()
      ..addAll(loadedTemplates);
    return recovered;
  }

  bool _loadRuns() {
    final raw = _preferences.getString(_runsKey);
    if (raw == null) {
      return false;
    }

    final decoded = _decodeList(raw);
    if (decoded == null) {
      runs.clear();
      return true;
    }

    var recovered = false;
    final loadedRuns = <WorkRun>[];
    final seenIds = <String>{};
    for (final item in decoded) {
      final run = _runFromStorage(item, seenIds);
      if (run == null) {
        recovered = true;
        continue;
      }
      recovered = recovered || run.recovered;
      loadedRuns.add(run.value);
    }
    if (loadedRuns.length > maxSavedRuns) {
      loadedRuns.removeRange(maxSavedRuns, loadedRuns.length);
      recovered = true;
    }

    runs
      ..clear()
      ..addAll(loadedRuns);
    return recovered;
  }

  Future<void> _saveTemplates([List<WorkTemplate>? value]) async {
    final saved = await _preferences.setString(
      _templatesKey,
      jsonEncode(
        (value ?? templates).map((template) => template.toJson()).toList(),
      ),
    );
    if (!saved) {
      throw StateError('템플릿 저장에 실패했습니다.');
    }
    await _preferences.setBool(_hasSeededDefaultsKey, true);
  }

  Future<void> _saveRuns([List<WorkRun>? value]) async {
    final saved = await _preferences.setString(
      _runsKey,
      jsonEncode((value ?? runs).map((run) => run.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('진행 업무 저장에 실패했습니다.');
    }
  }

  static List<dynamic>? _decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded;
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  static _StorageItem<WorkTemplate>? _templateFromStorage(
    Object? item,
    Set<String> seenIds,
  ) {
    final json = _asStringKeyedMap(item);
    if (json == null) {
      return null;
    }

    final steps = json['steps'];
    if (steps is! List) {
      return null;
    }

    return _buildTemplateItem(
      title: json['title'],
      steps: steps,
      id: json['id'],
      seenIds: seenIds,
    );
  }

  static _StorageItem<WorkRun>? _runFromStorage(
    Object? item,
    Set<String> seenIds,
  ) {
    final json = _asStringKeyedMap(item);
    if (json == null) {
      return null;
    }

    final rawSteps = json['steps'];
    if (rawSteps is! List) {
      return null;
    }

    var recovered = false;

    final id = _normalizeId(json['id'], seenIds);
    recovered = recovered || id.recovered;

    final templateTitle = _normalizeRequiredText(
      json['templateTitle'],
      maxTitleLength,
    );
    if (templateTitle == null) {
      return null;
    }
    recovered = recovered || templateTitle.recovered;

    final rawTitle = json.containsKey('title') ? json['title'] : null;
    final title = _normalizeOptionalText(rawTitle, maxTitleLength);
    recovered = recovered || rawTitle is String && rawTitle.trim() != title;
    if (rawTitle != null && rawTitle is! String) {
      recovered = true;
    }

    final rawNote = json.containsKey('note') ? json['note'] : null;
    final note = _normalizeOptionalText(rawNote, maxRunNoteLength);
    recovered = recovered || rawNote is String && rawNote.trim() != note;
    if (rawNote != null && rawNote is! String) {
      recovered = true;
    }

    final rawChecked = json['checked'];
    final checkedSource = rawChecked is List ? rawChecked : const <dynamic>[];
    if (rawChecked is! List) {
      recovered = true;
    }

    final steps = <String>[];
    final checked = <bool>[];

    for (var index = 0; index < rawSteps.length; index++) {
      final step = _normalizeRequiredText(rawSteps[index], maxStepLength);
      if (step == null) {
        recovered = true;
        continue;
      }

      if (steps.length == maxStepsPerTemplate) {
        recovered = true;
        continue;
      }

      steps.add(step.value);
      recovered = recovered || step.recovered;

      final checkedValue =
          index < checkedSource.length ? checkedSource[index] : null;
      if (checkedValue is bool) {
        checked.add(checkedValue);
      } else {
        checked.add(false);
        recovered = true;
      }
    }

    if (steps.isEmpty) {
      return null;
    }

    if (checkedSource.length > rawSteps.length) {
      recovered = true;
    }

    final startedAt = _normalizeStartedAt(json['startedAt']);
    recovered = recovered || startedAt.recovered;
    final endedAt = _normalizeEndedAt(json['endedAt']);
    recovered = recovered || endedAt.recovered;
    final attachments = _normalizeAttachments(json['attachments']);
    recovered = recovered || attachments.recovered;

    return _StorageItem(
      WorkRun(
        id: id.value,
        title: title ?? templateTitle.value,
        templateTitle: templateTitle.value,
        note: note ?? '',
        steps: steps,
        checked: checked,
        attachments: attachments.values,
        startedAt: startedAt.value,
        endedAt: endedAt.value,
      ),
      recovered,
    );
  }

  static WorkTemplate? _buildTemplate({
    required String title,
    required List<String> steps,
    String? id,
  }) {
    return _buildTemplateItem(
      title: title,
      steps: steps,
      id: id,
      seenIds: <String>{},
    )?.value;
  }

  static _StorageItem<WorkTemplate>? _buildTemplateItem({
    required Object? title,
    required List<dynamic> steps,
    required Object? id,
    required Set<String> seenIds,
  }) {
    var recovered = false;

    final normalizedTitle = _normalizeRequiredText(title, maxTitleLength);
    if (normalizedTitle == null) {
      return null;
    }
    recovered = recovered || normalizedTitle.recovered;

    final normalizedSteps = _normalizeSteps(steps);
    if (normalizedSteps.values.isEmpty) {
      return null;
    }
    recovered = recovered || normalizedSteps.recovered;

    final normalizedId = _normalizeId(id, seenIds);
    recovered = recovered || normalizedId.recovered;

    return _StorageItem(
      WorkTemplate(
        id: normalizedId.value,
        title: normalizedTitle.value,
        steps: normalizedSteps.values,
      ),
      recovered,
    );
  }

  static _StorageList<String> _normalizeSteps(List<dynamic> rawSteps) {
    var recovered = false;
    final steps = <String>[];

    for (final rawStep in rawSteps) {
      final step = _normalizeRequiredText(rawStep, maxStepLength);
      if (step == null) {
        recovered = true;
        continue;
      }

      if (steps.length == maxStepsPerTemplate) {
        recovered = true;
        continue;
      }

      steps.add(step.value);
      recovered = recovered || step.recovered;
    }

    return _StorageList(steps, recovered);
  }

  static _StorageList<WorkAttachment> _normalizeAttachments(Object? raw) {
    if (raw == null) {
      return const _StorageList(<WorkAttachment>[], false);
    }
    if (raw is! List) {
      return const _StorageList(<WorkAttachment>[], true);
    }

    var recovered = false;
    final attachments = <WorkAttachment>[];
    final seenIds = <String>{};
    for (final item in raw) {
      final json = _asStringKeyedMap(item);
      if (json == null) {
        recovered = true;
        continue;
      }

      if (attachments.length == maxAttachmentsPerRun) {
        recovered = true;
        continue;
      }

      final attachment = _normalizeAttachment(
        WorkAttachment.fromJson(json),
        seenIds,
      );
      if (attachment == null) {
        recovered = true;
        continue;
      }

      attachments.add(attachment.value);
      recovered = recovered || attachment.recovered;
    }

    return _StorageList(attachments, recovered);
  }

  static _StorageItem<WorkAttachment>? _normalizeAttachment(
    WorkAttachment attachment,
    Set<String> seenIds,
  ) {
    var recovered = false;

    final id = _normalizeId(attachment.id, seenIds);
    recovered = recovered || id.recovered;

    final name = _normalizeRequiredText(
      attachment.name,
      maxAttachmentNameLength,
    );
    if (name == null) {
      return null;
    }
    recovered = recovered || name.recovered;

    final dataBase64 = attachment.dataBase64.trim();
    if (dataBase64.isEmpty) {
      return null;
    }
    recovered = recovered || dataBase64 != attachment.dataBase64;

    try {
      final bytes = base64Decode(dataBase64);
      if (bytes.isEmpty || bytes.lengthInBytes > maxAttachmentBytes) {
        return null;
      }
    } on FormatException {
      return null;
    }

    final mimeType = attachment.mimeType?.trim();
    recovered = recovered || mimeType != attachment.mimeType;

    return _StorageItem(
      attachment.copyWith(
        id: id.value,
        name: name.value,
        dataBase64: dataBase64,
        mimeType: mimeType == null || mimeType.isEmpty ? null : mimeType,
      ),
      recovered,
    );
  }

  static _StorageItem<String> _normalizeId(
    Object? raw,
    Set<String> seenIds,
  ) {
    var recovered = false;
    var id = '';

    if (raw is String) {
      id = raw.trim();
      recovered = id != raw;
    } else {
      recovered = true;
    }

    if (id.isEmpty || seenIds.contains(id)) {
      recovered = true;
      do {
        id = _newId();
      } while (seenIds.contains(id));
    }

    seenIds.add(id);
    return _StorageItem(id, recovered);
  }

  static _StorageItem<String>? _normalizeRequiredText(
    Object? raw,
    int maxLength,
  ) {
    if (raw is! String) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final limited =
        trimmed.length > maxLength ? trimmed.substring(0, maxLength) : trimmed;
    return _StorageItem(limited, raw != limited);
  }

  static String? _normalizeOptionalText(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }

  static _StorageItem<DateTime> _normalizeStartedAt(Object? raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return _StorageItem(parsed, false);
      }
    }

    return _StorageItem(DateTime.now(), true);
  }

  static _StorageItem<DateTime?> _normalizeEndedAt(Object? raw) {
    if (raw == null) {
      return const _StorageItem(null, false);
    }

    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return _StorageItem(parsed, false);
      }
    }

    return const _StorageItem(null, true);
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? item) {
    if (item is! Map) {
      return null;
    }

    final mapped = <String, dynamic>{};
    for (final entry in item.entries) {
      final key = entry.key;
      if (key is! String) {
        return null;
      }
      mapped[key] = entry.value;
    }
    return mapped;
  }

  static final Random _random = Random.secure();
  static int _idSequence = 0;

  static String _newId() {
    _idSequence = (_idSequence + 1) % 1000000;
    final randomPart = _random.nextInt(0x3fffffff).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}-$_idSequence-$randomPart';
  }
}

class _StorageItem<T> {
  const _StorageItem(this.value, this.recovered);

  final T value;
  final bool recovered;
}

class _StorageList<T> {
  const _StorageList(this.values, this.recovered);

  final List<T> values;
  final bool recovered;
}
