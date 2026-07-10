# Échec du générateur de durcissement

Commit source : `2e99d9c5ee82e8d48d3d45f69a17e17fa87844de`

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
file:///home/runner/work/presto_app/presto_app/tools/apply_validation_round2_fixes.mjs:10
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
          ^

Error: account deletion static test: expected exactly one occurrence, found 0
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_validation_round2_fixes.mjs:10:11)
    at patchAccountDeletionStaticTest (file:///home/runner/work/presto_app/presto_app/tools/apply_validation_round2_fixes.mjs:43:13)
    at async file:///home/runner/work/presto_app/presto_app/tools/apply_validation_round2_fixes.mjs:131:1

Node.js v22.23.1
```
