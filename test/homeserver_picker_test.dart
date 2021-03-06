import 'package:fluffychat/views/homeserver_picker.dart';
import 'package:fluffychat/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test if the widget can be created', (WidgetTester tester) async {
    await tester.pumpWidget(FluffyChatApp(testWidget: HomeserverPicker()));

    await tester.tap(find.byType(TextField));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  });
}
