# HISAAB 1.3.0 — refreshed workspace and daily sales protection

This version refreshes navigation, dashboard metrics, page headings, summaries, tabs and forms while keeping the existing navy-and-teal palette, business fields, reports and actions. The violet-and-gold logo and all profile/shared-ledger features remain included. The app name, database schema and data locations are unchanged by this update.

## Sales-date protection

- Only sales are checked for duplicates: one sales entry per calendar date, per profile, regardless of amount or time of day.
- If that date already has a sale, the app shows a message and keeps the form contents. Cancel and edit the existing sale, or choose another date. There is no override to create a second daily sale.
- Editing a sale on its original date remains allowed. Changing it to an occupied date is blocked.
- Existing historical same-day records are preserved and remain editable; this update never automatically deletes or merges them.
- Purchases, payments, credit notes, expenses and bank-ledger entries no longer show duplicate warnings. Payment balance safeguards remain in place.

## Safe Windows update

1. Export a backup from the old app for each profile that has records. Keep the old release folder too.
2. Close every HISAAB window. Extract the complete new ZIP into a new application folder; keep HISAAB.exe, all DLLs and the data folder together.
3. Run HISAAB.exe using the same Windows account as before. Do not uninstall, clear application settings, or delete Documents/PharmacyManagement.
4. Existing profile names and passwords continue to work. If upgrading directly from the original single-user app, create the first profile; its private records stay in the original database.
5. On first sign-in, existing bank-ledger rows and bank-account details from all local profile databases are copied into one shared ledger. Original private database files and pre-migration recovery copies are retained. Compare balances and counts before entering new data.
6. Use the profile name/photo in the sidebar → Edit to add/change/remove a photo or choose whether to require a login password. Existing protected profiles require their current password before changing or removing protection.

## What is shared, and what stays private

- **Shared:** bank ledger, bank-account registry, and the original first profile's Bank Ledger section password. Additions, edits and deletions are visible from every profile. The Bank Ledger screen is labelled Shared.
- **Private:** sales, purchases, credit payments, returns, expenses, agency lists, reports based on private transactions, Sales section password, and each profile's backup-folder settings.
- The existing Bank Ledger section password is separate from the optional profile login password. When already configured, use the original first profile's ledger password from either profile.
- Existing ledger entries are not silently deduplicated during migration; identical records from different profiles are preserved. Review any historical duplicates yourself. Repeated bank-ledger entries are allowed without a duplicate warning.

## Login and photos

The start screen shows profile cards. Select a card to sign in. Password-free profiles open immediately; protected profiles show a password prompt. New passwords/PINs require at least 4 characters, so a 4-digit PIN works. Longer passwords are stronger. Anyone with access to this Windows session can open a password-free profile.

Photos are optional. Choose a PNG, JPEG or WebP under 5 MB. A square thumbnail is saved with local profile settings, so moving the original photo does not break it. Initials are shown when no photo is selected. Photos and profile passwords are local, not uploaded as part of database backups. Keep passwords safe; there is no email-based recovery.

## Backups and restore

Full profile exports, configured daily backups and cloud-folder uploads include that profile's private records plus a snapshot of the shared ledger. They do not include another profile's private transactions.

**Restoring/downloading a profile restores only its private records. It does not overwrite the shared bank ledger.** This prevents an older backup from one profile from undoing the other's recent ledger changes.

To restore the common ledger, use **Backup & Sync → Restore shared ledger**. Select either a standalone ledger export or a full HISAAB profile backup. Confirm that the operation affects every profile. A recovery copy is created first. Restart after restoring to refresh all screens. Use **Export shared ledger** to export only the common bank records, without private transactions.

Cloud-folder copies are backups of the shared ledger; ledger changes are shared live on this computer, not automatically downloaded/merged across computers. Restore a ledger snapshot explicitly when recovering it. This release is designed for profiles on the same Windows installation.

Database backups do not include the profile login registry or application settings. Keep those settings as well as all database files if moving to a new Windows account/computer. SQLite files are not encrypted; app login protection is not disk encryption.

## Storage and recovery

- Original private database: Documents/PharmacyManagement/pharmacy_management_v7.db (unchanged location).
- Additional private databases: pharmacy_profile_<stable-id>.db in the same folder.
- Common ledger: hisaab_shared_ledger_v1.db in that folder.
- Before ledger migration: each source database gets a .before_shared_ledger_v1.db recovery copy. Migration markers prevent repeated imports.
- Before restoring: a timestamped .before_restore_<timestamp>.db recovery copy is kept.
- Existing business tables, balances and IDs in private source files remain intact. Renaming a profile never changes its storage ID.

Do not switch back to an older app for normal work after upgrading: older versions do not know about the common ledger and would show stale private ledger copies.

## Test on your Windows laptop

Use test data or a copy of the client's export, never the only live database. Check profile selection, 4-digit PIN and no-password sign-in, photo persistence after restart, shared ledger add/edit/delete from both profiles, private records remaining separate, duplicate warnings, profile backup restore, and explicit shared-ledger restore. A fresh laptop has no client records until a backup is restored. When restoring onto a fresh test installation, restore the private profile and then explicitly restore its ledger snapshot.

The Windows build workflow runs automated tests, compiles the release, includes the SQLite runtime, verifies the bundle and checks that HISAAB.exe stays running. This launch check is not a substitute for your hands-on Windows acceptance test.
