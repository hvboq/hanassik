import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanassik/hanassik_store.dart';
import 'package:hanassik/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _templatesKey = 'hanassik.templates';
const _runsKey = 'hanassik.runs';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load recovers from corrupted storage JSON without throwing', () async {
    SharedPreferences.setMockInitialValues({
      _templatesKey: '{not valid json',
      _runsKey: '{"not":"a list"}',
    });

    final store = await HanassikStore.load();
    final preferences = await SharedPreferences.getInstance();

    expect(store.recoveredFromStorage, isTrue);
    expect(store.templates, isEmpty);
    expect(store.runs, isEmpty);
    expect(preferences.getString(_templatesKey), '[]');
    expect(preferences.getString(_runsKey), '[]');
  });

  test('load keeps valid templates and skips invalid template entries',
      () async {
    SharedPreferences.setMockInitialValues({
      _templatesKey: jsonEncode([
        {
          'id': 'valid',
          'title': '  유효한 템플릿  ',
          'steps': ['  첫 번째  ', '', '두 번째'],
        },
        {
          'id': 'empty-title',
          'title': ' ',
          'steps': ['단계'],
        },
        {
          'id': 'empty-steps',
          'title': '빈 단계',
          'steps': [' ', ''],
        },
        'not a map',
      ]),
      _runsKey: '[]',
    });

    final store = await HanassikStore.load();

    expect(store.recoveredFromStorage, isTrue);
    expect(store.templates, hasLength(1));
    expect(store.templates.first.id, 'valid');
    expect(store.templates.first.title, '유효한 템플릿');
    expect(store.templates.first.steps, ['첫 번째', '두 번째']);
  });

  test('load repairs run checked lengths and trims text', () async {
    SharedPreferences.setMockInitialValues({
      _templatesKey: '[]',
      _runsKey: jsonEncode([
        {
          'id': 'short',
          'templateTitle': '  짧은 체크  ',
          'steps': ['  첫 번째  ', '두 번째', '세 번째'],
          'checked': [true],
          'startedAt': '2026-06-24T00:00:00.000Z',
        },
        {
          'id': 'long',
          'templateTitle': '긴 체크',
          'steps': ['하나'],
          'checked': [false, true],
          'startedAt': '2026-06-24T00:00:00.000Z',
        },
      ]),
    });

    final store = await HanassikStore.load();

    expect(store.recoveredFromStorage, isTrue);
    expect(store.runs, hasLength(2));
    expect(store.runs[0].templateTitle, '짧은 체크');
    expect(store.runs[0].steps, ['첫 번째', '두 번째', '세 번째']);
    expect(store.runs[0].checked, [true, false, false]);
    expect(store.runs[1].checked, [false]);
  });

  test('default template is not seeded again after templates are deleted',
      () async {
    final firstLoad = await HanassikStore.load();

    expect(firstLoad.templates, isNotEmpty);

    for (final template in List<WorkTemplate>.from(firstLoad.templates)) {
      await firstLoad.deleteTemplate(template.id);
    }

    expect(firstLoad.templates, isEmpty);

    final secondLoad = await HanassikStore.load();

    expect(secondLoad.templates, isEmpty);
    expect(secondLoad.recoveredFromStorage, isFalse);
  });

  test('updateTemplate edits an existing template in place', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);

    await store.addTemplate('기존 템플릿', ['첫 번째']);

    final originalId = store.templates.single.id;

    final updated = await store.updateTemplate(
      originalId,
      '  수정한 템플릿  ',
      ['', '  새 첫 번째  ', '새 두 번째'],
    );

    expect(updated, isTrue);
    expect(store.templates, hasLength(1));
    expect(store.templates.single.id, originalId);
    expect(store.templates.single.title, '수정한 템플릿');
    expect(store.templates.single.steps, ['새 첫 번째', '새 두 번째']);

    final missingUpdate = await store.updateTemplate(
      'missing',
      '없는 템플릿',
      ['단계'],
    );
    final invalidUpdate = await store.updateTemplate(
      originalId,
      ' ',
      ['단계'],
    );

    expect(missingUpdate, isFalse);
    expect(invalidUpdate, isFalse);
    expect(store.templates.single.title, '수정한 템플릿');
  });

  test('addTemplate and startRun apply storage limits', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);
    final longTitle = _repeat('제목', 60);
    final longStep = _repeat('단계', 100);
    final manySteps = List<String>.generate(
      25,
      (index) => ' $longStep $index ',
    );

    await store.addTemplate(' $longTitle ', ['', '   ', ...manySteps]);

    expect(store.templates, hasLength(1));
    expect(store.templates.first.title.length, HanassikStore.maxTitleLength);
    expect(store.templates.first.steps,
        hasLength(HanassikStore.maxStepsPerTemplate));
    expect(
      store.templates.first.steps.every(
        (step) =>
            step.isNotEmpty &&
            step == step.trim() &&
            step.length <= HanassikStore.maxStepLength,
      ),
      isTrue,
    );

    await store.addTemplate('   ', ['유효한 단계']);
    await store.addTemplate('빈 단계', [' ', '']);

    expect(store.templates, hasLength(1));

    for (var index = 0; index < 105; index++) {
      await store.addTemplate('템플릿 $index', ['단계 $index']);
    }

    expect(store.templates, hasLength(HanassikStore.maxSavedTemplates));

    await store.startRun(
      WorkTemplate(id: 'dirty', title: ' $longTitle ', steps: manySteps),
    );

    expect(store.runs.first.templateTitle.length, HanassikStore.maxTitleLength);
    expect(
        store.runs.first.steps, hasLength(HanassikStore.maxStepsPerTemplate));
    expect(
        store.runs.first.checked, hasLength(HanassikStore.maxStepsPerTemplate));

    for (var index = 0; index < 105; index++) {
      await store.startRun(
        WorkTemplate(id: 'run-$index', title: '진행 $index', steps: ['단계']),
      );
    }

    expect(store.runs, hasLength(HanassikStore.maxSavedRuns));

    await store.startRun(
      WorkTemplate(id: 'bad-title', title: ' ', steps: ['단계']),
    );
    await store.startRun(
      WorkTemplate(id: 'bad-steps', title: '진행', steps: [' ', '']),
    );

    expect(store.runs, hasLength(HanassikStore.maxSavedRuns));
  });

  test('deleteCompletedRuns removes only completed runs', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);

    await store.startRun(
      WorkTemplate(id: 'done', title: '완료 업무', steps: ['마무리']),
    );
    await store.startRun(
      WorkTemplate(id: 'active', title: '진행 업무', steps: ['확인']),
    );

    final doneRun = store.runs.firstWhere(
      (run) => run.templateTitle == '완료 업무',
    );
    await store.toggleStep(doneRun.id, 0, true);

    final deletedCount = await store.deleteCompletedRuns();

    expect(deletedCount, 1);
    expect(store.runs, hasLength(1));
    expect(store.runs.single.templateTitle, '진행 업무');
    expect(store.runs.single.isDone, isFalse);

    final secondDeleteCount = await store.deleteCompletedRuns();

    expect(secondDeleteCount, 0);
    expect(store.runs, hasLength(1));
  });

  test('toggleStep records and clears run end time', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = HanassikStore(preferences);
    await store.startRun(
      WorkTemplate(id: 'timed', title: '시간 기록 업무', steps: ['마무리']),
    );

    final runId = store.runs.single.id;

    await store.toggleStep(runId, 0, true);

    expect(store.runs.single.isDone, isTrue);
    expect(store.runs.single.endedAt, isNotNull);

    final savedRuns = jsonDecode(preferences.getString(_runsKey)!) as List;
    expect(savedRuns.single, contains('endedAt'));
    expect(savedRuns.single['endedAt'], isA<String>());

    await store.toggleStep(runId, 0, false);

    expect(store.runs.single.isDone, isFalse);
    expect(store.runs.single.endedAt, isNull);
  });

  test('WorkRun exposes remaining count and next unchecked step', () {
    final run = WorkRun(
      id: 'run',
      templateTitle: '점검',
      steps: ['첫 번째', '두 번째', '세 번째'],
      checked: [true, false, false],
      startedAt: DateTime(2026, 6, 24),
    );

    expect(run.completedCount, 1);
    expect(run.remainingCount, 2);
    expect(run.nextUncheckedIndex, 1);

    final doneRun = run.copyWith(checked: [true, true, true]);

    expect(doneRun.remainingCount, 0);
    expect(doneRun.nextUncheckedIndex, isNull);
  });
}

String _repeat(String value, int count) {
  return List<String>.filled(count, value).join();
}
