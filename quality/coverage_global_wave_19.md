# Global coverage wave 19

## Scope

This wave covers `lib/services/offer_indexing.dart`, previously measured at 0/87 lines in the latest complete LCOV artifact.

Covered paths:

- slug and normalized-text generation;
- canonical category aliases and partial matches;
- category-id resolution and fallback slugs;
- metropolitan, DOM and collectivities postal-code departments;
- numeric and textual budget parsing;
- complete active offer index generation;
- inactive fallback index generation.

## Guarantees

- no threshold is lowered;
- no file is excluded from LCOV;
- no production behavior is changed;
- the final percentage must come from a complete CI LCOV artifact.
