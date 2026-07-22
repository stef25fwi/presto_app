from pathlib import Path

path = Path('lib/pages/publish_offer_page.dart')
source = path.read_text()

renames = {
    '_formatMicroIaRuntimeError': 'formatMicroIaRuntimeError',
    '_publishAiDebugValue': 'publishAiDebugValue',
    '_adminAudioModeLabel': 'adminAudioModeLabel',
    '_normalizeDraftMissionDelay': 'normalizeDraftMissionDelay',
    '_transcriptMentionsBudget': 'transcriptMentionsBudget',
    '_transcriptMentionsUrgency': 'transcriptMentionsUrgency',
    '_extractMissionDelayFromTranscript': 'extractMissionDelayFromTranscript',
    '_transcriptRequestsNegotiatedBudget': 'transcriptRequestsNegotiatedBudget',
    '_extractBudgetAmountFromTranscript': 'extractBudgetAmountFromTranscript',
    '_normalizeDetailText': 'normalizeDetailText',
    '_significantDetailWords': 'significantDetailWords',
    '_detailWordsMatch': 'detailWordsMatch',
    '_filterRedundantDetails': 'filterRedundantDetails',
    '_buildRichDraftDescription': 'buildRichDraftDescription',
    '_firstNonEmptyDraftValue': 'firstNonEmptyDraftValue',
    '_extractPostalCodeFromTranscript': 'extractPostalCodeFromTranscript',
    '_resolvePublishCategoryLabel': 'resolvePublishCategoryLabel',
    '_normalizeAiGeoHint': 'normalizeAiGeoHint',
    '_geoCommuneMatchesAiHint': 'geoCommuneMatchesAiHint',
    '_isValidPhoneFR': 'isValidPhoneFR',
    '_firstNonEmptyPublishPhone': 'firstNonEmptyPublishPhone',
    '_parseBudget': 'parseBudget',
    '_validatePublishTitle': 'validatePublishTitle',
    '_validatePublishDescription': 'validatePublishDescription',
    '_translatePublishIssue': 'translatePublishIssue',
    '_formatPublishError': 'formatPublishError',
    '_publishFieldLabel': 'publishFieldLabel',
    '_countryCodeForDept': 'countryCodeForDept',
    '_storageExtFromPhoto': 'storageExtFromPhoto',
    '_storageContentTypeFromPhoto': 'storageContentTypeFromPhoto',
}

for old, new in renames.items():
    count = source.count(old)
    if count == 0:
        raise SystemExit(f'missing publication helper: {old}')
    source = source.replace(old, new)

path.write_text(source)

test_path = Path('test/pages/publish_offer_pure_helpers_massive_coverage_test.dart')
test_source = test_path.read_text()
platform_import = "import 'package:firebase_core_platform_interface/test.dart';\n"
if platform_import not in test_source:
    test_source = test_source.replace(
        "import 'package:firebase_core/firebase_core.dart';\n",
        "import 'package:firebase_core/firebase_core.dart';\n" + platform_import,
        1,
    )

main_marker = "void main() {\n  dynamic createState()"
main_replacement = """void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  });

  dynamic createState()"""
if main_marker not in test_source:
    raise SystemExit('publication helper test main marker not found')
test_source = test_source.replace(main_marker, main_replacement, 1)
test_path.write_text(test_source)
