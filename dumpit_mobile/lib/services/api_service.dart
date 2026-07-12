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

  /// 将脑力整理卡片的内容一键推送到用户的 Notion
  static Future<bool> syncToNotion({
    required String notionToken,
    required String parentPageId,
    required String summary,
    required List<String> actionItems,
    required List<String> keyInsights,
    required List<dynamic> calendarEvents,
  }) async {
    final uri = Uri.parse('$baseUrl/api/notion/sync');
    
    final body = json.encode({
      'notion_token': notionToken,
      'parent_page_id': parentPageId,
      'summary': summary,
      'action_items': actionItems,
      'key_insights': keyInsights,
      'calendar_events': calendarEvents.map((e) => {
        'title': e.title,
        'time': e.time,
      }).toList(),
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return true;
      } else {
        String errorMsg = 'Notion同步失败';
        try {
          final errBody = json.decode(utf8.decode(response.bodyBytes));
          if (errBody['error'] != null) {
            errorMsg = errBody['error'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }
  }

  /// 🔒 向 Go 后端发起 Lemon Squeezy 激活码校验
  static Future<bool> verifyLicense(String licenseKey) async {
    final uri = Uri.parse('$baseUrl/api/license/verify');
    final body = json.encode({
      'license_key': licenseKey,
      'instance_name': 'DumpIt Mobile App Client',
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['success'] == true) {
          return true;
        }
        return false;
      } else {
        String errorMsg = '激活码校验失败';
        try {
          final errBody = json.decode(utf8.decode(response.bodyBytes));
          if (errBody['error'] != null) {
            errorMsg = errBody['error'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('网络连接失败: $e');
    }
  }
}
