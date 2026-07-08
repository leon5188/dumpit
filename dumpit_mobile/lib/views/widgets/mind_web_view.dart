import 'dart:math' as math;
import 'package:flutter/material.dart';

class _InteractiveNode {
  final String id;
  final String label;
  final String type; // 'insight' | 'todo'
  Offset offset;

  _InteractiveNode({
    required this.id,
    required this.label,
    required this.type,
    required this.offset,
  });
}

class MindWebView extends StatefulWidget {
  final List<String> keyInsights;
  final List<String> actionItems;

  const MindWebView({
    super.key,
    required this.keyInsights,
    required this.actionItems,
  });

  @override
  State<MindWebView> createState() => _MindWebViewState();
}

class _MindWebViewState extends State<MindWebView> {
  final List<_InteractiveNode> _nodes = [];
  String? _draggedNodeId;
  Size _canvasSize = const Size(500, 320);

  @override
  void initState() {
    super.initState();
    _initializeNodes();
  }

  @override
  void didUpdateWidget(covariant MindWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 数据更新时重新初始化拓扑节点
    if (oldWidget.keyInsights != widget.keyInsights ||
        oldWidget.actionItems != widget.actionItems) {
      _initializeNodes();
    }
  }

  void _initializeNodes() {
    _nodes.clear();
    final totalItems = widget.keyInsights.length + widget.actionItems.length;
    if (totalItems == 0) return;

    // 默认以画布中心为圆心
    final centerX = _canvasSize.width / 2;
    final centerY = _canvasSize.height / 2;
    const radius = 95.0;

    int idx = 0;
    for (final insight in widget.keyInsights) {
      final angle = (idx / totalItems) * 2 * math.pi;
      final labelText = insight.length > 12 ? '${insight.substring(0, 12)}...' : insight;
      _nodes.add(_InteractiveNode(
        id: 'insight-$idx',
        label: labelText,
        type: 'insight',
        offset: Offset(centerX + radius * math.cos(angle), centerY + radius * math.sin(angle)),
      ));
      idx++;
    }

    int todoIdx = 0;
    for (final todo in widget.actionItems) {
      final angle = (idx / totalItems) * 2 * math.pi;
      final labelText = todo.length > 12 ? '${todo.substring(0, 12)}...' : todo;
      _nodes.add(_InteractiveNode(
        id: 'todo-$todoIdx',
        label: labelText,
        type: 'todo',
        offset: Offset(centerX + radius * math.cos(angle), centerY + radius * math.sin(angle)),
      ));
      idx++;
      todoIdx++;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final localPos = details.localPosition;
    String? closestId;
    double minDistance = 35.0; // 触控半径阈值

    for (final node in _nodes) {
      final distance = (node.offset - localPos).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestId = node.id;
      }
    }

    setState(() {
      _draggedNodeId = closestId;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggedNodeId == null) return;
    
    // 边界溢出限幅，避免节点被拖出画布
    final x = details.localPosition.dx.clamp(20.0, _canvasSize.width - 20.0);
    final y = details.localPosition.dy.clamp(20.0, _canvasSize.height - 20.0);

    setState(() {
      for (final node in _nodes) {
        if (node.id == _draggedNodeId) {
          node.offset = Offset(x, y);
          break;
        }
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _draggedNodeId = null;
    });
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
              Icon(Icons.bubble_chart_outlined, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text(
                '🕸️ 原生脑力网状关联图',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // 自动适应屏幕宽度
              final width = constraints.maxWidth;
              if (width != _canvasSize.width) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _canvasSize = Size(width, 280);
                    _initializeNodes();
                  });
                });
              }

              return Container(
                width: width,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  ),
                ),
                child: _nodes.isEmpty
                    ? const Center(
                        child: Text(
                          '未识别到连线关系，请录入卡片内容',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : GestureDetector(
                        onPanStart: _handlePanStart,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _handlePanEnd,
                        child: CustomPaint(
                          size: _canvasSize,
                          painter: _MindWebPainter(
                            nodes: _nodes,
                            isDarkMode: isDark,
                          ),
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MindWebPainter extends CustomPainter {
  final List<_InteractiveNode> nodes;
  final bool isDarkMode;

  _MindWebPainter({required this.nodes, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制网状连线（虚线与发光效果）
    final linePaint = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < nodes.length; i++) {
      final start = nodes[i].offset;
      final end = nodes[(i + 1) % nodes.length].offset;
      
      // 绘制相近节点连线
      canvas.drawLine(start, end, linePaint);
      
      // 跨度连线，丰富网状结构
      if (nodes[i].type == 'todo' && nodes.length > 2) {
        canvas.drawLine(start, nodes[0].offset, linePaint);
      }
    }

    // 2. 绘制节点与文字标签
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final node in nodes) {
      final isInsight = node.type == 'insight';
      
      // 节点阴影发光 Paint
      final shadowPaint = Paint()
        ..color = (isInsight ? Colors.deepPurpleAccent : Colors.greenAccent).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      
      // 节点实体 Paint
      final nodePaint = Paint()
        ..color = isInsight ? Colors.purpleAccent : Colors.greenAccent
        ..style = PaintingStyle.fill;

      // 绘制发光阴影
      canvas.drawCircle(node.offset, 9.0, shadowPaint);
      // 绘制中心圆点
      canvas.drawCircle(node.offset, 6.0, nodePaint);

      // 绘制文字
      textPainter.text = TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: 9.5,
          color: isDarkMode ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w500,
          background: Paint()
            ..color = isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8)
            ..style = PaintingStyle.fill,
        ),
      );
      
      textPainter.layout();
      // 偏移文字，避免挡住小圆圈
      textPainter.paint(
        canvas,
        node.offset + const Offset(10, -5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MindWebPainter oldDelegate) => true;
}
