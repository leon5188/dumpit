import 'dart:convert';

// 带重要度评分的结构化条目（待办 / 灵感通用）
class ImportanceItem {
  final String text;
  final double importance; // 0.0~1.0，由后端 AI 判定；旧数据/缺省为 0.5

  const ImportanceItem({
    required this.text,
    this.importance = 0.5,
  });

  factory ImportanceItem.fromJson(Map<String, dynamic> json) {
    final raw = (json['importance'] is num) ? (json['importance'] as num).toDouble() : 0.5;
    return ImportanceItem(
      text: json['text']?.toString() ?? '',
      importance: raw.clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'importance': importance,
      };
}

class CalendarEvent {
  final String title;
  final String time;

  CalendarEvent({required this.title, required this.time});

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      title: json['title'] ?? '',
      time: json['time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'time': time,
    };
  }
}

class HistoryRecord {
  final String id;
  final String timestamp;
  final String rawText;
  final String summary;
  final List<ImportanceItem> actionItems;
  final List<ImportanceItem> keyInsights;
  final List<ImportanceItem> infoItems; // 备忘信息维度（新壁垒）
  final List<CalendarEvent> calendarEvents;
  final String emotion; // 情绪标签（如 焦虑/兴奋/平静/混乱）
  final String status; // 'done', 'offline_pending', 'syncing', 'error'
  final String folder; // 'inbox', 'archive', 'trash'
  final String? offlineAudio; // Base64 audio if offline
  final String? toneSample;
  final String? prompt;

  HistoryRecord({
    required this.id,
    required this.timestamp,
    required this.rawText,
    required this.summary,
    required this.actionItems,
    required this.keyInsights,
    required this.infoItems,
    required this.calendarEvents,
    this.emotion = '',
    required this.status,
    required this.folder,
    this.offlineAudio,
    this.toneSample,
    this.prompt,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    // 兼容新旧后端：优先读 v2 对象数组（action_items_v2 / key_insights_v2 / info_items_v2），
    // 缺失时回退旧字符串数组（action_items / key_insights / info_items）。
    List<ImportanceItem> parseItems(dynamic v2, dynamic legacy) {
      if (v2 is List) {
        final items = v2
            .whereType<Map<String, dynamic>>()
            .map((e) => ImportanceItem.fromJson(e))
            .toList();
        if (items.isNotEmpty) return items;
      }
      if (legacy is List) {
        return legacy
            .whereType<String>()
            .map((t) => ImportanceItem(text: t, importance: 0.5))
            .toList();
      }
      return [];
    }

    var calendarEventsJson = json['calendarEvents'] as List? ?? [];
    List<CalendarEvent> calendars = calendarEventsJson
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    return HistoryRecord(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      rawText: json['rawText'] ?? '',
      summary: json['summary'] ?? '',
      actionItems: parseItems(json['action_items_v2'], json['action_items']),
      keyInsights: parseItems(json['key_insights_v2'], json['key_insights']),
      infoItems: parseItems(json['info_items_v2'], json['info_items']),
      calendarEvents: calendars,
      emotion: json['emotion']?.toString() ?? '',
      status: json['status'] ?? 'done',
      folder: json['folder'] ?? 'inbox',
      offlineAudio: json['offlineAudio'],
      toneSample: json['toneSample'],
      prompt: json['prompt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'rawText': rawText,
      'summary': summary,
      'action_items_v2': actionItems.map((e) => e.toJson()).toList(),
      'key_insights_v2': keyInsights.map((e) => e.toJson()).toList(),
      'info_items_v2': infoItems.map((e) => e.toJson()).toList(),
      // 旧字段保留，供未升级的客户端/同步消费方兼容
      'action_items': actionItems.map((e) => e.text).toList(),
      'key_insights': keyInsights.map((e) => e.text).toList(),
      'info_items': infoItems.map((e) => e.text).toList(),
      'calendarEvents': calendarEvents.map((e) => e.toJson()).toList(),
      'emotion': emotion,
      'status': status,
      'folder': folder,
      'offlineAudio': offlineAudio,
      'toneSample': toneSample,
      'prompt': prompt,
    };
  }

  HistoryRecord copyWith({
    String? id,
    String? timestamp,
    String? rawText,
    String? summary,
    List<ImportanceItem>? actionItems,
    List<ImportanceItem>? keyInsights,
    List<ImportanceItem>? infoItems,
    List<CalendarEvent>? calendarEvents,
    String? emotion,
    String? status,
    String? folder,
    String? offlineAudio,
    String? toneSample,
    String? prompt,
  }) {
    return HistoryRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      rawText: rawText ?? this.rawText,
      summary: summary ?? this.summary,
      actionItems: actionItems ?? this.actionItems,
      keyInsights: keyInsights ?? this.keyInsights,
      infoItems: infoItems ?? this.infoItems,
      calendarEvents: calendarEvents ?? this.calendarEvents,
      emotion: emotion ?? this.emotion,
      status: status ?? this.status,
      folder: folder ?? this.folder,
      offlineAudio: offlineAudio ?? this.offlineAudio,
      toneSample: toneSample ?? this.toneSample,
      prompt: prompt ?? this.prompt,
    );
  }
}
