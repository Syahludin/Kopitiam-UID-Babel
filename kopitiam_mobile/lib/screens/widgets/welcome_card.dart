import 'package:flutter/material.dart';

import '../../theme/kopitiam_theme.dart';

class WelcomeCard extends StatelessWidget {
  final Map<String, dynamic> sesi;

  const WelcomeCard({super.key, required this.sesi});

  @override
  Widget build(BuildContext context) {
    final username = (sesi['username'] ?? 'Pengguna').toString();
    final subTim = (sesi['subTim'] ?? sesi['tim'] ?? '-').toString();
    final ulp = (sesi['ulp'] ?? '-').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: KopitiamColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E7892)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24063B5C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selamat datang',
                  style: TextStyle(
                    color: Color(0xFFC5DFE7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E526B),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: KopitiamColors.yellow),
                    SizedBox(width: 7),
                    Text(
                      'SESI AKTIF',
                      style: TextStyle(
                        color: KopitiamColors.surface,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KopitiamColors.surface,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF286A80)),
          const SizedBox(height: 12),
          _info(Icons.groups_rounded, 'Sub-Tim', subTim),
          const SizedBox(height: 11),
          _info(Icons.location_city_rounded, 'ULP', ulp),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF9FC8D4)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB8D5DE),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: KopitiamColors.surface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}
