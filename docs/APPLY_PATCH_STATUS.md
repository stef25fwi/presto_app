# Échec du générateur de durcissement

Commit source : `9d8ff52a63234eeab96d044024159ff275e07e22`

```text
production hardening patches: OK
startup hardening patches: OK
auth client hardening patches: OK
account cleanup patch: OK
cursor patch script normalized: OK
file:///home/runner/work/presto_app/presto_app/tools/apply_cursor_pagination.mjs:20
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
          ^

Error: query cursor parameter: expected exactly one occurrence, found 2
    at replaceOnce (file:///home/runner/work/presto_app/presto_app/tools/apply_cursor_pagination.mjs:20:11)
    at patchQueryHelper (file:///home/runner/work/presto_app/presto_app/tools/apply_cursor_pagination.mjs:29:13)
    at async file:///home/runner/work/presto_app/presto_app/tools/apply_cursor_pagination.mjs:116:1

Node.js v22.23.1
```
