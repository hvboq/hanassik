import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanassik/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts a checklist run from a saved template', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    expect(find.text('진행 중인 업무가 없습니다'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    expect(find.text('신규 고객 온보딩'), findsOneWidget);

    await tester.tap(find.text('이 템플릿으로 시작'));
    await tester.pumpAndSettle();
    expect(find.text('진행 업무 시작'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '업무 제목'), findsOneWidget);

    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();

    expect(find.text('"신규 고객 온보딩" 업무를 시작했습니다.'), findsOneWidget);
    expect(find.text('현재 진행 상황'), findsOneWidget);
    expect(find.text('템플릿: 신규 고객 온보딩'), findsOneWidget);
    expect(find.text('남은 항목 5개'), findsOneWidget);
    expect(find.text('다음 할 일'), findsOneWidget);
    expect(find.text('진행 중 1개'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.endsWith(' 시작') ?? false),
      ),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNWidgets(5));

    await tester.tap(find.text('다음 항목 완료'));
    await tester.pumpAndSettle();

    expect(find.text('1/5 완료'), findsOneWidget);
    expect(find.text('남은 항목 4개'), findsOneWidget);
  });

  testWidgets('clears completed runs after confirmation', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 템플릿으로 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text('다음 항목 완료'));
      await tester.pumpAndSettle();
    }

    expect(find.text('완료된 업무 1개'), findsOneWidget);
    expect(find.textContaining('종료'), findsOneWidget);

    await tester.tap(find.text('완료 기록 정리'));
    await tester.pumpAndSettle();

    expect(find.text('완료된 업무 삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('완료된 업무 1개'), findsOneWidget);

    await tester.tap(find.text('완료 기록 정리'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('완료된 업무 1개'), findsNothing);
    expect(find.text('진행 중인 업무가 없습니다'), findsOneWidget);
    expect(find.text('완료된 업무 1개를 삭제했습니다.'), findsOneWidget);
  });

  testWidgets('shows a recovery notice for corrupted local data',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'hanassik.hasSeededDefaults': true,
      'hanassik.templates': 'not-json',
    });

    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    expect(find.text('일부 저장 데이터가 손상되어 사용할 수 있는 항목만 복구했습니다.'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('일부 저장 데이터가 손상되어 사용할 수 있는 항목만 복구했습니다.'), findsNothing);
  });

  testWidgets('starts a run with a custom title and note', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 템플릿으로 시작'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '업무 제목'),
      '김하나 고객 온보딩',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '메모'),
      '계약서 확인 후 담당자에게 공유',
    );
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();

    expect(find.text('"김하나 고객 온보딩" 업무를 시작했습니다.'), findsOneWidget);
    expect(find.text('김하나 고객 온보딩'), findsOneWidget);
    expect(find.text('템플릿: 신규 고객 온보딩'), findsOneWidget);
    expect(find.text('계약서 확인 후 담당자에게 공유'), findsOneWidget);
  });

  testWidgets('edits an active run title and note', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 템플릿으로 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('업무 정보 수정'));
    await tester.pumpAndSettle();

    expect(find.text('진행 업무 수정'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '업무 제목'),
      '김하나 고객 재방문',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '메모'),
      '오전 방문 후 사진 첨부 예정',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('"김하나 고객 재방문" 업무 정보를 수정했습니다.'), findsOneWidget);
    expect(find.text('김하나 고객 재방문'), findsOneWidget);
    expect(find.text('오전 방문 후 사진 첨부 예정'), findsOneWidget);
    expect(find.text('진행 업무 수정'), findsNothing);
  });

  testWidgets('creates a custom template', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('템플릿 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, '템플릿 이름'), '월말 정산');
    await tester.enterText(
        find.widgetWithText(TextFormField, '체크 항목 1'), '자료 수집');
    await tester.enterText(
        find.widgetWithText(TextFormField, '체크 항목 2'), '금액 대조');
    await tester.enterText(
        find.widgetWithText(TextFormField, '체크 항목 3'), '보고서 공유');

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    expect(find.text('월말 정산'), findsOneWidget);
    expect(find.text('1. 자료 수집'), findsOneWidget);
    expect(find.text('2. 금액 대조'), findsOneWidget);
    expect(find.text('3. 보고서 공유'), findsOneWidget);
  });

  testWidgets('keeps the template sheet below the top safe area',
      (tester) async {
    const topSafeArea = 44.0;
    final topSafeAreaInPhysicalPixels =
        topSafeArea * tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(top: topSafeAreaInPhysicalPixels);
    tester.view.viewPadding = FakeViewPadding(top: topSafeAreaInPhysicalPixels);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('템플릿 만들기'));
    await tester.pumpAndSettle();

    final sheetTop = tester.getTopLeft(find.text('업무 템플릿 만들기')).dy;

    expect(sheetTop, greaterThanOrEqualTo(topSafeArea));
  });

  testWidgets('saves a template when any checklist item has text',
      (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('템플릿 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, '템플릿 이름'), '첫 칸 비움');
    await tester.enterText(
        find.widgetWithText(TextFormField, '체크 항목 2'), '두 번째 항목');

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    expect(find.text('첫 칸 비움'), findsOneWidget);
    expect(find.text('1. 두 번째 항목'), findsOneWidget);
    expect(find.text('최소 1개 항목이 필요합니다.'), findsNothing);
  });

  testWidgets('removes checklist item fields while creating a template',
      (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('템플릿 만들기'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '체크 항목 3'), findsOneWidget);

    await tester.tap(find.byTooltip('항목 삭제').at(1));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '체크 항목 1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '체크 항목 2'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '체크 항목 3'), findsNothing);
  });

  testWidgets('edits an existing template', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('수정'));
    await tester.pumpAndSettle();

    expect(find.text('업무 템플릿 수정'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '템플릿 이름'),
      '수정된 온보딩',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '체크 항목 1'),
      '수정된 첫 단계',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final updateButton = find.widgetWithText(FilledButton, '수정');
    await tester.ensureVisible(updateButton);
    await tester.pumpAndSettle();
    await tester.tap(updateButton);
    await tester.pumpAndSettle();

    expect(find.text('수정된 온보딩'), findsOneWidget);
    expect(find.text('1. 수정된 첫 단계'), findsOneWidget);
    expect(find.text('신규 고객 온보딩'), findsNothing);
  });

  testWidgets('requires confirmation before deleting a template',
      (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    final templateDismissible = find.ancestor(
      of: find.text('신규 고객 온보딩'),
      matching: find.byType(Dismissible),
    );

    await tester.drag(templateDismissible, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('템플릿 삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('신규 고객 온보딩'), findsOneWidget);

    await tester.drag(templateDismissible, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('저장된 템플릿이 없습니다'), findsOneWidget);
  });
}
