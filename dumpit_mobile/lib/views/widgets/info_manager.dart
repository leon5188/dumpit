import 'package:flutter/material.dart';
import '../../models/history_record.dart';

class InfoManager extends StatelessWidget {
  final List<ImportanceItem> infoItems;

  const InfoManager({super.key, required this.infoItems});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Text(
                '💡 原生备忘信息',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (infoItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '没有需要记住的备忘信息',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            ...infoItems.map((item) {
              final isHot = item.importance >= 0.7;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHot)
                      const Padding(
                        padding: EdgeInsets.only(right: 4, top: 2),
                        child: Text('⚡', style: TextStyle(fontSize: 12)),
                      ),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: isHot ? Colors.cyanAccent : null,
                          fontWeight: isHot ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
