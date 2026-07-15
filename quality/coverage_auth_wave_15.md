# Auth coverage wave 15

## Scope

This wave extends `AuthService` coverage without lowering thresholds or excluding files.

Covered paths:

- email registration trims the email and sets the Firebase language to French;
- Firebase registration failures are propagated;
- unexpected registration failures are propagated;
- email sign-in trims the email and sets the Firebase language to French;
- Firebase sign-in failures are propagated;
- unexpected sign-in failures are propagated.

## Measurement rule

No coverage percentage is declared from this branch before the pull-request validation produces a complete LCOV artifact. The next priority will be selected from that artifact, using real uncovered lines only.
