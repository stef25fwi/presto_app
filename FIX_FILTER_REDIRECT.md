# ✅ Fix: Firebase Console Link on Filter Activation

## Problem
When activating a filter on the "Je consulte" page, users were being redirected to a Firebase Console link. This happened when Firestore returned errors due to missing indexes.

## Root Cause Analysis
1. **Immediate Issue**: The error handling code was extracting URLs from Firestore error messages and displaying them as clickable links to users
   - File: `lib/main.dart` (lines ~4010-4065)
   - Method: `_extractFirstUrl()` was pulling Firebase Console links from error messages
   - UI: Error screen had "Ouvrir le lien" button that launched these URLs

2. **Deeper Issue**: Missing Firestore indexes for the filter combinations
   - Query filters: `isActive=true` + `category` + `subCategory` + `postalCode`
   - These combinations required specific compound indexes in Firestore
   - When indexes didn't exist, Firestore returned "FAILED_PRECONDITION" errors with index creation links

## Solution Implemented

### Phase 1: Hide Error URLs from Users ✅
**File**: `lib/main.dart` (lines 4002-4065)
- Removed the `_extractFirstUrl()` call that pulled URLs from error messages
- Removed the "Ouvrir le lien" and "Copier le lien" buttons from error UI
- Kept user-friendly error message: "Mise à jour en cours, réessaie dans 1 minute"
- Users no longer see Firebase Console links

### Phase 2: Add Missing Firestore Indexes ✅
**File**: `firestore.indexes.json`

Added 7 new compound indexes to support filter combinations:

1. **category + createdAt**
   ```
   isActive ↑, category ↑, createdAt ↓
   ```

2. **subCategory + createdAt**
   ```
   isActive ↑, subCategory ↑, createdAt ↓
   ```

3. **postalCode + createdAt**
   ```
   isActive ↑, postalCode ↑, createdAt ↓
   ```

4. **category + subCategory + createdAt**
   ```
   isActive ↑, category ↑, subCategory ↑, createdAt ↓
   ```

5. **category + postalCode + createdAt**
   ```
   isActive ↑, category ↑, postalCode ↑, createdAt ↓
   ```

6. **category + subCategory + postalCode + createdAt** (most complex)
   ```
   isActive ↑, category ↑, subCategory ↑, postalCode ↑, createdAt ↓
   ```

## Deployment Steps

### For Local Development
```bash
cd /workspaces/presto_app

# Deploy the new Firestore indexes
firebase deploy --only firestore:indexes

# Wait for indexes to build (may take 5-30 minutes)
firebase firestore:indexes:list
```

### For Production
The indexes are now defined in `firestore.indexes.json`. They will be deployed during the next:
- GitHub Actions CI/CD pipeline run
- Manual Firebase deploy in production

## Testing Checklist

After deployment, verify:

- [ ] **Filter activation**: Click a filter on "Je consulte" page
  - Should load offers without error
  - No Firebase Console links appear
  - Friendly error message if issues occur

- [ ] **Multi-filter combinations**: Test:
  - [ ] Category only
  - [ ] SubCategory only
  - [ ] Postal Code only
  - [ ] Category + SubCategory
  - [ ] Category + Postal Code
  - [ ] All three combined

- [ ] **Error handling**: If an error still occurs:
  - [ ] Shows user-friendly message
  - [ ] Shows "Réessayer" button (not Firebase links)
  - [ ] No external URLs in error UI

## Files Changed
1. `/workspaces/presto_app/lib/main.dart` - Removed error URL extraction (lines 4010-4065)
2. `/workspaces/presto_app/firestore.indexes.json` - Added 7 new compound indexes

## Status
- ✅ UI fix: Error URLs hidden from users
- ⏳ Index deployment: Pending Firebase deploy

## Next Steps
1. Deploy the updated `firestore.indexes.json` file to Firebase
2. Wait for indexes to build (5-30 minutes typically)
3. Test filter activation in all combinations
4. If errors persist, check Firebase Console → Firestore → Indexes for status
