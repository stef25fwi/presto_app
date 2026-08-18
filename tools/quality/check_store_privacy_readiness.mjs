import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const failures = [];
const passes = [];

function read(relativePath) {
  const absolute = path.join(root, relativePath);
  if (!fs.existsSync(absolute)) {
    failures.push(`missing file: ${relativePath}`);
    return '';
  }
  return fs.readFileSync(absolute, 'utf8');
}

function requireMarkers(relativePath, markers) {
  const content = read(relativePath);
  if (!content) return;
  let valid = true;
  for (const marker of markers) {
    if (!content.includes(marker)) {
      valid = false;
      failures.push(`${relativePath}: missing marker ${JSON.stringify(marker)}`);
    }
  }
  if (valid) passes.push(relativePath);
}

function forbidMarkers(relativePath, markers) {
  const content = read(relativePath);
  if (!content) return;
  for (const marker of markers) {
    if (content.includes(marker)) {
      failures.push(`${relativePath}: forbidden marker ${JSON.stringify(marker)}`);
    }
  }
}

const readinessPath = 'quality/store_privacy_readiness.json';
const readinessRaw = read(readinessPath);
if (readinessRaw) {
  try {
    const readiness = JSON.parse(readinessRaw);
    if (readiness.repository_score_target !== 10) {
      failures.push(`${readinessPath}: repository_score_target must be 10`);
    }
    if (!Array.isArray(readiness.controls) || readiness.controls.length !== 10) {
      failures.push(`${readinessPath}: exactly 10 repository controls are required`);
    } else {
      for (const control of readiness.controls) {
        if (control.status !== 'implemented') {
          failures.push(`${readinessPath}: ${control.id} is not implemented`);
        }
        if (!Array.isArray(control.evidence) || control.evidence.length === 0) {
          failures.push(`${readinessPath}: ${control.id} has no evidence`);
          continue;
        }
        for (const evidence of control.evidence) {
          if (!fs.existsSync(path.join(root, evidence))) {
            failures.push(`${readinessPath}: ${control.id} evidence missing: ${evidence}`);
          }
        }
      }
    }
    if (!Array.isArray(readiness.external_release_actions) ||
        readiness.external_release_actions.length < 5) {
      failures.push(`${readinessPath}: external release actions must remain explicit`);
    }
  } catch (error) {
    failures.push(`${readinessPath}: invalid JSON: ${error.message}`);
  }
}

requireMarkers('docs/privacy/STORE_DATA_INVENTORY.md', [
  'SIRET',
  'Audio / voix',
  'Adresse IP',
  'App Check / Play Integrity / reCAPTCHA',
  'Identifiant publicitaire / Device ID',
  'Contenus envoyés à l’IA',
]);

requireMarkers('docs/privacy/PROCESSOR_REGISTER.md', [
  'Firebase Authentication',
  'Firebase App Check',
  'Firebase AI',
  'Google Mobile Ads / AdMob',
  'Google UMP',
  'Google Sign-In',
  'Facebook Login',
  'Sign in with Apple',
]);

requireMarkers('docs/deployment/playstore-declarations.md', [
  'Data Safety',
  'SIRET',
  'Localisation approximative',
  'Identifiant publicitaire Android',
  'Firebase App Check',
  'Firebase AI',
  'Google Mobile Ads / AdMob + UMP',
  'https://ilipresto.fr/confidentialite',
  'https://ilipresto.fr/suppression-compte',
]);

requireMarkers('docs/deployment/appstore-privacy-declarations.md', [
  'App Privacy',
  'Coarse Location',
  'Device ID',
  'Advertising Data',
  'Product Interaction',
  'App Tracking Transparency',
  'Privacy manifests Apple',
  'https://ilipresto.fr/confidentialite',
]);

requireMarkers('web/confidentialite/index.html', [
  'Politique de confidentialité iliprestō',
  'SIRET',
  'Firebase App Check',
  'Firebase AI',
  'Google Mobile Ads/AdMob',
  'App Tracking Transparency',
  '/suppression-compte',
]);

requireMarkers('web/suppression-compte/index.html', [
  'Supprimer votre compte iliprestō',
  'Sans passer par l’application',
  'contact@ilipresto.fr',
  '/confidentialite',
]);

requireMarkers('lib/services/cookie_consent_service.dart', [
  'setAnalyticsCollectionEnabled',
  'analyticsAllowed',
  'marketingAllowed',
  'applyGoogleConsentMode',
]);

requireMarkers('lib/bootstrap/app_bootstrap.dart', [
  'if (!kIsWeb)',
  'AdsConsentService.instance.refreshPrivacyState()',
]);

requireMarkers('lib/services/ads_consent_service.dart', [
  'requestConsentInfoUpdate',
  'loadAndShowConsentFormIfRequired',
  'canRequestAds()',
  'getPrivacyOptionsRequirementStatus()',
  'showPrivacyOptionsForm',
  'refreshPrivacyState',
]);

requireMarkers('lib/widgets/ad_banner.dart', [
  'CookieConsentService.instance.canUseMarketing',
  'AdsConsentService.instance.initializeForAds()',
  'ad request blocked by UMP consent state',
]);
forbidMarkers('lib/widgets/ad_banner.dart', [
  'MobileAds.instance.initialize()',
  'ConsentInformation.instance.requestConsentInfoUpdate(',
]);

requireMarkers('lib/pages/legal_info_page.dart', [
  "import '../widgets/ads_privacy_options_card.dart';",
  'const AdsPrivacyOptionsCard()',
]);

requireMarkers('lib/widgets/ads_privacy_options_card.dart', [
  'Préférences publicitaires Google',
  'AdsConsentService.instance.showPrivacyOptions()',
  'AdsConsentService.instance.refreshPrivacyState()',
  'if (!required) return const SizedBox.shrink();',
]);

requireMarkers('lib/features/operating_mode/legal_documents.dart', [
  'SIRET',
  'Firebase App Check',
  'Firebase AI',
  'Google Mobile Ads/AdMob',
  'App Tracking Transparency',
  'https://ilipresto.fr/suppression-compte',
]);

requireMarkers('ios/Runner/Info.plist', [
  '<key>GADApplicationIdentifier</key>',
  '<key>NSUserTrackingUsageDescription</key>',
  '<key>NSCameraUsageDescription</key>',
  '<key>NSMicrophoneUsageDescription</key>',
]);

const rgpdRaw = read('quality/rgpd_readiness.json');
if (rgpdRaw) {
  try {
    const rgpd = JSON.parse(rgpdRaw);
    const privacy = rgpd.controls?.find((control) => control.id === 'privacy-notice');
    const processors = rgpd.controls?.find((control) => control.id === 'processor-register');
    if (privacy?.status !== 'implemented') {
      failures.push('quality/rgpd_readiness.json: privacy-notice must be implemented');
    }
    if (processors?.status !== 'implemented') {
      failures.push('quality/rgpd_readiness.json: processor-register must be implemented');
    }
    if (privacy?.evidence?.includes('lib/pages/privacy_policy_page.dart')) {
      failures.push('quality/rgpd_readiness.json: stale privacy_policy_page.dart evidence remains');
    }
  } catch (error) {
    failures.push(`quality/rgpd_readiness.json: invalid JSON: ${error.message}`);
  }
}

if (failures.length > 0) {
  console.error(`Store privacy readiness: FAIL (${failures.length} issue(s))`);
  for (const failure of failures) console.error(`- ${failure}`);
  process.exitCode = 1;
} else {
  console.log('Store privacy readiness: PASS — 10/10 repository controls implemented.');
  console.log(`Validated ${new Set(passes).size} evidence files plus readiness registries.`);
  console.log('External console/archive actions remain intentionally tracked as external_required.');
}
