import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/history_record.dart';
import '../../services/association.dart';

// 全局脑网：跨记录关联图谱（壁垒3 — 非线性动态双向链接图谱）
// 中心 = 用户「你」，外围 = 所有记录的概念节点，跨记录共享 2-gram 自动连线。
class GlobalMindWebView extends StatefulWidget {
  final List<HistoryRecord> historyList;
  final String? activeRecordId;

  const GlobalMindWebView({
    super.key,
    required this.historyList,
    this.activeRecordId,
  });

  @override
  State<GlobalMindWebView> createState() => _GlobalMindWebViewState();
}

class _GlobalMindWebViewState extends State<GlobalMindWebView> {
  final List<_GNode> _nodes = [];
  final List<_GEdge> _edges = [];
  Size _canvasSize = const Size(500, 320);
  String? _draggedId;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(covariant GlobalMindWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historyList != widget.historyList) _buildGraph();
  }

  void _buildGraph() {
    _nodes.clear();
    _edges.clear();
    final result = AssociationService.analyze(widget.historyList);
    // 用关联结果直接建图
    for (final node in result.nodes) {
      _nodes.add(_GNode(
        id: node.id,
        label: node.text,
        type: node.isAction ? 'todo' : (node.isInfo ? 'info' : 'insight'),
        importance: node.importance,
        recordId: node.recordId,
      ));
    }
    for (final link in result.links) {
      _edges.add(_GEdge(a: link.a, b: link.b, weight: link.shared));
    }
    _layout();
  }

  // 环形布局：中心「你」+ 节点均匀散布
  void _layout() {
    if (_nodes.isEmpty) return;
    final cx = _canvasSize.width / 2;
    final cy = _canvasSize.height / 2;
    final r = math.min(cx, cy) - 30;
    for (var i = 0; i < _nodes.length; i++) {
      final angle = (i / _nodes.length) * 2 * math.pi;
      _nodes[i].offset = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    }
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
              Icon(Icons.hub_outlined, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text('🕸️ 全局脑网（跨记录关联）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AI 自动把不同次倾泻里共享的主题连线 —— 越用越懂你',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          if (_nodes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('倾泻更多想法后，这里会连成你的专属大脑', style: TextStyle(color: Colors.grey))),
            )
          else
            SizedBox(
              height: 300,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  if ((constraints.maxWidth - _canvasSize.width).abs() > 1) {
                    _canvasSize = Size(constraints.maxWidth, 300);
                    _layout();
                  }
                  return Stack(
                    children: [
                      CustomPaint(
                        size: _canvasSize,
                        painter: _GWebPainter(
                          nodes: _nodes,
                          edges: _edges,
                          activeRecordId: widget.activeRecordId,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GNode {
  final String id;
  final String label;
  final String type;
  final double importance;
  final String recordId;
  Offset offset;
  _GNode({
    required this.id,
    required this.label,
    required this.type,
    required this.importance,
    required this.recordId,
    this.offset = Offset.zero,
  });
}

class _GEdge {
  final String a;
  final String b;
  final int weight;
  _GEdge({required this.a, required this.b, required this.weight});
}

class _GWebPainter extends CustomPainter {
  final List<_GNode> nodes;
  final List<_GEdge> edges;
  final String? activeRecordId;
  final bool isDark;

  _GWebPainter({required this.nodes, required this.edges, this.activeRecordId, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 中心枢纽「你」
    canvas.drawCircle(center, 22, Paint()..color = Colors.purpleAccent.withOpacity(0.25));
    canvas.drawCircle(center, 12, Paint()..color = isDark ? const Color(0xFF1E1E2F) : Colors.white);
    canvas.drawCircle(center, 12, Paint()..color = Colors.purpleAccent.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 1.6);

    final nodeById = {for (var n in nodes) n.id: n};
    // 边
    for (final e in edges) {
      final na = nodeById[e.a];
      final nb = nodeById[e.b];
      if (na == null || nb == null) continue;
      final isActive = activeRecordId != null && (na.recordId == activeRecordId || nb.recordId == activeRecordId);
      canvas.drawLine(
        na.offset,
        nb.offset,
        Paint()
          ..color = (isActive ? Colors.amberAccent : Colors.purpleAccent).withOpacity(isActive ? 0.55 : 0.18)
          ..strokeWidth = isActive ? 2.0 : 1.0,
      );
    }
    // 节点
    for (final n in nodes) {
      final isActive = activeRecordId != null && n.recordId == activeRecordId;
      final color = n.importance >= 0.7
          ? Colors.redAccent
          : (n.type == 'todo'
              ? Colors.greenAccent
              : (n.type == 'info' ? Colors.cyanAccent : Colors.purpleAccent));
      final r = 4.0 + n.importance * 5.0;
      canvas.drawCircle(n.offset, r + 3, Paint()..color = color.withOpacity(0.3));
      canvas.drawCircle(n.offset, r, Paint()..color = isActive ? Colors.amberAccent : color);
    }
  }

  @override
  bool shouldRepaint(covariant _GWebPainter old) => old.nodes != nodes || old.edges != edges || old.activeRecordId != activeRecordId;
}
