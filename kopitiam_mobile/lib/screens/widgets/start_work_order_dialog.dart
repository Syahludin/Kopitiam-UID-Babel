import 'package:flutter/material.dart';

Future<bool> confirmStartWorkOrder(
  BuildContext context, {
  required String code,
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text('Mulai $title?'),
      content: Text('Apakah Anda ingin mulai mengerjakan WO dengan kode: $code?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Tidak'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ya, mulai'),
        ),
      ],
    ),
  );
  return result == true;
}
