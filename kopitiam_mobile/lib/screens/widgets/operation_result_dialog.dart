import 'package:flutter/material.dart';

Future<void> showOperationResultDialog(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) {
  const navy = Color(0xFF071B30);
  const blue = Color(0xFF004D8C);
  const green = Color(0xFF16A34A);
  const red = Color(0xFFDC2626);
  const muted = Color(0xFF64748B);
  const greenSoft = Color(0xFFECFDF5);
  const redSoft = Color(0xFFFEF2F2);

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99071B30),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: success ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33071B30),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: success ? greenSoft : redSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: success ? green : red,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: FilledButton.styleFrom(
                  backgroundColor: success ? blue : red,
                  foregroundColor: const Color(0xFFFDFEFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
