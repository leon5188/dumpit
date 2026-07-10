import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ConfigDialogs {
  /// ⚙️ 弹出 IP 局域网配置对话框
  static void showIpDialog({
    required BuildContext context,
    required bool isZh,
    required TextEditingController ipController,
    required Function(String) onSaved,
  }) {
    ipController.text = ApiService.baseUrl.replaceFirst('http://', '').replaceFirst(':8080', '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          title: Text(
            isZh ? '⚙️ 配置局域网 Go 后端 IP' : '⚙️ Config Backend IP',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isZh ? '如果使用的是手机真机联调，请输入电脑的局域网 IP 以连接后端。' : 'Enter your PC local IP to sync from physical devices.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: 'e.g., 192.168.1.100',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final ip = ipController.text.trim();
                ApiService.setBaseUrl(ip);
                Navigator.pop(context);
                onSaved(ip);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// 🔑 弹出激活 License 对话框
  static void showLicenseDialog({
    required BuildContext context,
    required bool isZh,
    required TextEditingController licenseKeyController,
    required Function(String) onActivated,
    required Function(String) showSnackBar,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          title: Text(
            isZh ? '🔑 激活 BrainVent. 黄金会员' : '🔑 Activate BrainVent. Premium',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh 
                    ? '请输入您购买后获得的激活码，即可解锁无限次 AI 整理和 Notion 一键云同步特权。' 
                    : 'Enter your license key to unlock unlimited dumps & Notion sync.',
                style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: licenseKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'e.g., LSQ-...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.3),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                isZh ? '取消' : 'Cancel',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final key = licenseKeyController.text.trim();
                if (key.isEmpty) {
                  showSnackBar(isZh ? '⚠️ 激活码不能为空' : '⚠️ License key cannot be empty');
                  return;
                }

                showSnackBar(isZh ? '正在连接支付中心校验激活码...' : 'Verifying license key...');

                try {
                  final success = await ApiService.verifyLicense(key);
                  if (success) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('dumpit_is_premium', true);
                    await prefs.setString('dumpit_license_key', key);
                    
                    Navigator.of(context).pop(); // 关闭弹窗
                    onActivated(key);
                    showSnackBar(isZh ? '🎉 激活成功！欢迎成为 BrainVent. 黄金会员！' : '🎉 Activated successfully! Welcome to BrainVent. Premium!');
                  } else {
                    showSnackBar(isZh ? '⚠️ 激活码无效或已被核销' : '⚠️ Invalid or expired license key');
                  }
                } catch (e) {
                  showSnackBar(isZh ? '⚠️ 激活失败: ${e.toString().replaceAll('Exception: ', '')}' : '⚠️ Activation failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isZh ? '激活' : 'Activate',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
