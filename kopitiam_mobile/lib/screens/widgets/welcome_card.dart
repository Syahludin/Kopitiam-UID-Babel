import 'package:flutter/material.dart';

class WelcomeCard extends StatelessWidget {
  final Map<String, dynamic> sesi;

  const WelcomeCard({super.key, required this.sesi});

  static const navy700 = Color(0xFF004D8C);
  static const navy950 = Color(0xFF071B30);
  static const green400 = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    final username = (sesi['username'] ?? 'Pengguna').toString();
    final subTim = (sesi['subTim'] ?? sesi['tim'] ?? '-').toString();
    final ulp = (sesi['ulp'] ?? '-').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: navy700,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: navy950.withValues(alpha: .10)),
        boxShadow: const [
          BoxShadow(color: Color(0x14004D8C), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selamat datang,',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: green400),
                    SizedBox(width: 6),
                    Text('Sesi Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: .16)),
          const SizedBox(height: 16),
          _info(Icons.groups_rounded, 'Sub-Tim', subTim),
          const SizedBox(height: 12),
          _info(Icons.location_city_rounded, 'ULP', ulp),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 16, color: Colors.white.withValues(alpha: .70)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .70))),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value.isEmpty ? '-' : value, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    ],
  );
}
