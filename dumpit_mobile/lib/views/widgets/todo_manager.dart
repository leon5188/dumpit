import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/history_record.dart';
import '../../services/mobile_sound_service.dart';

class TodoManager extends StatefulWidget {
  final List<HistoryRecord> historyList;
  final String? activeRecordId;
  final bool isZh;
  final Function(List<ImportanceItem>) onTodosChanged;
  final Function(String)? onGlobalTodoDeleted;
  final Function(ImportanceItem, bool)? onTodoChecked;

  const TodoManager({
    super.key,
    required this.historyList,
    required this.activeRecordId,
    required this.isZh,
    required this.onTodosChanged,
    this.onGlobalTodoDeleted,
    this.onTodoChecked,
  });

  @override
  State<TodoManager> createState() => _TodoManagerState();
}

class _TodoManagerState extends State<TodoManager> {
  final TextEditingController _controller = TextEditingController();
  late List<HistoryRecord> _localHistoryList;
  final Set<String> _checkedSet = {}; // 用 Set 管理多个正在消失的任务

  @override
  void initState() {
    super.initState();
    _localHistoryList = List.from(widget.historyList);
  }

  // 合并全局 actionItems
  List<ImportanceItem> get _sorted {
    final allItems = <ImportanceItem>[];
    for (var r in _localHistoryList) {
      if (r.folder != 'trash') {
        allItems.addAll(r.actionItems);
      }
    }
    return allItems..sort((a, b) => b.importance.compareTo(a.importance));
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.activeRecordId != null) {
      final activeIndex = _localHistoryList.indexWhere((r) => r.id == widget.activeRecordId);
      if (activeIndex != -1) {
        final active = _localHistoryList[activeIndex];
        final updated = List<ImportanceItem>.from(active.actionItems)
          ..insert(0, ImportanceItem(text: text, importance: 0.5));
        setState(() {
          _localHistoryList[activeIndex] = active.copyWith(actionItems: updated);
        });
        widget.onTodosChanged(updated);
      }
    }
    _controller.clear();
  }

  void _deleteTodo(ImportanceItem todo) {
    for (int i = 0; i < _localHistoryList.length; i++) {
      final r = _localHistoryList[i];
      if (r.folder != 'trash' && r.actionItems.any((e) => e.text == todo.text)) {
        final updated = List<ImportanceItem>.from(r.actionItems)..removeWhere((e) => e.text == todo.text);
        setState(() {
          _localHistoryList[i] = r.copyWith(actionItems: updated);
        });
        if (r.id == widget.activeRecordId) {
          widget.onTodosChanged(updated);
        } else {
          widget.onGlobalTodoDeleted?.call(todo.text);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = _sorted;

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
              const Icon(Icons.check_circle_outline, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isZh ? '✅ 全局待办事项 (跨记录汇总)' : '✅ Global Todos',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(widget.isZh ? '没有待办事项' : 'No Action Items', style: const TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final todo = sorted[index];
                final isChecked = _checkedSet.contains(todo.text);
                final isHot = todo.importance >= 0.7;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isChecked ? 0.0 : 1.0, // 消消乐变透明
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHot ? Colors.orangeAccent.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (isChecked) return; // 防止重复点击
                            setState(() {
                              _checkedSet.add(todo.text);
                            });
                            MobileSoundService().playChime();
                            if (isHot) {
                              HapticFeedback.heavyImpact(); // 强烈震动
                            } else {
                              HapticFeedback.mediumImpact();
                            }
                            widget.onTodoChecked?.call(todo, true);
                            
                            // 延迟彻底删除它
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted && _checkedSet.contains(todo.text)) {
                                _checkedSet.remove(todo.text);
                                _deleteTodo(todo);
                              }
                            });
                          },
                          child: Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isHot ? Colors.orangeAccent : Colors.purpleAccent,
                                width: 2,
                              ),
                              color: isChecked ? (isHot ? Colors.orangeAccent : Colors.purpleAccent) : Colors.transparent,
                            ),
                            child: isChecked
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            todo.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: isHot ? Colors.orangeAccent : (isDark ? Colors.white : Colors.black87),
                              fontWeight: isHot ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                          onPressed: () => _deleteTodo(todo),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.isZh ? '添加新待办...' : 'Add a new todo...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
              border: OutlineBinding.circular(8, isDark ? Colors.white24 : Colors.black12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.purpleAccent),
                onPressed: _addTodo,
              ),
            ),
            onSubmitted: (_) => _addTodo(),
          ),
        ],
      ),
    );
  }
}

class OutlineBinding {
  static OutlineInputBorder circular(double r, Color c) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(r),
      borderSide: BorderSide(color: c),
    );
  }
}
