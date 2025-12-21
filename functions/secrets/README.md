# Secrets Directory

Place your GCP service account JSON file here:
- `gcp-sa.json` - Google Cloud Platform Service Account credentials

⚠️ **IMPORTANT**: Never commit these files to git!

## How to get the service account JSON:
1. Go to https://console.cloud.google.com/iam-admin/serviceaccounts?project=presto-app-74abe
2. Select service account (e.g., `presto-app-74abe@appspot.gserviceaccount.com`)
3. Click "Keys" → "Add Key" → "Create new key" → JSON
4. Download and save as `gcp-sa.json` in this directory
