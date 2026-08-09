import 'package:flutter/material.dart';
import '../../models/history_record.dart';
import '../../services/device_sync_service.dart';
import 'todo_manager.dart';
import 'mind_web_view.dart';
import 'timeline_view.dart';
import 'info_manager.dart';
import 'global_mind_web_view.dart';

// 📑 嵌套 TabView 的 AI 梳理详情 BottomSheet 浮层组件
class RestructuredDetailsSheet extends StatefulWidget {
  final bool isZh;
  final String summary;
  final List<ImportanceItem> actionItems;
  final List<ImportanceItem> keyInsights;
  final List<ImportanceItem> infoItems;
  final String emotion;
  final List<CalendarEvent> calendarEvents;
  final List<HistoryRecord> historyList; // 全量历史，用于跨记录关联图谱
  final String? activeRecordId; // 当前查看的记录
  final VoidCallback onArchive;
  final VoidCallback onDestroy;
  final VoidCallback onSyncNotion;
  final Function(List<ImportanceItem>) onTodosChanged;

  const RestructuredDetailsSheet({
    super.key,
    required this.isZh,
    required this.summary,
    required this.actionItems,
    required this.keyInsights,
    required this.infoItems,
    this.emotion = '',
    required this.calendarEvents,
    this.historyList = const [],
    this.activeRecordId,
    required this.onArchive,
    required this.onDestroy,
    required this.onSyncNotion,
    required this.onTodosChanged,
  });

  @override
  State<RestructuredDetailsSheet> createState() => _RestructuredDetailsSheetState();
}

class _RestructuredDetailsSheetState extends State<RestructuredDetailsSheet> with SingleTickerProviderStateMixin {
  late TabController _sheetTabController;
  bool _isFocusPlaying = false;
  bool _globalWeb = false; // 网状图 Tab：true=全局跨记录脑网，false=当前记录

  @override
  void initState() {
    super.initState();
    _sheetTabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _sheetTabController.dispose();
    DeviceSyncService.toggleFocusSound(false); // 退出面板时静音释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // 占屏幕 80% 高度
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 顶部收折条
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // 按钮与动作
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.isZh ? '🧠 BrainVent. 整理结果' : '🧠 BrainVent Result',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (widget.emotion.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _emotionColor(widget.emotion).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _emotionColor(widget.emotion).withOpacity(0.5)),
                  ),
                  child: Text(
                    '${_emotionEmoji(widget.emotion)} ${widget.emotion}',
                    style: TextStyle(color: _emotionColor(widget.emotion), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isFocusPlaying ? Icons.psychology : Icons.psychology_outlined,
                      color: _isFocusPlaying ? Colors.purpleAccent : Colors.grey,
                      size: 20,
                    ),
                    tooltip: widget.isZh ? 'ADHD 专注脑波音' : 'ADHD Focus Beats',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() {
                        _isFocusPlaying = !_isFocusPlaying;
                      });
                      await DeviceSyncService.toggleFocusSound(_isFocusPlaying);
                      if (mounted) {
                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              _isFocusPlaying
                                  ? (widget.isZh
                                      ? '🧠 专注脑波已开启 (8Hz Alpha 双耳差频)，佩戴耳机效果最佳'
                                      : '🧠 Focus Beats active (8Hz Alpha Binaural), headphones recommended')
                                  : (widget.isZh ? '🔇 专注脑波已关闭' : '🔇 Focus Beats paused'),
                            ),
                            backgroundColor: _isFocusPlaying ? Colors.purple : Colors.grey[800],
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.notifications_active_outlined, color: Colors.lightBlueAccent, size: 20),
                    tooltip: widget.isZh ? '同步至系统提醒' : 'Sync to Reminders',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (widget.actionItems.isEmpty) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(widget.isZh ? '⚠️ 没有提取到待办事项' : '⚠️ No tasks to sync'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(widget.isZh ? '正在同步到系统提醒事项...' : 'Syncing to Reminders...'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                      try {
                        final success = await DeviceSyncService.syncReminders(widget.actionItems.map((e) => e.text).toList());
                        if (success && mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(widget.isZh ? '🎉 已同步到系统提醒事项！' : '🎉 Synced to Reminders successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(widget.isZh ? '⚠️ 同步失败：未获得权限' : '⚠️ Sync failed: Permission denied'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(widget.isZh ? '⚠️ 同步失败: $e' : '⚠️ Sync failed: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                    onPressed: widget.onSyncNotion,
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 20),
                    onPressed: widget.onArchive,
                  ),
                  IconButton(
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: widget.onDestroy,
                  ),
                ],
              )
            ],
          ),
          // 霓虹 TabBar
          TabBar(
            controller: _sheetTabController,
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.purpleAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: widget.isZh ? '📝 重构' : '📝 Summary'),
              Tab(text: widget.isZh ? '✅ 待办' : '✅ Todos'),
              Tab(text: widget.isZh ? '🕸️ 网状图' : '🕸️ Web'),
              Tab(text: widget.isZh ? '💡 备忘' : '💡 Info'),
              Tab(text: widget.isZh ? '📅 时间轴' : '📅 Timeline'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _sheetTabController,
              children: [
                // Tab 1: 整理文
                SingleChildScrollView(
                  child: Text(
                    widget.summary,
                    style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
                  ),
                ),
                // Tab 2: 待办清单
                TodoManager(
                  actionItems: widget.actionItems,
                  onTodosChanged: widget.onTodosChanged,
                ),
                // Tab 3: 网状图（可在「本条」与「全局脑网」间切换）
                Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        ToggleButtons(
                          isSelected: [!_globalWeb, _globalWeb],
                          onPressed: (i) => setState(() => _globalWeb = i == 1),
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: Colors.purpleAccent.withOpacity(0.3),
                          color: Colors.grey,
                          constraints: const BoxConstraints(minHeight: 30, minWidth: 70),
                          children: [
                            Text(widget.isZh ? '本条' : 'This'),
                            Text(widget.isZh ? '全局脑网' : 'Global'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _globalWeb
                          ? GlobalMindWebView(
                              historyList: widget.historyList,
                              activeRecordId: widget.activeRecordId,
                            )
                          : MindWebView(
                              keyInsights: widget.keyInsights,
                              actionItems: widget.actionItems,
                              infoItems: widget.infoItems,
                            ),
                    ),
                  ],
                ),
                // Tab 4: 备忘信息
                InfoManager(infoItems: widget.infoItems),
                // Tab 5: 纵向时间轴日程
                TimelineView(
                  events: widget.calendarEvents,
                  highPriority: widget.actionItems
                      .where((e) => e.importance >= 0.7)
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 情绪标签 → 配色（直观区分 ADHD 倾泻时的情绪状态）
Color _emotionColor(String emotion) {
  switch (emotion) {
    case '焦虑':
      return Colors.orangeAccent;
    case '兴奋':
    case '期待':
      return Colors.amberAccent;
    case '平静':
    case '满足':
      return Colors.greenAccent;
    case '混乱':
      return Colors.purpleAccent;
    case '疲惫':
      return Colors.blueGrey;
    case '沮丧':
      return Colors.blueAccent;
    default:
      return Colors.grey;
  }
}

// 情绪标签 → emoji
String _emotionEmoji(String emotion) {
  switch (emotion) {
    case '焦虑':
      return '😰';
    case '兴奋':
      return '🤩';
    case '期待':
      return '🤗';
    case '平静':
      return '😌';
    case '满足':
      return '😊';
    case '混乱':
      return '🌀';
    case '疲惫':
      return '😮‍💨';
    case '沮丧':
      return '😔';
    default:
      return '💭';
  }
}
