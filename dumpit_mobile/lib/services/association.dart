import '../models/history_record.dart';

/// 跨记录关联 + 重要度聚合服务（纯客户端，不引第三方分词库）。
///
/// 用一个轻量 2-gram 重叠算法判断两条记录是否「相关」：
/// 把每条记录里的待办/灵感文本切成相邻 2 字片段，两条记录共享 ≥1 个 2-gram
/// 即视为关联，共享越多关联越强。无需中文分词器即可捕获「周会 / 会议」「猫砂盆 / 猫咪」等近似主题。

/// 单个概念节点（来自某条记录的某条待办、灵感或备忘）
class ConceptNode {
  final String id;        // 形如 "recId#0" 或 "recId#k2" 或 "recId#i2"
  final String recordId;  // 所属记录
  final String text;      // 原文
  final double importance; // 该条目的 AI 重要度
  final bool isAction;    // true=待办，false=灵感/备忘
  final bool isInfo;      // true=备忘信息

  ConceptNode({
    required this.id,
    required this.recordId,
    required this.text,
    required this.importance,
    required this.isAction,
    this.isInfo = false,
  });
}

/// 跨记录关联边：表示两条记录因共享 2-gram 而相关
class RecordLink {
  final String a; // recordId
  final String b; // recordId
  final int shared; // 共享的 2-gram 数量（关联强度）

  RecordLink({required this.a, required this.b, required this.shared});
}

/// 概念在全局的出现次数（复现越多 = 越重要、越值得关注）
class ConceptFrequency {
  final String gram;       // 2-gram 文本
  int count;               // 出现次数（跨记录）
  double maxImportance;    // 关联条目的最高重要度
  final Set<String> recordIds; // 出现在哪些记录

  ConceptFrequency({
    required this.gram,
    required this.count,
    required this.maxImportance,
    required this.recordIds,
  });
}

/// 关联分析结果
class AssociationResult {
  final List<ConceptNode> nodes;     // 所有概念节点
  final List<RecordLink> links;      // 跨记录关联边
  final Map<String, List<ConceptNode>> byRecord; // recordId -> 该记录的概念
  final Map<int, List<ConceptFrequency>> hotGrams; // 共享 gram 数阈值 -> 高频概念（排序后）

  AssociationResult({
    required this.nodes,
    required this.links,
    required this.byRecord,
    required this.hotGrams,
  });
}

class AssociationService {
  AssociationService._();

  /// 把所有记录拆成概念节点 + 计算跨记录 2-gram 关联
  static AssociationResult analyze(List<HistoryRecord> records) {
    final nodes = <ConceptNode>[];
    final byRecord = <String, List<ConceptNode>>{};

    for (final rec in records) {
      final recNodes = <ConceptNode>[];
      for (var i = 0; i < rec.actionItems.length; i++) {
        final it = rec.actionItems[i];
        final node = ConceptNode(
          id: '${rec.id}#a$i',
          recordId: rec.id,
          text: it.text,
          importance: it.importance,
          isAction: true,
        );
        nodes.add(node);
        recNodes.add(node);
      }
      for (var i = 0; i < rec.keyInsights.length; i++) {
        final it = rec.keyInsights[i];
        final node = ConceptNode(
          id: '${rec.id}#k$i',
          recordId: rec.id,
          text: it.text,
          importance: it.importance,
          isAction: false,
        );
        nodes.add(node);
        recNodes.add(node);
      }
      for (var i = 0; i < rec.infoItems.length; i++) {
        final it = rec.infoItems[i];
        final node = ConceptNode(
          id: '${rec.id}#i$i',
          recordId: rec.id,
          text: it.text,
          importance: it.importance,
          isAction: false,
          isInfo: true,
        );
        nodes.add(node);
        recNodes.add(node);
      }
      byRecord[rec.id] = recNodes;
    }

    // 计算每条记录的 2-gram 集合
    final gramSets = <String, Set<String>>{};
    for (final rec in records) {
      gramSets[rec.id] = _recordGrams(rec);
    }

    // 两两比较记录，生成关联边
    final links = <RecordLink>[];
    final gramFreq = <String, ConceptFrequency>{};
    for (var i = 0; i < records.length; i++) {
      for (var j = i + 1; j < records.length; j++) {
        final a = records[i].id;
        final b = records[j].id;
        final shared = gramSets[a]!.intersection(gramSets[b]!).toList();
        if (shared.isNotEmpty) {
          links.add(RecordLink(a: a, b: b, shared: shared.length));
          // 累计高频概念
          for (final g in shared) {
            final imp = _maxImportanceAmong(nodes, a, b, g);
            final existing = gramFreq[g];
            if (existing == null) {
              gramFreq[g] = ConceptFrequency(
                gram: g,
                count: 2,
                maxImportance: imp,
                recordIds: {a, b},
              );
            } else {
              existing.count += 1;
              existing.maxImportance = existing.maxImportance > imp ? existing.maxImportance : imp;
              existing.recordIds.add(a);
              existing.recordIds.add(b);
            }
          }
        }
      }
    }

    // 按共享 gram 数阈值归类高频概念（用于「反复出现的主题」高亮）
    final hotGrams = <int, List<ConceptFrequency>>{};
    for (final threshold in [3, 2, 1]) {
      final list = gramFreq.values
          .where((f) => f.count >= threshold)
          .toList()
        ..sort((x, y) => y.count.compareTo(x.count));
      hotGrams[threshold] = list;
    }

    return AssociationResult(
      nodes: nodes,
      links: links,
      byRecord: byRecord,
      hotGrams: hotGrams,
    );
  }

  /// 提取一条记录的全部 2-gram（去重集合）
  static Set<String> _recordGrams(HistoryRecord rec) {
    final grams = <String>{};
    for (final it in [...rec.actionItems, ...rec.keyInsights, ...rec.infoItems]) {
      grams.addAll(_bigrams(it.text));
    }
    return grams;
  }

  /// 把文本切成相邻 2 字片段（中英文通用，过滤纯空白/标点）
  static List<String> _bigrams(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length < 2) {
      return cleaned.isNotEmpty ? [cleaned] : [];
    }
    final out = <String>[];
    for (var i = 0; i < cleaned.length - 1; i++) {
      out.add(cleaned.substring(i, i + 2));
    }
    return out;
  }

  /// 在某两条记录的概念节点里，找出包含指定 gram 的条目中的最高重要度
  static double _maxImportanceAmong(
    List<ConceptNode> nodes,
    String a,
    String b,
    String gram,
  ) {
    var max = 0.0;
    for (final n in nodes) {
      if (n.recordId == a || n.recordId == b) {
        if (_bigrams(n.text).contains(gram) && n.importance > max) {
          max = n.importance;
        }
      }
    }
    return max;
  }
}
