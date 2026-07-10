import 'package:flutter/material.dart';
import '../../models/history_record.dart';
import '../../services/device_sync_service.dart';
import 'todo_manager.dart';
import 'mind_web_view.dart';
import 'timeline_view.dart';

// 📑 嵌套 TabView 的 AI 梳理详情 BottomSheet 浮层组件
class RestructuredDetailsSheet extends StatefulWidget {
  final bool isZh;
  final String summary;
  final List<String> actionItems;
  final List<String> keyInsights;
  final List<CalendarEvent> calendarEvents;
  final VoidCallback onArchive;
  final VoidCallback onDestroy;
  final VoidCallback onSyncNotion;
  final Function(List<String>) onTodosChanged;

  const RestructuredDetailsSheet({
    super.key,
    required this.isZh,
    required this.summary,
    required this.actionItems,
    required this.keyInsights,
    required this.calendarEvents,
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

  @override
  void initState() {
    super.initState();
    _sheetTabController = TabController(length: 4, vsync: this);
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
              Text(
                widget.isZh ? '🧠 BrainVent. 整理结果' : '🧠 BrainVent Result',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
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
                        final success = await DeviceSyncService.syncReminders(widget.actionItems);
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
                    icon: const Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                    onPressed: widget.onSyncNotion,
                  ),
                  IconButton(
                    icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 20),
                    onPressed: widget.onArchive,
                  ),
                  IconButton(
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
                // Tab 3: 可拖拽网状图
                MindWebView(
                  keyInsights: widget.keyInsights,
                  actionItems: widget.actionItems,
                ),
                // Tab 4: 纵向时间轴日程
                TimelineView(events: widget.calendarEvents),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
