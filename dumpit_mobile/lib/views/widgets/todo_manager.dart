import 'package:flutter/material.dart';

class TodoManager extends StatefulWidget {
  final List<String> actionItems;
  final Function(List<String>) onTodosChanged;

  const TodoManager({
    super.key,
    required this.actionItems,
    required this.onTodosChanged,
  });

  @override
  State<TodoManager> createState() => _TodoManagerState();
}

class _TodoManagerState extends State<TodoManager> {
  final TextEditingController _controller = TextEditingController();
  final Map<int, bool> _checkedMap = {};

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final updated = List<String>.from(widget.actionItems)..add(text);
    widget.onTodosChanged(updated);
    _controller.clear();
  }

  void _deleteTodo(int index) {
    final updated = List<String>.from(widget.actionItems)..removeAt(index);
    setState(() {
      _checkedMap.remove(index);
      // 索引需要重新对齐
      final temp = <int, bool>{};
      _checkedMap.forEach((key, val) {
        if (key > index) {
          temp[key - 1] = val;
        } else if (key < index) {
          temp[key] = val;
        }
      });
      _checkedMap.clear();
      _checkedMap.addAll(temp);
    });
    widget.onTodosChanged(updated);
  }

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
              Icon(Icons.check_circle_outline, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text(
                '✅ 原生待办事项管理器',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.actionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '双击这里或下方添加你的第一个具体行动...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.actionItems.length,
              itemBuilder: (context, index) {
                final todo = widget.actionItems[index];
                final isChecked = _checkedMap[index] ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _checkedMap[index] = !isChecked;
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isChecked ? Colors.pinkAccent : Colors.grey,
                              width: 1.5,
                            ),
                            color: isChecked ? Colors.pinkAccent.withOpacity(0.2) : Colors.transparent,
                          ),
                          child: isChecked
                              ? const Icon(Icons.check, size: 14, color: Colors.pinkAccent)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          todo,
                          style: TextStyle(
                            fontSize: 14,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked ? Colors.grey : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                        onPressed: () => _deleteTodo(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '输入具体行动，回车添加...',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _addTodo(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addTodo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
