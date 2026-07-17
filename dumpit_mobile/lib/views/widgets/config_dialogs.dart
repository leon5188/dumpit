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
                const Divider(color: Colors.white24, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _showTermsDialog(context, isZh),
                      child: Text(
                        isZh ? '使用条款 (EULA)' : 'Terms of Use (EULA)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text('  |  ', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    GestureDetector(
                      onTap: () => _showPrivacyDialog(context, isZh),
                      child: Text(
                        isZh ? '隐私政策' : 'Privacy Policy',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                        ),
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

  static void _showTermsDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            isZh ? '使用条款 (EULA)' : 'Terms of Use (EULA)',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                isZh
                    ? '欢迎使用 Dumpit！\n\n'
                        '1. 协议接受\n使用本软件即表示您同意本使用条款。若您不同意，请勿使用。\n\n'
                        '2. 许可范围\nDumpit 授予您一项个人、非独占、不可转让、有限的许可，允许您在 Apple 智能设备上运行本软件。\n\n'
                        '3. 订阅与付费\n本软件提供自动续订订阅服务。所有费用将通过您的 Apple ID 账户进行扣除。订阅会自动续订，除非您在当前订阅期结束前至少 24 小时关闭自动续订。\n\n'
                        '4. 适用标准 EULA\n除本协议另有规定外，本软件同时适用 Apple 的标准应用许可协议 (Standard EULA)。您可以通过以下链接查阅完整内容：https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\n\n'
                        '5. 免责声明\n本软件“按原样”提供，不提供任何明示或暗示的保证。对于因使用本软件而导致的任何数据丢失或间接损失，我们不承担任何责任。'
                    : 'Welcome to Dumpit!\n\n'
                        '1. Acceptance of Terms\nBy using this software, you agree to these Terms of Use. If you do not agree, please do not use it.\n\n'
                        '2. Scope of License\nDumpit grants you a personal, non-exclusive, non-transferable, limited license to run this software on Apple devices.\n\n'
                        '3. Subscriptions & Billing\nThis software offers auto-renewable subscriptions. Payment will be charged to your Apple ID account. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period.\n\n'
                        '4. Standard EULA Applies\nUnless otherwise specified, this application is governed by Apple\'s Standard Licensed Application End User License Agreement (EULA). You can review the details at: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\n\n'
                        '5. Disclaimer of Warranties\nThis software is provided "as is" without warranties of any kind. We are not liable for any data loss or indirect damages arising from using this software.',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isZh ? '确认' : 'Close', style: const TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }

  static void _showPrivacyDialog(BuildContext context, bool isZh) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            isZh ? '隐私政策' : 'Privacy Policy',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                isZh
                    ? '我们非常重视您的隐私：\n\n'
                        '1. 数据收集与处理\nDumpit 主要在本地保存和整理您的脑暴记录与录音。除非您主动开启云同步服务（如 Notion 同步），否则您的数据不会被传输到外部服务器。我们不会将您的个人隐私数据出售或共享给任何第三方。\n\n'
                        '2. 云同步与 API\n当您配置并开启 Notion 或其它云同步时，本 App 会调用相应平台的安全 API 传输选定的笔记。相关访问令牌（Token）将加密存储在您的设备本地。\n\n'
                        '3. 权限说明\n我们可能需要麦克风权限以支持语音录音功能。我们不会在未获得您允许的情况下访问您的麦克风或后台进行录音。\n\n'
                        '4. 政策变更\n隐私政策如有更新，我们会在应用内发布通知。'
                    : 'We value your privacy:\n\n'
                        '1. Data Collection & Processing\nDumpit primarily saves and restructures your brain dumps and voice recordings locally on your device. Unless you manually enable cloud synchronization services (such as Notion sync), your data will not be transmitted to external servers. We do not sell or share your personal data with third parties.\n\n'
                        '2. Cloud Sync & APIs\nWhen you configure and enable Notion or other cloud integrations, the App calls the respective platform APIs to transfer selected notes securely. Access tokens are encrypted and stored locally on your device.\n\n'
                        '3. Permissions\nWe require microphone access to support voice recording. We will never access your microphone or record in the background without your explicit permission.\n\n'
                        '4. Changes to Policy\nAny updates to our Privacy Policy will be notified within the App.',
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isZh ? '确认' : 'Close', style: const TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );
  }
}
