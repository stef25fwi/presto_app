import 'package:cloud_functions/cloud_functions.dart';

import '../../models/marketplace_enums.dart';
import '../../models/marketplace_report.dart';
import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';

class ReportRepository {
  ReportRepository({
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
  })  : _functions = functions ?? prestoFirebaseFunctions,
        _analytics = analytics ?? ProductAnalyticsService();

  final FirebaseFunctions _functions;
  final ProductAnalyticsService _analytics;

  Future<bool> reportListing(
    ListingReportDraft draft, {
    required String recaptchaToken,
  }) async {
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'reportListing',
      timeout: const Duration(seconds: 20),
      parameters: <String, dynamic>{
        ...draft.toMap(),
        'recaptchaToken': recaptchaToken,
      },
    );
    final data = Map<String, dynamic>.from(
      (response.data as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    await _analytics.logEvent('listing_reported', parameters: <String, Object?>{
      'listing_id': draft.listingId,
      'reason_code': draft.reasonCode.value,
      'review_triggered': data['reviewTriggered'] == true,
    });
    return data['ok'] == true;
  }
}
