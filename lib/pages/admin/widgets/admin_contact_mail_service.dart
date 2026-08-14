import '../../../services/firebase_functions_region.dart';
import 'admin_contact_mail_models.dart';

class AdminContactMailService {
  const AdminContactMailService();

  Future<AdminContactInboxSummary> loadSummary() async {
    final result = await callPrestoFunction<dynamic>(
      functions: prestoFirebaseFunctions,
      name: 'adminGetInboundMailboxSummary',
      timeout: const Duration(seconds: 15),
      area: 'admin-inbox',
    );
    return AdminContactInboxSummary.fromDynamic(result.data);
  }

  Future<List<AdminContactMailItem>> listEmails({int limit = 30}) async {
    final result = await callPrestoFunction<dynamic>(
      functions: prestoFirebaseFunctions,
      name: 'adminListInboundEmails',
      timeout: const Duration(seconds: 20),
      parameters: {'limit': limit},
      area: 'admin-inbox',
    );
    final data = adminContactAsStringMap(result.data);
    final rawItems = data['items'];
    if (rawItems is! List) return const <AdminContactMailItem>[];
    return rawItems
        .map(AdminContactMailItem.fromDynamic)
        .toList(growable: false);
  }

  Future<void> markRead(String emailId) async {
    await callPrestoFunction<dynamic>(
      functions: prestoFirebaseFunctions,
      name: 'adminMarkInboundEmailRead',
      timeout: const Duration(seconds: 15),
      parameters: {'emailId': emailId, 'isRead': true},
      area: 'admin-inbox',
    );
  }
}
