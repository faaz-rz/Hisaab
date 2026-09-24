# HISAAB 1.1 — separate profiles

## Updating the client's Windows installation

1. In the old app, use **Backup & Sync → Export Backup** and keep the resulting `.db` file.
2. Close HISAAB. Keep a copy of the old release folder.
3. Extract the complete new Windows release to a separate application folder. Keep `HISAAB.exe`, its DLLs and the `data` folder together. Use the same Windows account as before.
4. Open the new `HISAAB.exe`. Choose a name and password for the **first profile**. This profile automatically uses the existing business records.
5. Sign in and check the transactions, expenses, ledger, and totals before entering new data.
6. Click the profile name near the bottom of the sidebar (or the Profiles icon on a narrow screen), then **Add profile**. Give the second profile its own name and password.
7. Use **Sign out / Switch profile**, choose the second profile and sign in. It starts with empty records and the same features.

Do not delete the client's Documents/PharmacyManagement folder or clear HISAAB's application settings during the update. No uninstall is required. Replacing the executable alone is insufficient: distribute the whole release folder.

## Data compatibility

- The first profile retains `Documents/PharmacyManagement/pharmacy_management_v7.db`. The actual Documents folder follows Windows configuration, including a redirected Documents folder.
- Additional profiles use `pharmacy_profile_<stable-id>.db` in the same folder. Renaming a profile does not change its ID or move its records.
- The database version remains 1. Existing business tables and IDs remain intact. An additive `hisaab_profile` metadata table identifies backup ownership.
- Before the first upgraded login opens/migrates/syncs an existing database, a consistent recovery copy is created alongside it: `<database-name>.before_multi_user_v1.db`. This copy is not overwritten on subsequent launches.
- Existing Sales/Bank Ledger passwords and backup settings remain with the first profile. Additional profiles have independent settings and section passwords.
- No existing duplicate entries are removed. New or edited entries with matching details show a warning. Users can go back or explicitly save a genuine repeated entry.
- Dates are compared by displayed calendar day; text matching ignores ASCII case and surrounding spaces. Different amounts, accounts or other details are not treated as identical.

## Backup behavior

Each profile has independent backup/cloud settings and distinct backup filenames, even if both select the same OneDrive folder. A backup tagged with another profile's ID is rejected. Older untagged backups can be restored into the first profile. A recovery copy is retained before a valid restore replaces current data. Corrupt or invalid backups are rejected before replacement.

Database exports contain business records, not the profile login registry or local settings. Keep HISAAB's application settings as well as database files if moving to a new Windows account/computer. This release's profile management is designed for the same Windows installation; new-computer account recovery is not provided by a database-only restore.

These are local app logins with salted PBKDF2 password hashes. The SQLite files themselves are not encrypted. Keep passwords safely; there is no email-based password recovery.

## Release verification

Run `flutter test` and `flutter analyze --no-fatal-infos --no-fatal-warnings`. The Windows GitHub Actions workflow pins Flutter 3.47.1, runs tests, builds the release, bundles the SQLite DLL from the pinned sqflite_common_ffi package, checks for `HISAAB.exe`, and performs a basic process launch check. For a manual Windows build, run `dart run tooling/bundle_windows_sqlite.dart` after `flutter build windows --release`. A Windows launch check alone does not exercise every feature.

Before sending the Windows ZIP, test a copy of the client's exported database in a separate Windows test account: upgrade, compare record counts and totals, create/switch profiles, test duplicate warning/cancel/confirm, and export/restore each profile. Never use the client's only live database for testing.
