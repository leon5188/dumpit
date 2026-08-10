import 'package:flutter/material.dart';
import '../../models/history_record.dart';

class InfoManager extends StatelessWidget {
  final List<HistoryRecord> historyList;
  final String? activeRecordId;
  final bool isZh;

  const InfoManager({
    super.key,
    required this.historyList,
    required this.activeRecordId,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    // 聚合全局 infoItems
    final allInfos = <ImportanceItem>[];
    for (var r in historyList) {
      if (r.folder != 'trash') {
        allInfos.addAll(r.infoItems);
      }
    }
    // 简易去重/按重要度排序
    final sortedInfos = allInfos.toSet().toList()
      ..sort((a, b) => b.importance.compareTo(a.importance));

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
            children: [
              const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                isZh ? '💡 全局备忘知识库' : '💡 Global Knowledge Base',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedInfos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isZh ? '全局未提取到需要记住的备忘信息' : 'No general information extracted.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            ...sortedInfos.map((item) {
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
