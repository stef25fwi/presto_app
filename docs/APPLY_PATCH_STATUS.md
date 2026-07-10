# Échec du générateur de durcissement

Commit source : `f71ef4ac0354ad67518cebe86da78979fc0d8baa`

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
npm error code ERESOLVE
npm error ERESOLVE could not resolve
npm error
npm error While resolving: firebase-functions@7.2.5
npm error Found: firebase-admin@14.1.0
npm error node_modules/firebase-admin
npm error   firebase-admin@"^14.1.0" from the root project
npm error
npm error Could not resolve dependency:
npm error peer firebase-admin@"^11.10.0 || ^12.0.0 || ^13.0.0" from firebase-functions@7.2.5
npm error node_modules/firebase-functions
npm error   firebase-functions@"^7.2.5" from the root project
npm error
npm error Conflicting peer dependency: firebase-admin@13.10.0
npm error node_modules/firebase-admin
npm error   peer firebase-admin@"^11.10.0 || ^12.0.0 || ^13.0.0" from firebase-functions@7.2.5
npm error   node_modules/firebase-functions
npm error     firebase-functions@"^7.2.5" from the root project
npm error
npm error Fix the upstream dependency conflict, or retry
npm error this command with --force or --legacy-peer-deps
npm error to accept an incorrect (and potentially broken) dependency resolution.
npm error
npm error
npm error For a full report see:
npm error /home/runner/.npm/_logs/2026-07-10T05_00_44_887Z-eresolve-report.txt
npm error A complete log of this run can be found in: /home/runner/.npm/_logs/2026-07-10T05_00_44_887Z-debug-0.log
```
