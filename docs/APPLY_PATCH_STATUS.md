# Échec du générateur de durcissement

Commit source : `e859e69893d79fd024773d34629c0234720bd872`

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
file:///home/runner/work/presto_app/presto_app/tools/apply_stripe_ordering_hardening.mjs:12
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
          ^

Error: subscription event ordering field: expected exactly one occurrence, found 2
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_stripe_ordering_hardening.mjs:12:11)
    at file:///home/runner/work/presto_app/presto_app/tools/apply_stripe_ordering_hardening.mjs:23:1

Node.js v22.23.1
```
