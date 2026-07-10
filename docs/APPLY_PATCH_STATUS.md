# Échec du générateur de durcissement

Commit source : `666ae6d1a2909c5f54fd4a8499bb14058b415001`

```text
production hardening patches: OK
startup hardening patches: OK
auth client hardening patches: OK
account cleanup patch: OK
cursor patch script normalized: OK
cursor query signature patch: OK
cursor pagination patches: OK
validation fixes: OK
file:///home/runner/work/presto_app/presto_app/tools/apply_identity_authority_hardening.mjs:10
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
          ^

Error: canonical merge profile write: expected exactly one occurrence, found 0
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_identity_authority_hardening.mjs:10:11)
    at file:///home/runner/work/presto_app/presto_app/tools/apply_identity_authority_hardening.mjs:33:13

Node.js v22.23.1
```
