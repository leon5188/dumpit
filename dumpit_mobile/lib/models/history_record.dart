import 'dart:convert';

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
  final List<String> actionItems;
  final List<String> keyInsights;
  final List<CalendarEvent> calendarEvents;
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
    required this.calendarEvents,
    required this.status,
    required this.folder,
    this.offlineAudio,
    this.toneSample,
    this.prompt,
  });

  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    var actionItemsJson = json['actionItems'] ?? [];
    List<String> actions = List<String>.from(actionItemsJson);

    var keyInsightsJson = json['keyInsights'] ?? [];
    List<String> insights = List<String>.from(keyInsightsJson);

    var calendarEventsJson = json['calendarEvents'] as List? ?? [];
    List<CalendarEvent> calendars = calendarEventsJson
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    return HistoryRecord(
      id: json['id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      rawText: json['rawText'] ?? '',
      summary: json['summary'] ?? '',
      actionItems: actions,
      keyInsights: insights,
      calendarEvents: calendars,
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
      'actionItems': actionItems,
      'keyInsights': keyInsights,
      'calendarEvents': calendarEvents.map((e) => e.toJson()).toList(),
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
    List<String>? actionItems,
    List<String>? keyInsights,
    List<CalendarEvent>? calendarEvents,
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
      calendarEvents: calendarEvents ?? this.calendarEvents,
      status: status ?? this.status,
      folder: folder ?? this.folder,
      offlineAudio: offlineAudio ?? this.offlineAudio,
      toneSample: toneSample ?? this.toneSample,
      prompt: prompt ?? this.prompt,
    );
  }
}
