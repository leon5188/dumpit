import '../models/history_record.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// importLocalHistory 的结果：failedIds 是导入失败的本地记录 id；
/// idMapping 是成功导入的记录的 本地(client) id -> 服务端新分配 id 映射，
/// 调用方应据此改写本地记录的 id，避免后续 pull 时与云端记录重复。
class ImportResult {
  final List<String> failedIds;
  final Map<String, String> idMapping;

  const ImportResult({required this.failedIds, required this.idMapping});
}

class SyncService {
  /// 首次登录时，把本地全部历史记录一次性导入云端
  static Future<ImportResult> importLocalHistory(List<HistoryRecord> localRecords) async {
    final sessionToken = await AuthService.getSessionToken();
    if (sessionToken == null || localRecords.isEmpty) {
      return const ImportResult(failedIds: [], idMapping: {});
    }

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
    final failedIds = List<String>.from(decoded['failed'] ?? []);
    final idMapping = <String, String>{
      for (final entry in (decoded['imported'] as List? ?? []))
        (entry as Map<String, dynamic>)['client_id'] as String: entry['server_id'] as String,
    };
    return ImportResult(failedIds: failedIds, idMapping: idMapping);
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
