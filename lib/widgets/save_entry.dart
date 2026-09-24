import 'package:flutter/material.dart';
import '../services/entry_service.dart';
import '../services/session_service.dart';

/// Returns true only when the save succeeds. Keeps form contents on failure.
Future<bool> saveEntry(
  BuildContext context,
  Future<void> Function(bool allowDuplicate) save,
) async {
  SessionService.instance.activeSaves++;
  try {
    return await _saveEntry(context, save);
  } finally {
    SessionService.instance.activeSaves--;
  }
}

Future<bool> _saveEntry(BuildContext context,
    Future<void> Function(bool allowDuplicate) save) async {
  try {
    await save(false);
    return true;
  } on DuplicateEntryException catch (error) {
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible duplicate entry'),
        content: Text(
            '$error\n\nSave another copy only if this is a separate, genuine entry.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save another copy')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    try {
      await save(true);
      return true;
    } catch (error) {
      if (context.mounted) _showError(context, error);
      return false;
    }
  } catch (error) {
    if (context.mounted) _showError(context, error);
    return false;
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(error is EntrySaveException
        ? error.message
        : 'Could not finish saving. Your form is still available. Check the entry list before retrying.'),
  ));
}
