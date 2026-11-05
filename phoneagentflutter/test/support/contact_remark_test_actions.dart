import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/presentation/pages/contact_detail_page.dart';

/// Exercises retained editor/deletion behavior without reintroducing hidden UI.
Future<void> openRetainedRemarkEditor(WidgetTester tester) async {
  tester.widget<ContactDetailPage>(find.byType(ContactDetailPage)).onEdit();
  await tester.pumpAndSettle();
}

Future<void> requestRetainedRemarkDeletion(WidgetTester tester) async {
  final callback = tester
      .widget<ContactDetailPage>(find.byType(ContactDetailPage))
      .onDelete;
  expect(callback, isNotNull);
  callback!();
  await tester.pumpAndSettle();
}
