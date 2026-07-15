# Global coverage wave 17

## Scope

This wave targets `lib/models/hero_slide.dart`, measured at 0/111 covered lines in the latest complete LCOV artifact.

Covered behavior:

- map parsing and normalization;
- safe defaults for malformed legacy values;
- timestamp and JSON serialization;
- complete and no-op `copyWith` paths;
- image/video and global/regional helpers;
- deterministic display ordering.

## Guarantees

- no threshold is lowered;
- no file is excluded from LCOV;
- the production model remains unchanged;
- the final percentage will only be reported from the complete CI LCOV artifact.
