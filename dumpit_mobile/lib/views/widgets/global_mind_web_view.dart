import 'package:flutter/material.dart';
import '../../models/history_record.dart';

// 全局脑网改版：摒弃容易杂乱的画布连线，改为将跨记录的「关键洞察 (Key Insights)」
// 统一聚合，按重要度或时间排布，做到「一条一条清晰地列出来」。
class GlobalMindWebView extends StatelessWidget {
  final List<HistoryRecord> historyList;
  final String? activeRecordId;
  final bool isZh;

  const GlobalMindWebView({
    super.key,
    required this.historyList,
    this.activeRecordId,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 收集所有有效记录的关键洞察
    final List<Map<String, dynamic>> allInsights = [];
    for (var r in historyList) {
      if (r.folder != 'trash') {
        for (var insight in r.keyInsights) {
          allInsights.add({
            'text': insight.text,
            'importance': insight.importance,
            'recordId': r.id,
            'date': r.timestamp,
          });
        }
      }
    }

    // 按重要度排序，优先展示最关键的启发
    allInsights.sort((a, b) => (b['importance'] as double).compareTo(a['importance'] as double));

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
              const Icon(Icons.hub_outlined, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 8),
              Text(isZh ? '🕸️ 全局思维洞察 (核心梳理)' : '🕸️ Global Insights', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isZh ? '这里汇聚了你过去所有的核心启发，不再散落各处，真正构建你的智库。' : 'All your key insights gathered across time, building your personal knowledge base.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (allInsights.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(isZh ? '倾泻更多想法后，AI提取的关键洞察将在这里汇总。' : 'Dump more thoughts, and AI-extracted insights will appear here.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allInsights.length,
              itemBuilder: (context, index) {
                final insight = allInsights[index];
                final bool isActive = insight['recordId'] == activeRecordId;
                final bool isHot = insight['importance'] >= 0.7;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Colors.purpleAccent.withOpacity(0.15) 
                        : (isDark ? Colors.black.withOpacity(0.2) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive 
                          ? Colors.purpleAccent.withOpacity(0.5) 
                          : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isHot ? Icons.local_fire_department : Icons.lightbulb_outline,
                          size: 16,
                          color: isHot ? Colors.orangeAccent : Colors.purpleAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              insight['text'],
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: isHot ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isZh ? '源自 · ${insight['date']}' : 'From · ${insight['date']}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
