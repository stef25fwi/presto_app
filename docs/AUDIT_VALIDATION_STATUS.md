# Validation automatique — branche audit/prod-hardening-p0-p11

Généré par GitHub Actions sur le commit `dc46e612d171e5d9aadc3d8eb7bca74ac27d1025`.

| Contrôle | Résultat |
|---|---|
| Patchs idempotents et garde-fous | `failure` |
| Dépendances Flutter | `failure` |
| Flutter analyze | `failure` |
| Tests Flutter | `failure` |
| Dépendances Functions | `success` |
| Build Functions | `failure` |
| Tests Functions | `failure` |
| Firebase CLI | `success` |
| Tests Firestore Rules | `failure` |
| Build Web release | `failure` |
| Budget bundle Web | `failure` |

Les logs détaillés sont conservés dans `audit_validation_logs/`.

## bundle_budget.log

```text
Error: ENOENT: no such file or directory, stat '/home/runner/work/presto_app/presto_app/build/web/main.dart.js'
    at async Object.stat (node:internal/fs/promises:1037:18)
    at async main (file:///home/runner/work/presto_app/presto_app/tools/check_web_bundle_size.mjs:30:22) {
  errno: -2,
  code: 'ENOENT',
  syscall: 'stat',
  path: '/home/runner/work/presto_app/presto_app/build/web/main.dart.js'
}

```

## firebase_cli.log

```text
npm warn deprecated node-domexception@1.0.0: Use your platform's native DOMException instead
npm warn deprecated tar@6.2.1: Old versions of tar are not supported, and contain widely publicized security vulnerabilities, which have been fixed in the current version. Please update. Support for old versions may be purchased (at exorbitant rates) by contacting i@izs.me
npm warn deprecated json-ptr@3.1.1: Package no longer supported. Contact Support at https://www.npmjs.com/support for more info.
npm warn deprecated uuid@9.0.1: uuid@10 and below is no longer supported.  For ESM codebases, update to uuid@latest.  For CommonJS codebases, use uuid@11 (but be aware this version will likely be deprecated in 2028).
npm warn deprecated uuid@9.0.1: uuid@10 and below is no longer supported.  For ESM codebases, update to uuid@latest.  For CommonJS codebases, use uuid@11 (but be aware this version will likely be deprecated in 2028).
npm warn deprecated uuid@9.0.1: uuid@10 and below is no longer supported.  For ESM codebases, update to uuid@latest.  For CommonJS codebases, use uuid@11 (but be aware this version will likely be deprecated in 2028).
npm warn deprecated uuid@8.3.2: uuid@10 and below is no longer supported.  For ESM codebases, update to uuid@latest.  For CommonJS codebases, use uuid@11 (but be aware this version will likely be deprecated in 2028).
npm warn deprecated glob@10.5.0: Old versions of glob are not supported, and contain widely publicized security vulnerabilities, which have been fixed in the current version. Please update. Support for old versions may be purchased (at exorbitant rates) by contacting i@izs.me

added 627 packages in 13s

85 packages are looking for funding
  run `npm fund` for details

```

## firestore_rules.log

```text

> presto-functions@1.0.0 test:firestore
> npm run test:firestore:public-listings && npm run test:firestore:canonical-rules && npm run test:firestore:user-authority


> presto-functions@1.0.0 test:firestore:public-listings
> firebase emulators:exec --config ../firebase.json --only firestore "node scripts/test_public_listings_rules.mjs"

[33m[1m⚠  emulators:[22m[39m You are not currently authenticated so some features may not work correctly. Please run [1mfirebase login[22m to authenticate the CLI.
[36m[1mi  emulators:[22m[39m Starting emulators: firestore
[33m[1m⚠ [22m[39m It appears you are running in a CI environment. You can avoid downloading the Firestore Emulator repeatedly by caching the /home/runner/.cache/firebase/emulators directory.
[36m[1mi  firestore:[22m[39m downloading cloud-firestore-emulator-v1.19.8.jar...

[36m[1mi  firestore:[22m[39m Firestore Emulator logging to [1mfirestore-debug.log[22m
[32m[1m✔  firestore:[22m[39m Firestore Emulator UI websocket is running on 9150.
[36m[1mi [22m[39m Running script: [1mnode scripts/test_public_listings_rules.mjs[22m
public listings rules integration: OK
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator

> presto-functions@1.0.0 test:firestore:canonical-rules
> firebase emulators:exec --config ../firebase.json --only firestore "node scripts/test_canonical_marketplace_rules.mjs"

[33m[1m⚠  emulators:[22m[39m You are not currently authenticated so some features may not work correctly. Please run [1mfirebase login[22m to authenticate the CLI.
[36m[1mi  emulators:[22m[39m Starting emulators: firestore
[36m[1mi  firestore:[22m[39m Firestore Emulator logging to [1mfirestore-debug.log[22m
[32m[1m✔  firestore:[22m[39m Firestore Emulator UI websocket is running on 9150.
[36m[1mi [22m[39m Running script: [1mnode scripts/test_canonical_marketplace_rules.mjs[22m
[2026-07-10T04:43:52.162Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x7e608048 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L396, false for 'create' @ L867, false for 'update' @ L399, false for 'update' @ L867
Error: Expected request to fail, but it succeeded.
    at pr.then._a (file:///home/runner/work/presto_app/presto_app/functions/node_modules/@firebase/rules-unit-testing/dist/esm/index.esm.js:571:31)
    at process.processTicksAndRejections (node:internal/process/task_queues:103:5)
    at async main (file:///home/runner/work/presto_app/presto_app/functions/scripts/test_canonical_marketplace_rules.mjs:81:5)
[33m[1m⚠ [22m[39m Script exited unsuccessfully (code 1)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator

[1m[31mError:[39m[22m Script "[1mnode scripts/test_canonical_marketplace_rules.mjs[22m" exited with code 1

```

## flutter_analyze.log

```text
Resolving dependencies...
The current Dart SDK version is 3.11.1.

Because presto_app depends on record >=7.0.0 which requires SDK version >=3.12.0 <4.0.0, version solving failed.


You can try one of the following suggestions to make the pubspec resolve:
* Try using the Flutter SDK version: 3.44.6. 
* Consider downgrading your constraint on record: flutter pub add record:^6.2.1
Failed to update packages.

```

## flutter_deps.log

```text
Setting "enable-web" value to "true".

You may need to restart any open editors for them to read new settings.
Resolving dependencies...
The current Dart SDK version is 3.11.1.

Because presto_app depends on record >=7.0.0 which requires SDK version >=3.12.0 <4.0.0, version solving failed.


You can try one of the following suggestions to make the pubspec resolve:
* Try using the Flutter SDK version: 3.44.6. 
* Consider downgrading your constraint on record: flutter pub add record:^6.2.1
Failed to update packages.

```

## flutter_test.log

```text
Resolving dependencies...
The current Dart SDK version is 3.11.1.

Because presto_app depends on record >=7.0.0 which requires SDK version >=3.12.0 <4.0.0, version solving failed.


You can try one of the following suggestions to make the pubspec resolve:
* Try using the Flutter SDK version: 3.44.6. 
* Consider downgrading your constraint on record: flutter pub add record:^6.2.1
Failed to update packages.

```

## functions_build.log

```text

> presto-functions@1.0.0 build
> tsc

src/modules/billing/stripe_webhook.ts(162,29): error TS2532: Object is possibly 'undefined'.

```

## functions_deps.log

```text
npm warn deprecated node-domexception@1.0.0: Use your platform's native DOMException instead
npm warn deprecated glob@10.5.0: Old versions of glob are not supported, and contain widely publicized security vulnerabilities, which have been fixed in the current version. Please update. Support for old versions may be purchased (at exorbitant rates) by contacting i@izs.me

added 460 packages, and audited 461 packages in 12s

64 packages are looking for funding
  run `npm fund` for details

12 vulnerabilities (11 moderate, 1 high)

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.

```

## functions_test.log

```text

> presto-functions@1.0.0 test
> npm run build && node --test $(find lib -name '*.test.js' -print)


> presto-functions@1.0.0 build
> tsc

src/modules/billing/stripe_webhook.ts(162,29): error TS2532: Object is possibly 'undefined'.

```

## patches.log

```text
production hardening patches: OK
startup hardening patches: OK
file:///home/runner/work/presto_app/presto_app/tools/apply_auth_client_hardening.mjs:12
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
          ^

Error: remove client emailVerified profile write: expected exactly one occurrence, found 0
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_auth_client_hardening.mjs:12:11)
    at file:///home/runner/work/presto_app/presto_app/tools/apply_auth_client_hardening.mjs:24:8

Node.js v22.23.1

```

## web_build.log

```text
[flutter_with_build_stamp] APPCHECK_RECAPTCHA_SITE_KEY=absent
[flutter_with_build_stamp] APPCHECK_RECAPTCHA_PROVIDER=enterprise
[flutter_with_build_stamp] FCM_WEB_VAPID_KEY=absent
[flutter_with_build_stamp] ERROR: APPCHECK_RECAPTCHA_SITE_KEY is required for web release builds.
[flutter_with_build_stamp] Define it in the environment or .env.local before deploying hosting.

```
