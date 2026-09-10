import 'package:flutter/material.dart';

const _ink = Color(0xFF071F33);
const _logoBlue = Color(0xFF004D8C);
const _yellow = Color(0xFFF6D03F);
const _surface = Color(0xFFFBFDFE);
const _line = Color(0xFFDCE8EC);
const _muted = Color(0xFF667D86);
const _softBlue = Color(0xFFE8F4FC);
const _softGold = Color(0xFFFFF3D8);

Future<bool> showWorkOrderStartDialog(
  BuildContext context, {
  required String code,
  required String module,
  required String title,
  required String detail,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: _surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF176DA8), _logoBlue, Color(0xFF004279)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _yellow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: _ink),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mulai pekerjaan ini?',
                          style: TextStyle(
                            color: _surface,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Periksa detail WO sebelum melanjutkan',
                          style: TextStyle(color: Color(0xFFD7EBEF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    color: _surface,
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pastikan Work Order yang dipilih sudah benar. Setelah dikonfirmasi, WO akan di mulai untuk dikerjakan',
                    style: TextStyle(color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _softBlue,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                module.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _logoBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                            ),
                            Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: _softGold,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 6, color: Color(0xFFB57900)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Belum dikerjakan',
                                    style: TextStyle(
                                      color: Color(0xFF8B6100),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (detail.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: _line),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(color: _muted, fontSize: 11),
                            children: [
                              const TextSpan(text: 'Kode WO: '),
                              TextSpan(
                                text: code,
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: _yellow,
                        foregroundColor: _ink,
                        child: Icon(Icons.check_rounded, size: 14),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(color: Color(0xFF72520B), fontSize: 12),
                            children: [
                              TextSpan(text: 'Status akan berubah menjadi '),
                              TextSpan(
                                text: 'Progress Pekerjaan',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: _ink,
                            side: const BorderSide(color: _line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: _yellow,
                            foregroundColor: _ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            'Ya, mulai',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
