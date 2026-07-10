# Validation automatique — branche audit/prod-hardening-p0-p11

Généré par GitHub Actions sur le commit `158274fc3125d15246658ac20b766afa6a985f9b`.

| Contrôle | Résultat |
|---|---|
| Patchs idempotents et garde-fous | `success` |
| Dépendances Flutter | `success` |
| Flutter analyze | `failure` |
| Tests Flutter | `failure` |
| Dépendances Functions | `success` |
| Build Functions | `success` |
| Tests Functions | `success` |
| Firebase CLI | `success` |
| Tests Firestore Rules | `failure` |
| Build Web release | `success` |
| Budget bundle Web | `failure` |

Les 100 dernières lignes de chaque contrôle sont conservées ci-dessous.

## bundle_budget.log

```text
main.dart.js: 5.89 MiB / 12.00 MiB
build/web total: 67.29 MiB / 50.00 MiB
Error: build/web exceeds the production budget: 67.29 MiB
    at main (file:///home/runner/work/presto_app/presto_app/tools/check_web_bundle_size.mjs:40:11)

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
[2026-07-10T05:14:32.140Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de3e error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L398, false for 'create' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.346Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de3f error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.373Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de41 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.396Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de42 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.415Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de43 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.436Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de44 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:32.479Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de45 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L398, false for 'create' @ L869, evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'create' @ L398, false for 'create' @ L869
[2026-07-10T05:14:32.495Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de46 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L424, false for 'create' @ L869, false for 'update' @ L424, false for 'update' @ L869
[2026-07-10T05:14:32.508Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de47 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'update' @ L424, false for 'update' @ L869
[2026-07-10T05:14:32.520Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de48 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L435, false for 'create' @ L869, false for 'update' @ L435, false for 'update' @ L869
[2026-07-10T05:14:32.529Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de49 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'update' @ L435, false for 'update' @ L869
[2026-07-10T05:14:32.590Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de4b error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L448, false for 'create' @ L869, false for 'update' @ L448, false for 'update' @ L869
[2026-07-10T05:14:32.601Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de4c error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'update' @ L448, false for 'update' @ L869
[2026-07-10T05:14:32.625Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de4d error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L657, false for 'create' @ L869, false for 'update' @ L657, false for 'update' @ L869
[2026-07-10T05:14:32.635Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de4e error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'update' @ L657, false for 'update' @ L869
[2026-07-10T05:14:32.688Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de50 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L464, false for 'create' @ L869, false for 'update' @ L464, false for 'update' @ L869
[2026-07-10T05:14:32.701Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de51 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'create' @ L773, false for 'create' @ L869, false for 'update' @ L773, false for 'update' @ L869
[2026-07-10T05:14:32.712Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de52 error. Code: 7 Message: 7 PERMISSION_DENIED: 
false for 'update' @ L773, false for 'update' @ L869
[2026-07-10T05:14:32.744Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x8b47de53 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L779:26 for 'create' @ L779, false for 'create' @ L869, false for 'update' @ L781, false for 'update' @ L869, Property createdVia is undefined on object. for 'create' @ L779, false for 'create' @ L869
canonical marketplace rules integration: OK
[32m[1m✔ [22m[39m Script exited successfully (code 0)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator

> presto-functions@1.0.0 test:firestore:user-authority
> firebase emulators:exec --config ../firebase.json --only firestore "node scripts/test_user_authority_rules.mjs"

[33m[1m⚠  emulators:[22m[39m You are not currently authenticated so some features may not work correctly. Please run [1mfirebase login[22m to authenticate the CLI.
[36m[1mi  emulators:[22m[39m Starting emulators: firestore
[36m[1mi  firestore:[22m[39m Firestore Emulator logging to [1mfirestore-debug.log[22m
[32m[1m✔  firestore:[22m[39m Firestore Emulator UI websocket is running on 9150.
[36m[1mi [22m[39m Running script: [1mnode scripts/test_user_authority_rules.mjs[22m
[2026-07-10T05:14:39.508Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d7d error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.532Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d7e error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.559Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d7f error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.581Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d80 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.603Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d81 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.634Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d82 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.655Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d83 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.676Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d84 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.692Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d85 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.707Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d86 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.722Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d87 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
[2026-07-10T05:14:39.738Z]  @firebase/firestore: Firestore (11.10.0): GrpcConnection RPC 'Write' stream 0x21996d88 error. Code: 7 Message: 7 PERMISSION_DENIED: 
evaluation error at L401:24 for 'update' @ L401, false for 'update' @ L869, false for 'update' @ L401, false for 'update' @ L869
Error: Expected request to fail, but it succeeded.
    at pr.then._a (file:///home/runner/work/presto_app/presto_app/functions/node_modules/@firebase/rules-unit-testing/dist/esm/index.esm.js:571:31)
    at process.processTicksAndRejections (node:internal/process/task_queues:103:5)
    at async main (file:///home/runner/work/presto_app/presto_app/functions/scripts/test_user_authority_rules.mjs:65:7)
[33m[1m⚠ [22m[39m Script exited unsuccessfully (code 1)
[36m[1mi  emulators:[22m[39m Shutting down emulators.
[36m[1mi  firestore:[22m[39m Stopping Firestore Emulator
[36m[1mi  hub:[22m[39m Stopping emulator hub
[36m[1mi  logging:[22m[39m Stopping Logging Emulator

[1m[31mError:[39m[22m Script "[1mnode scripts/test_user_authority_rules.mjs[22m" exited with code 1

```

## flutter_analyze.log

```text
Resolving dependencies...
Downloading packages...
  audio_session 0.2.3 (0.2.4 available)
  audioplayers 6.8.0 (6.8.1 available)
  audioplayers_windows 4.4.0 (4.4.1 available)
  cross_file 0.3.5+2 (0.3.5+4 available)
! flutter_app_badger 1.5.0 from path third_party/flutter_app_badger (overridden)
  google_sign_in_android 7.2.13 (7.2.15 available)
  image 4.8.0 (4.9.1 available)
  image_picker 1.2.2 (1.2.3 available)
  just_audio 0.10.5 (0.10.6 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.18.0 (1.19.0 available)
  package_config 2.2.0 (3.0.0 available)
  pdf 3.12.0 (3.13.0 available)
  qr 3.0.2 (4.0.0 available)
  record 7.1.0 (7.1.1 available)
  record_linux 2.1.0 (2.1.1 available)
  record_web 2.1.0 (2.1.1 available)
  record_windows 2.2.0 (2.2.2 available)
  share_plus 10.1.4 (13.2.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  test_api 0.7.11 (0.7.13 available)
  timezone 0.11.0 (0.11.1 available)
  vector_math 2.2.0 (2.4.0 available)
  video_player_android 2.9.7 (2.11.0 available)
  video_player_avfoundation 2.9.7 (2.11.0 available)
  video_player_platform_interface 6.7.0 (6.9.0 available)
  webview_flutter 4.14.0 (4.14.1 available)
  win32 5.15.0 (6.3.0 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing presto_app...                                         

   info • Invalid use of a private type in a public API. Try making the private type public, or making the API that uses the private type also be private • lib/features/subscriptions/subscription_widgets.dart:436:9 • library_private_types_in_public_api
   info • Invalid use of a private type in a public API. Try making the private type public, or making the API that uses the private type also be private • lib/features/subscriptions/subscription_widgets.dart:443:10 • library_private_types_in_public_api

2 issues found. (ran in 21.1s)

```

## flutter_deps.log

```text
Setting "enable-web" value to "true".

You may need to restart any open editors for them to read new settings.
Resolving dependencies...
Downloading packages...
  audio_session 0.2.3 (0.2.4 available)
  audioplayers 6.8.0 (6.8.1 available)
  audioplayers_windows 4.4.0 (4.4.1 available)
  cross_file 0.3.5+2 (0.3.5+4 available)
! flutter_app_badger 1.5.0 from path third_party/flutter_app_badger (overridden)
  google_sign_in_android 7.2.13 (7.2.15 available)
  image 4.8.0 (4.9.1 available)
  image_picker 1.2.2 (1.2.3 available)
  just_audio 0.10.5 (0.10.6 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.18.0 (1.19.0 available)
  package_config 2.2.0 (3.0.0 available)
  pdf 3.12.0 (3.13.0 available)
  qr 3.0.2 (4.0.0 available)
  record 7.1.0 (7.1.1 available)
  record_linux 2.1.0 (2.1.1 available)
  record_web 2.1.0 (2.1.1 available)
  record_windows 2.2.0 (2.2.2 available)
  share_plus 10.1.4 (13.2.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  test_api 0.7.11 (0.7.13 available)
  timezone 0.11.0 (0.11.1 available)
  vector_math 2.2.0 (2.4.0 available)
  video_player_android 2.9.7 (2.11.0 available)
  video_player_avfoundation 2.9.7 (2.11.0 available)
  video_player_platform_interface 6.7.0 (6.9.0 available)
  webview_flutter 4.14.0 (4.14.1 available)
  win32 5.15.0 (6.3.0 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

```

## flutter_test.log

```text
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 50 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///home/runner/work/presto_app/presto_app/lib/pages/toolbox_je_me_lance_page.dart:7069:16

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#00daa relayoutBoundary=up21 OVERFLOWING:
  creator: Row ← Padding ← DecoratedBox ← Container ← Listener ← RawGestureDetector ← GestureDetector
    ← Semantics ← DefaultSelectionStyle ← Builder ← MouseRegion ← Semantics ← ⋯
  parentData: offset=Offset(11.0, 9.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=301.6, 0.0<=h<=Infinity)
  size: Size(301.6, 17.0)
  direction: horizontal
  mainAxisAlignment: start
  mainAxisSize: min
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
00:24 +130 -1: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_etudiant_journey_test.dart: le statut Étudiant + activité du catalogue alimente le parcours avec la fiche officielle
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following message was thrown:
Multiple exceptions (33) were detected during the running of the current test, and at least one was
unexpected.
════════════════════════════════════════════════════════════════════════════════════════════════════
00:25 +130 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton IA dictée est visible sur la page de publication
00:25 +130 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_etudiant_journey_test.dart: le statut Étudiant + activité du catalogue alimente le parcours avec la fiche officielle [E]
  Test failed. See exception logs above.
  The test description was: le statut Étudiant + activité du catalogue alimente le parcours avec la fiche officielle
  
00:25 +130 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton IA dictée est visible sur la page de publication
00:25 +131 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton IA assistant (✨) est toujours visible dans le champ description
00:25 +132 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Cliquer "Publier mon offre" sans remplir le formulaire affiche les erreurs de validation
[PublishOfferAiFlow] step=PublishOfferAiFlowStep.textSelected reason=text-tab-selected
00:25 +133 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton Publier est initialement grisé (formulaire incomplet)
00:25 +134 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton Publier est initialement grisé (formulaire incomplet)
00:25 +135 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton Publier est initialement grisé (formulaire incomplet)
00:25 +136 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton Publier est initialement grisé (formulaire incomplet)
00:25 +137 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Le bouton Publier est initialement grisé (formulaire incomplet)
00:25 +138 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: La sélection d'une catégorie active la sous-catégorie correspondante
[PublishOfferAiFlow] step=PublishOfferAiFlowStep.textSelected reason=text-tab-selected
00:26 +139 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Saisir le titre et la description active le bouton IA sparkle et le formulaire enregistre le contenu
00:26 +140 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Saisir le titre et la description active le bouton IA sparkle et le formulaire enregistre le contenu
00:26 +141 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Saisir le titre et la description active le bouton IA sparkle et le formulaire enregistre le contenu
00:26 +142 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Saisir le titre et la description active le bouton IA sparkle et le formulaire enregistre le contenu
00:26 +143 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: Annonce test : tous les champs obligatoires sont présents dans le formulaire
00:27 +144 -2: /home/runner/work/presto_app/presto_app/test/publish_offer_test.dart: (tearDownAll)
00:27 +144 -2: /home/runner/work/presto_app/presto_app/test/profile_readiness_location_test.dart: ProfileReadinessChecker.resolveLocation accepts city and postalCode aliases
00:27 +145 -2: /home/runner/work/presto_app/presto_app/test/profile_readiness_location_test.dart: ProfileReadinessChecker.resolveLocation accepts legacy snake_case postal aliases
00:27 +146 -2: /home/runner/work/presto_app/presto_app/test/profile_readiness_location_test.dart: ProfileReadinessChecker.resolveLocation reports exact missing location reason
00:28 +147 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: (setUpAll)
00:28 +147 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +148 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +149 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +150 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +151 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +152 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +153 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +154 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +155 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +156 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +157 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +158 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:28 +159 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:29 +160 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:29 +161 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:29 +162 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:29 +163 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:30 +164 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:30 +165 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:30 +166 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:31 +167 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:32 +168 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:32 +169 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:32 +170 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:32 +171 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Retraité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:33 +172 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Indépendant + activité Agriculteur affiche les vraies infos de la fiche officielle
00:37 +173 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Demandeur d'emploi + activité Agriculteur affiche les vraies infos de la fiche officielle
00:40 +174 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: le statut Sans activité + activité Agriculteur affiche les vraies infos de la fiche officielle
00:44 +175 -2: /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_statuts_agriculteur_journey_test.dart: (tearDownAll)
00:44 +175 -2: Some tests failed.

Failing tests:
  /home/runner/work/presto_app/presto_app/test/auth_email_static_test.dart: Auth email / connexion static checks tests suppression compte deleteCurrentAccount
  /home/runner/work/presto_app/presto_app/test/toolbox_je_me_lance_etudiant_journey_test.dart: le statut Étudiant + activité du catalogue alimente le parcours avec la fiche officielle

```

## functions_build.log

```text

> presto-functions@1.0.0 build
> tsc


```

## functions_deps.log

```text
npm warn deprecated node-domexception@1.0.0: Use your platform's native DOMException instead
npm warn deprecated glob@10.5.0: Old versions of glob are not supported, and contain widely publicized security vulnerabilities, which have been fixed in the current version. Please update. Support for old versions may be purchased (at exorbitant rates) by contacting i@izs.me

added 492 packages, and audited 493 packages in 7s

65 packages are looking for funding
  run `npm fund` for details

9 moderate severity vulnerabilities

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.

```

## functions_test.log

```text
  ...
# Subtest: readConversationParticipants falls back to alias fields and metadata maps
ok 132 - readConversationParticipants falls back to alias fields and metadata maps
  ---
  duration_ms: 0.239214
  type: 'test'
  ...
# Subtest: readConversationParticipantIdsFromCanonicalId extracts participants from canonical id
ok 133 - readConversationParticipantIdsFromCanonicalId extracts participants from canonical id
  ---
  duration_ms: 0.211954
  type: 'test'
  ...
# Subtest: readConversationParticipants prioritizes canonical id when provided
ok 134 - readConversationParticipants prioritizes canonical id when provided
  ---
  duration_ms: 0.348616
  type: 'test'
  ...
# Subtest: buildConversationParticipantFields writes all participant aliases
ok 135 - buildConversationParticipantFields writes all participant aliases
  ---
  duration_ms: 0.390509
  type: 'test'
  ...
# Subtest: parseCanonicalConversationId reads offer and participants from canonical ids
ok 136 - parseCanonicalConversationId reads offer and participants from canonical ids
  ---
  duration_ms: 2.257152
  type: 'test'
  ...
# Subtest: mergeUniqueParticipantIds deduplicates and sorts participant ids
ok 137 - mergeUniqueParticipantIds deduplicates and sorts participant ids
  ---
  duration_ms: 0.274106
  type: 'test'
  ...
# Subtest: normalizeParticipantBooleanMap fills missing participants with false
ok 138 - normalizeParticipantBooleanMap fills missing participants with false
  ---
  duration_ms: 0.355537
  type: 'test'
  ...
# Subtest: normalizeParticipantNumberMap fills missing participants with zero
ok 139 - normalizeParticipantNumberMap fills missing participants with zero
  ---
  duration_ms: 0.285572
  type: 'test'
  ...
# Subtest: normalizeParticipantUnknownMap keeps only participant scoped keys
ok 140 - normalizeParticipantUnknownMap keeps only participant scoped keys
  ---
  duration_ms: 0.347474
  type: 'test'
  ...
# Subtest: readConversationFlagMap normalizes boolean maps
ok 141 - readConversationFlagMap normalizes boolean maps
  ---
  duration_ms: 1.556825
  type: 'test'
  ...
# Subtest: computeConversationStatus returns open when nobody archived or blocked
ok 142 - computeConversationStatus returns open when nobody archived or blocked
  ---
  duration_ms: 0.202751
  type: 'test'
  ...
# Subtest: computeConversationStatus returns archived when all participants archived
ok 143 - computeConversationStatus returns archived when all participants archived
  ---
  duration_ms: 0.122551
  type: 'test'
  ...
# Subtest: computeConversationStatus returns closed when any participant blocked
ok 144 - computeConversationStatus returns closed when any participant blocked
  ---
  duration_ms: 0.172084
  type: 'test'
  ...
# Subtest: isConversationFlagEnabledForUser reads participant-specific flags
ok 145 - isConversationFlagEnabledForUser reads participant-specific flags
  ---
  duration_ms: 0.275749
  type: 'test'
  ...
# Subtest: isConversationFlagEnabledForUser also supports deletedBy
ok 146 - isConversationFlagEnabledForUser also supports deletedBy
  ---
  duration_ms: 0.147118
  type: 'test'
  ...
1..146
# tests 146
# suites 0
# pass 146
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 1689.912116

```

## patches.log

```text
production hardening patches: OK
startup hardening patches: OK
auth client hardening patches: OK
account cleanup patch: OK
cursor patch script normalized: OK
cursor query signature patch: OK
cursor pagination patches: OK
validation fixes: OK
identity authority hardening: OK
dependency security upgrades: OK
stripe ordering hardening: OK
function resource limits: OK

up to date, audited 509 packages in 1s

80 packages are looking for funding
  run `npm fund` for details

9 moderate severity vulnerabilities

To address issues that do not require attention, run:
  npm audit fix

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
production guardrails: OK (8 checks)

```

## web_build.log

```text
[flutter_with_build_stamp] APPCHECK_RECAPTCHA_SITE_KEY=present(26 chars)
[flutter_with_build_stamp] APPCHECK_RECAPTCHA_PROVIDER=enterprise
[flutter_with_build_stamp] FCM_WEB_VAPID_KEY=absent
Resolving dependencies...
Downloading packages...
  audio_session 0.2.3 (0.2.4 available)
  audioplayers 6.8.0 (6.8.1 available)
  audioplayers_windows 4.4.0 (4.4.1 available)
  cross_file 0.3.5+2 (0.3.5+4 available)
! flutter_app_badger 1.5.0 from path third_party/flutter_app_badger (overridden)
  google_sign_in_android 7.2.13 (7.2.15 available)
  image 4.8.0 (4.9.1 available)
  image_picker 1.2.2 (1.2.3 available)
  just_audio 0.10.5 (0.10.6 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.18.0 (1.19.0 available)
  package_config 2.2.0 (3.0.0 available)
  pdf 3.12.0 (3.13.0 available)
  qr 3.0.2 (4.0.0 available)
  record 7.1.0 (7.1.1 available)
  record_linux 2.1.0 (2.1.1 available)
  record_web 2.1.0 (2.1.1 available)
  record_windows 2.2.0 (2.2.2 available)
  share_plus 10.1.4 (13.2.0 available)
  share_plus_platform_interface 5.0.2 (7.1.0 available)
  test_api 0.7.11 (0.7.13 available)
  timezone 0.11.0 (0.11.1 available)
  vector_math 2.2.0 (2.4.0 available)
  video_player_android 2.9.7 (2.11.0 available)
  video_player_avfoundation 2.9.7 (2.11.0 available)
  video_player_platform_interface 6.7.0 (6.9.0 available)
  webview_flutter 4.14.0 (4.14.1 available)
  win32 5.15.0 (6.3.0 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Compiling lib/main.dart for the Web...                          
Font asset "Font-Awesome-7-Brands-Regular-400.otf" was tree-shaken, reducing it from 215132 to 2024 bytes (99.1% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Font asset "Font-Awesome-7-Free-Regular-400.otf" was tree-shaken, reducing it from 87340 to 1524 bytes (98.3% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 1472 bytes (99.4% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 52040 bytes (96.8% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             55.0s
✓ Built build/web

```
