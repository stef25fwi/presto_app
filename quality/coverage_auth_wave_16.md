# Auth coverage wave 16

## Scope

This wave continues `AuthService` coverage without lowering thresholds or excluding files.

Covered paths:

- email registration receives a credential whose user is unexpectedly null;
- the service raises the explicit `user-null` Firebase Auth error;
- email sign-in receives a credential whose user is null;
- the credential is returned without attempting a Firestore profile write;
- language configuration and email normalization remain verified on both paths.

## Measurement rule

No coverage percentage is declared from this branch before the pull-request validation produces a complete LCOV artifact. The next priority will be selected from that artifact, using real uncovered lines only.
