import 'package:flutter/material.dart';
import '../../models/history_record.dart';

class TimelineView extends StatelessWidget {
  final List<HistoryRecord> historyList;
  final bool isZh;

  const TimelineView({
    super.key,
    required this.historyList,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context) {
    // 全局提取所有未归档记录中的事件并按时间合并排序
    final allEvents = <CalendarEvent>[];
    final allHighPriority = <ImportanceItem>[];
    
    for (var r in historyList) {
      if (r.folder != 'trash') {
        allEvents.addAll(r.calendarEvents);
        allHighPriority.addAll(r.actionItems.where((e) => e.importance >= 0.7));
      }
    }

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
              const Icon(Icons.calendar_today_outlined, color: Colors.pinkAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                isZh ? '📅 全局时间轴 (跨记录汇总)' : '📅 Global Timeline',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (allEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isZh ? '全局未提取到日程，请录音倾倒包含时间的任务' : 'No upcoming events found.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 高优先级待办（importance>=0.7）红色高亮区：直观联动 AI 重要度
                if (allHighPriority.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text(
                              '全局高优待办 (近期穿插)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...allHighPriority.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  const Icon(Icons.priority_high, size: 14, color: Colors.redAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
                ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allEvents.length,
              itemBuilder: (context, index) {
                final event = allEvents[index];
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      // 时间轴线与圆点
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.purpleAccent, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purpleAccent.withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: index == allEvents.length - 1
                                  ? Colors.transparent
                                  : Colors.purpleAccent.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // 日程卡片内容
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black.withOpacity(0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: Colors.pinkAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    event.time,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.pinkAccent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
              ],
            ),
        ],
      ),
    );
  }
}
