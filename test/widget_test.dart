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

    expect(find.text('"신규 고객 온보딩" 업무를 시작했습니다.'), findsOneWidget);
    expect(find.text('진행 중 1개'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(5));

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('1/5 완료'), findsOneWidget);
  });

  testWidgets('clears completed runs after confirmation', (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 템플릿으로 시작'));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byType(CheckboxListTile).at(index));
      await tester.pumpAndSettle();
    }

    expect(find.text('완료된 업무 1개'), findsOneWidget);

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

  testWidgets('requires confirmation before deleting a template',
      (tester) async {
    await tester.pumpWidget(const HanassikApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '템플릿'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('템플릿 삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(find.text('신규 고객 온보딩'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('저장된 템플릿이 없습니다'), findsOneWidget);
  });
}
