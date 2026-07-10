# Échec du générateur de durcissement

Commit source : `5751a41f0fce61ae60717153af4f087a3f46821c`

```text
Error: firestore protected user fields: expected exactly one source occurrence, found 0
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_prod_hardening_patches.mjs:18:11)
    at patchFirestoreRules (file:///home/runner/work/presto_app/presto_app/tools/apply_prod_hardening_patches.mjs:36:13)
    at async main (file:///home/runner/work/presto_app/presto_app/tools/apply_prod_hardening_patches.mjs:177:3)
```
