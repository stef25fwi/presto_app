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
