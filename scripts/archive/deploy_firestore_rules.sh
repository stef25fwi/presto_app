#!/bin/bash
# Script pour déployer les règles Firestore

cd /workspaces/presto_app
firebase deploy --only firestore:rules
