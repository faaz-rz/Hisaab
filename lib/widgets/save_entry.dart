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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(error.isPurchase
            ? Icons.receipt_long_outlined
            : Icons.event_busy_outlined),
        title: Text(error.title),
        content: Text(error.toString()),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(error.backLabel)),
        ],
      ),
    );
    return false;
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
