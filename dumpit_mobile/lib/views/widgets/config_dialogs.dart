import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/iap_service.dart';

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

  /// 👑 弹出 Apple IAP 内购收银台对话框
  static void showIapPaywall({
    required BuildContext context,
    required bool isZh,
    required VoidCallback onActivated,
    required Function(String) showSnackBar,
  }) {
    // 绑定内购状态事件监听
    IapService.instance.initialize(
      onSuccess: () {
        Navigator.of(context).pop(); // 关闭收银台
        onActivated();
      },
      onError: (err) {
        showSnackBar('⚠️ $err');
      },
      onStatus: (status) {
        showSnackBar(status);
      },
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Text(
                '👑 ',
                style: TextStyle(fontSize: 20),
              ),
              Text(
                isZh ? '黄金 Premium 会员' : 'Premium Gold Membership',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh
                    ? '订阅黄金会员，即可解锁以下尊享特权：'
                    : 'Subscribe to Premium to unlock all features:',
                style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildFeatureRow(
                icon: '♾️',
                title: isZh ? '无限次 AI 智能整理' : 'Unlimited AI Restructurings',
                desc: isZh ? '突破免费次数限制，随心整理录音。' : 'No daily limits for recording analysis.',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                icon: '☁️',
                title: isZh ? '一键同步至 Notion' : 'One-Tap Sync to Notion',
                desc: isZh ? '将整理好的待办和结构化文稿自动云同步。' : 'Sync tasks and drafts straight to Notion.',
              ),
              const SizedBox(height: 12),
              _buildFeatureRow(
                icon: '🚀',
                title: isZh ? '抢先体验未来高级特权' : 'Priority Access to Updates',
                desc: isZh ? '新功能开发完成立即向您推送开放。' : 'Get access to new tools as they release.',
              ),
            ],
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () {
                    IapService.instance.buyProduct(IapService.premiumMonthlyId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isZh ? '订阅 Premium 月会员 (￥30.00/月)' : 'Subscribe Premium (\$4.99/mo)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    IapService.instance.buyProduct(IapService.premiumLifetimeId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E3F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.amber, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isZh ? '终身买断 Lifetime Vault (￥398.00)' : 'Lifetime Vault (\$59.99)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        IapService.instance.restorePurchases();
                      },
                      child: Text(
                        isZh ? '🔄 恢复购买' : '🔄 Restore Purchases',
                        style: const TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isZh ? '暂不需要' : 'Cancel',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static Widget _buildFeatureRow({
    required String icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
