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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF15111F), const Color(0xFF0B0A12)]
                        : [Colors.black.withOpacity(0.03), Colors.black.withOpacity(0.06)],
                  ),
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
                    : Stack(
                        children: [
                          GestureDetector(
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
                          Positioned(
                            top: 8,
                            right: 10,
                            child: _buildLegend(),
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

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendDot(Colors.purpleAccent, '灵感洞察'),
          const SizedBox(height: 3),
          _buildLegendDot(Colors.greenAccent, '待办事项'),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
      ],
    );
  }
}

class _MindWebPainter extends CustomPainter {
  final List<_InteractiveNode> nodes;
  final bool isDarkMode;

  _MindWebPainter({required this.nodes, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. 中心枢纽发光核心（代表本次脑力倾倒本身）
    canvas.drawCircle(
      center,
      36,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.purpleAccent.withOpacity(0.3), Colors.purpleAccent.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: 36)),
    );
    canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF1E1E2F));
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = Colors.purpleAccent.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 2. 每个节点向中心枢纽绘制柔和弧线（弯曲方向随节点位置变化，避免直线杂乱重叠）
    for (final node in nodes) {
      final isInsight = node.type == 'insight';
      final lineColor = isInsight ? Colors.purpleAccent : Colors.greenAccent;

      final mid = Offset.lerp(center, node.offset, 0.5)!;
      final normal = (node.offset - center);
      final normalLen = normal.distance;
      final bow = normalLen == 0
          ? Offset.zero
          : Offset(-normal.dy, normal.dx) / normalLen * 16;
      final control = mid + bow;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(control.dx, control.dy, node.offset.dx, node.offset.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withOpacity(0.16)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor.withOpacity(0.45)
          ..strokeWidth = 1.1
          ..style = PaintingStyle.stroke,
      );
    }

    // 3. 绘制节点（发光圆点 + 圆角文字胶囊）
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isInsight = node.type == 'insight';
      final color = isInsight ? Colors.purpleAccent : Colors.greenAccent;
      // 相邻节点交替上/下偏移，减少标签在水平相近时相互重叠
      final verticalOffset = i.isEven ? -6.0 : 14.0;

      canvas.drawCircle(
        node.offset,
        9.0,
        Paint()
          ..color = color.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(node.offset, 5.0, Paint()..color = color);
      canvas.drawCircle(
        node.offset,
        5.0,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // 靠近画布右边缘时把标签翻到节点左侧，避免文字溢出边界
      final labelOnLeft = node.offset.dx > size.width - 90;
      final maxLabelWidth = (labelOnLeft ? node.offset.dx : size.width - node.offset.dx) - 22;

      textPainter.text = TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: 9.5,
          color: isDarkMode ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.ellipsis = '…';
      textPainter.maxLines = 1;
      textPainter.layout(maxWidth: maxLabelWidth.clamp(30.0, double.infinity));

      final labelOffset = labelOnLeft
          ? node.offset + Offset(-11 - textPainter.width, verticalOffset)
          : node.offset + Offset(11, verticalOffset);
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          labelOffset.dx - 4,
          labelOffset.dy - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = (isDarkMode ? Colors.black : Colors.white).withOpacity(0.72),
      );
      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = color.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _MindWebPainter oldDelegate) => true;
}
