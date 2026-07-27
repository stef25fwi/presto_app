import 'package:cloud_functions/cloud_functions.dart';

import '../../models/marketplace_enums.dart';
import '../../models/marketplace_report.dart';
import '../../services/firebase_functions_region.dart';
import '../../services/product_analytics_service.dart';

typedef ReportListingCaller = Future<Object?> Function(
  Map<String, dynamic> parameters,
);
typedef ReportAnalyticsLogger = Future<void> Function(
  String name,
  Map<String, Object?> parameters,
);

class ReportRepository {
  ReportRepository({
    FirebaseFunctions? functions,
    ProductAnalyticsService? analytics,
    ReportListingCaller? caller,
    ReportAnalyticsLogger? analyticsLogger,
  })  : _functionsOverride = functions,
        _analyticsOverride = analytics,
        _caller = caller,
        _analyticsLogger = analyticsLogger;

  final FirebaseFunctions? _functionsOverride;
  final ProductAnalyticsService? _analyticsOverride;
  final ReportListingCaller? _caller;
  final ReportAnalyticsLogger? _analyticsLogger;

  FirebaseFunctions get _functions => _functionsOverride ?? prestoFirebaseFunctions;
  ProductAnalyticsService get _analytics =>
      _analyticsOverride ?? ProductAnalyticsService();

  Future<Object?> _report(Map<String, dynamic> parameters) async {
    final caller = _caller;
    if (caller != null) return caller(parameters);
    final response = await callPrestoFunction<dynamic>(
      functions: _functions,
      name: 'reportListing',
      timeout: const Duration(seconds: 20),
      parameters: parameters,
    );
    return response.data;
  }

  Future<void> _log(
    String name,
    Map<String, Object?> parameters,
  ) async {
    final logger = _analyticsLogger;
    if (logger != null) return logger(name, parameters);
    return _analytics.logEvent(name, parameters: parameters);
  }

  Future<bool> reportListing(
    ListingReportDraft draft, {
    required String recaptchaToken,
  }) async {
    final rawData = await _report(<String, dynamic>{
      ...draft.toMap(),
      'recaptchaToken': recaptchaToken,
    });
    final data = Map<String, dynamic>.from(
      (rawData as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    await _log('listing_reported', <String, Object?>{
      'listing_id': draft.listingId,
      'reason_code': draft.reasonCode.value,
      'review_triggered': data['reviewTriggered'] == true,
    });
    return data['ok'] == true;
  }
}
