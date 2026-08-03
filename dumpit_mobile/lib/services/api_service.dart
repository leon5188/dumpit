import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Go 后端默认 API 地址
  // 在 iOS 模拟器或真实局域网联调下，可以使用 localhost/您的 Mac 局域网 IP
  // 如果是 Android 模拟器，Android 内部路由 localhost 对应 10.0.2.2 端口
  // 默认使用部署在 Render 的后端地址，以便他人使用和本地直接联调
  static String baseUrl = 'https://dumpit-r0zv.onrender.com';

  /// 更改全局后端地址以适应真机局域网联调
  static void setBaseUrl(String customIp) {
    if (!customIp.startsWith('http://') && !customIp.startsWith('https://')) {
      baseUrl = 'http://$customIp:8080';
    } else {
      baseUrl = customIp;
    }
  }

  /// 上传音频并获取 AI 语气克隆与多维度梳理结果
  static Future<Map<String, dynamic>> uploadAudio({
    required File audioFile,
    required String toneSample,
    required String customPrompt,
  }) async {
    final uri = Uri.parse('$baseUrl/api/process-audio');
    final request = http.MultipartRequest('POST', uri);

    // 附带音频文件
    final stream = http.ByteStream(audioFile.openRead());
    final length = await audioFile.length();
    final multipartFile = http.MultipartFile(
      'audio',
      stream,
      length,
      filename: audioFile.path.split('/').last,
    );
    request.files.add(multipartFile);

    // 附带语气克隆参考和额外提示指令
    request.fields['user_tone_sample'] = toneSample;
    request.fields['custom_prompt'] = customPrompt;

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded as Map<String, dynamic>;
      } else {
        String errorMsg = '服务器处理异常';
        try {
          final errBody = json.decode(response.body);
          if (errBody['error'] != null) {
            errorMsg = errBody['error'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('网络连接失败，请确认 Go 后端已开启且设备在同一网络: $e');
    }
  }

  /// 向后端发起 JSON POST 请求，成功时返回解析后的响应体，失败时抛出带错误信息的异常
  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    required String defaultErrorMsg,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? defaultErrorMsg);
  }

  /// 将脑力整理卡片的内容一键推送到用户的 Notion
  static Future<bool> syncToNotion({
    required String notionToken,
    required String parentPageId,
    required String summary,
    required List<String> actionItems,
    required List<String> keyInsights,
    required List<dynamic> calendarEvents,
  }) async {
    await _postJson(
      '/api/notion/sync',
      {
        'notion_token': notionToken,
        'parent_page_id': parentPageId,
        'summary': summary,
        'action_items': actionItems,
        'key_insights': keyInsights,
        'calendar_events': calendarEvents.map((e) => {
          'title': e.title,
          'time': e.time,
        }).toList(),
      },
      defaultErrorMsg: 'Notion同步失败',
    );
    return true;
  }

  /// 🔒 向 Go 后端发起 Apple IAP 支付票据（收据）校验；订阅与账号绑定，需登录态
  static Future<bool> verifyReceipt(String receiptData, {required String sessionToken}) async {
    final decoded = await _postJsonAuthed(
      '/api/iap/verify',
      {'receipt_data': receiptData},
      sessionToken: sessionToken,
      defaultErrorMsg: '购买凭证校验失败',
    );
    return decoded['success'] == true;
  }

  /// 用 Firebase ID Token 向后端换取 session token（首次登录自动建号）
  static Future<Map<String, dynamic>> verifyFirebaseIdToken(String idToken) async {
    return _postJson(
      '/api/auth/verify',
      {'id_token': idToken},
      defaultErrorMsg: '登录验证失败',
    );
  }

  /// 附带登录态的 JSON POST 请求
  static Future<Map<String, dynamic>> _postJsonAuthed(
    String path,
    Map<String, dynamic> body, {
    required String sessionToken,
    required String defaultErrorMsg,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? defaultErrorMsg);
  }

  /// 附带登录态的 JSON GET 请求
  static Future<Map<String, dynamic>> _getJsonAuthed(
    String path, {
    required String sessionToken,
    required String defaultErrorMsg,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $sessionToken'},
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? defaultErrorMsg);
  }

  /// 首次登录批量导入本地历史记录
  static Future<Map<String, dynamic>> importHistory(
    String sessionToken,
    List<Map<String, dynamic>> records,
  ) async {
    return _postJsonAuthed(
      '/api/history/import',
      {'records': records},
      sessionToken: sessionToken,
      defaultErrorMsg: '历史记录导入失败',
    );
  }

  /// 新建一条云端历史记录
  static Future<Map<String, dynamic>> createHistory(
    String sessionToken,
    Map<String, dynamic> summary,
    String rawText,
  ) async {
    return _postJsonAuthed(
      '/api/history',
      {'summary': summary, 'raw_text': rawText},
      sessionToken: sessionToken,
      defaultErrorMsg: '云端保存失败',
    );
  }

  /// 拉取云端历史记录（全部，不做增量，重装/换设备场景足够用）
  static Future<Map<String, dynamic>> listHistory(String sessionToken) async {
    return _getJsonAuthed(
      '/api/history',
      sessionToken: sessionToken,
      defaultErrorMsg: '拉取历史记录失败',
    );
  }

  /// 拉取当前账号的订阅状态，用于重装/换设备登录后恢复会员权限
  static Future<Map<String, dynamic>> getSubscription(String sessionToken) async {
    return _getJsonAuthed(
      '/api/subscription',
      sessionToken: sessionToken,
      defaultErrorMsg: '拉取订阅状态失败',
    );
  }
}
