import '../models/history_record.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SyncService {
  /// 首次登录时，把本地全部历史记录一次性导入云端，返回导入失败的本地记录 id 列表
  static Future<List<String>> importLocalHistory(List<HistoryRecord> localRecords) async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null || localRecords.isEmpty) return [];

    final records = localRecords.map((r) => {
      'client_id': r.id,
      'summary': {
        'summary': r.summary,
        'action_items': r.actionItems,
        'key_insights': r.keyInsights,
        'calendar_events': r.calendarEvents.map((e) => e.toJson()).toList(),
      },
      'raw_text': r.rawText,
    }).toList();

    final decoded = await ApiService.importHistory(sessionToken, records);
    return List<String>.from(decoded['failed'] ?? []);
  }

  /// 新建一条记录后同步到云端；失败时调用方应把该记录标记为"待同步"，不要阻塞当前操作
  static Future<bool> pushRecord(HistoryRecord record) async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null) return false;

    try {
      await ApiService.createHistory(
        sessionToken,
        {
          'summary': record.summary,
          'action_items': record.actionItems,
          'key_insights': record.keyInsights,
          'calendar_events': record.calendarEvents.map((e) => e.toJson()).toList(),
        },
        record.rawText,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 拉取云端全部历史记录，换设备/重装后调用
  static Future<List<HistoryRecord>> pullAllHistory() async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null) return [];

    final decoded = await ApiService.listHistory(sessionToken);
    final rawRecords = decoded['records'] as List? ?? [];

    return rawRecords.map((r) {
      final summary = r['summary'] as Map<String, dynamic>;
      return HistoryRecord(
        id: r['id'] as String,
        timestamp: (r['created_at'] as String? ?? '').replaceFirst('T', ' '),
        rawText: r['raw_text'] as String? ?? '',
        summary: summary['summary'] as String? ?? '',
        actionItems: List<String>.from(summary['action_items'] ?? []),
        keyInsights: List<String>.from(summary['key_insights'] ?? []),
        calendarEvents: ((summary['calendar_events'] as List?) ?? [])
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: 'done',
        folder: (r['archived'] == true) ? 'archive' : 'inbox',
      );
    }).toList();
  }
}
