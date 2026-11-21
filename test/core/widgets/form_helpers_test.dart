import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planova/core/widgets/effort_field.dart';
import 'package:planova/core/widgets/near_limit_counter.dart';

void main() {
  testWidgets('The matching quick effort choice is shown as selected', (
    tester,
  ) async {
    final controller = TextEditingController(text: '60');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EffortField(
            controller: controller,
            fieldKey: 'e',
            label: 'Effort',
            validate: validateEffort,
          ),
        ),
      ),
    );
    bool selected(int minutes) => tester
        .widget<ChoiceChip>(find.byKey(ValueKey('e-quick-$minutes')))
        .selected;
    expect(selected(60), isTrue);
    expect(selected(120), isFalse);
    await tester.tap(find.byKey(const ValueKey('e-quick-120')));
    await tester.pump();
    expect(selected(120), isTrue);
    expect(selected(60), isFalse);
  });

  testWidgets('Counters stay hidden until 80% of the limit', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    Widget? counter(int length) => nearLimitCounter(
      context,
      currentLength: length,
      isFocused: true,
      maxLength: 100,
    );
    expect(counter(5), isNull);
    expect(counter(79), isNull);
    expect(counter(80), isA<Text>());
    expect((counter(100) as Text).data, '100/100');
  });
}
