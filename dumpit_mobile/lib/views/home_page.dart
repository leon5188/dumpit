import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/history_record.dart';
import '../../services/api_service.dart';
import '../../services/device_sync_service.dart';
import '../translations.dart';
import 'widgets/restructured_details_sheet.dart';
import 'widgets/config_dialogs.dart';

class ToolLink {
  final String text;
  final String? actionId;
  final String? url;

  const ToolLink({
    required this.text,
    this.actionId,
    this.url,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // 双语与侧边分类
  bool _isZh = true;
  String _sidebarFolder = 'inbox'; // 'inbox', 'archive', 'trash'

  // 录音状态
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;
  String? _localAudioPath;
  double _currentAmplitude = 0.0;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  // 状态与指令
  String _status = 'idle'; // 'idle', 'recording', 'uploading', 'done', 'error'
  String _errorMsg = '';
  final TextEditingController _toneController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _notionTokenController = TextEditingController();
  final TextEditingController _notionPageController = TextEditingController();
  final TextEditingController _licenseKeyController = TextEditingController();
  bool _showConfig = false;
  bool _showGuide = true;
  bool _isPremium = false;

  // 核心提取结果 (用于当前活跃查看)
  String _summary = '';
  List<String> _actionItems = [];
  List<String> _keyInsights = [];
  List<CalendarEvent> _calendarEvents = [];

  // 历史数据库
  List<HistoryRecord> _historyList = [];
  String? _activeRecordId;

  // 滚动与 Tab 切换
  final ScrollController _scrollController = ScrollController();

  // 💡 体验示例数据 (与之前保持一致)
  final Map<String, Map<String, dynamic>> _demoData = {
    'zh': {
      'summary': '哎呀，今天真是乱成一团，理一下接下来要做的事。首先是今晚的家庭聚餐，定在晚上7:00，得提前半小时去超市买点西红柿和新鮮牛肉，不能迟到。然后是下周一早上9:30有个特别重要的项目周会，PPT大纲我已经有了，但数据图表还得更新下，这周末得抽两小时做完。另外，今天突然想到的那个“智能猫砂盆”的跨界创意真的很棒，可以给猫咪做健康监测，这个点点子得赶紧记下来，以后做可行性调研！最后，今天有三条多余的垃圾推销短信，直接删了，免得看着心烦。',
      'action_items': [
        '今晚6:30去超市购买西红柿与新鲜牛肉',
        '这周末抽2小时更新下周一项目周会的PPT数据图表',
        '对“智能猫砂盆健康监测”创意进行初步可行性调研',
        '清理手机里的推销短信和无用垃圾垃圾邮件',
      ],
      'key_insights': [
        '智能猫砂盆如果集成尿液PH值检测，可以成为宠物健康预警的黄金入口。',
        '将大任务（如项目周报）拆解为“更新图表”这一步，能极大缓解周日的ADHD拖延焦虑。',
      ],
      'calendar_events': [
        CalendarEvent(title: '🛒 超市采购食材', time: '今天 18:30'),
        CalendarEvent(title: '🏠 家庭温馨聚餐', time: '今天 19:00'),
        CalendarEvent(title: '📊 核心项目周会', time: '下周一 09:30'),
      ],
    },
    'en': {
      'summary': "Gosh, today is a total mess. Let me declutter my brain. First, we have a family dinner tonight at 7:00 PM. I need to run to the grocery store at 6:30 PM to buy some tomatoes and fresh beef. Second, there is a crucial weekly project meeting next Monday at 9:30 AM. I have the outline ready, but I need to spend 2 hours this weekend updating the data charts. Also, I got this amazing idea today: a smart cat litter box that tracks feline health! I must write this down for future feasibility research. Lastly, those 3 spam texts I got today are driving me crazy, just delete them and keep things clean.",
      'action_items': [
        'Go to the grocery store at 6:30 PM to buy tomatoes & beef',
        'Spend 2 hours this weekend updating data charts for Monday meeting',
        'Conduct initial feasibility study on the smart cat litter box concept',
        'Delete spam messages and clear inbox junk',
      ],
      'key_insights': [
        'A smart cat litter box with pH-level urine tracking could act as an early warning health system.',
        'Breaking the weekly report down to "updating charts" avoids procrastination friction.',
      ],
      'calendar_events': [
        CalendarEvent(title: '🛒 Buy Ingredients at Store', time: 'Today 18:30'),
        CalendarEvent(title: '🏠 Family Dinner', time: 'Today 19:00'),
        CalendarEvent(title: '📊 Weekly Project Meeting', time: 'Monday 09:30'),
      ],
    }
  };

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final url = await DeviceSyncService.getLaunchUrl();
      if (url != null) {
        _handleLaunchUrl(url);
      }
    });
  }

  // 处理外部 Scheme 唤醒
  void _handleLaunchUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'brainvent') {
        if (uri.host == 'record' || uri.queryParameters['action'] == 'start') {
          if (!_isRecording) {
            _startRecording();
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _amplitudeSubscription?.cancel();
    _timer?.cancel();
    _scrollController.dispose();
    _toneController.dispose();
    _promptController.dispose();
    _ipController.dispose();
    _notionTokenController.dispose();
    _notionPageController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  // 载入本地配置
  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isZh = prefs.getBool('dumpit_lang_zh') ?? true;
      _toneController.text = prefs.getString('dumpit_tone_sample') ?? '';
      _notionTokenController.text = prefs.getString('dumpit_notion_token') ?? '';
      _notionPageController.text = prefs.getString('dumpit_notion_page_id') ?? '';
      _isPremium = prefs.getBool('dumpit_is_premium') ?? false;
      _licenseKeyController.text = prefs.getString('dumpit_license_key') ?? '';
      
      final historyRaw = prefs.getString('dumpit_history_list');
      if (historyRaw != null) {
        try {
          final List decoded = json.decode(historyRaw);
          _historyList = decoded.map((e) => HistoryRecord.fromJson(e)).toList();
        } catch (_) {}
      }
    });
  }

  // 存储本地历史
  Future<void> _saveHistoryToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(_historyList.map((e) => e.toJson()).toList());
    await prefs.setString('dumpit_history_list', raw);
  }

  Future<void> _saveToneSample(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dumpit_tone_sample', val);
  }

  Future<void> _saveNotionToken(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dumpit_notion_token', val);
  }

  Future<void> _saveNotionPageId(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dumpit_notion_page_id', val);
  }

  // ⚡ 向 Go 后端发起同步到 Notion 的请求
  Future<void> _syncActiveRecordToNotion() async {
    if (!_isPremium) {
      _showSnackBar(_isZh 
          ? '🔒 提示: 一键同步到 Notion 是黄金会员专属特权！请打开侧边栏激活您的授权码。' 
          : '🔒 Notice: Notion 1-Click Sync is a Premium feature! Please activate your license in the sidebar.');
      return;
    }

    final token = _notionTokenController.text.trim();
    final pageId = _notionPageController.text.trim();

    if (token.isEmpty || pageId.isEmpty) {
      _showSnackBar(_isZh ? '⚠️ 请先在偏好设置中配置 Notion Token 与 Page ID' : '⚠️ Please configure Notion Token & Page ID first');
      return;
    }

    _showSnackBar(_isZh ? '正在同步到 Notion...' : 'Syncing to Notion...');

    try {
      final success = await ApiService.syncToNotion(
        notionToken: token,
        parentPageId: pageId,
        summary: _summary,
        actionItems: _actionItems,
        keyInsights: _keyInsights,
        calendarEvents: _calendarEvents,
      );

      if (success) {
        _showSnackBar(_isZh ? '🎉 同步成功！已在 Notion 中创建页面' : '🎉 Synced to Notion successfully!');
      } else {
        _showSnackBar(_isZh ? '⚠️ 同步失败，请检查配置或网络' : '⚠️ Sync failed, check settings');
      }
    } catch (e) {
      _showSnackBar('⚠️ Notion同步出错: $e');
    }
  }

  void _toggleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isZh = !_isZh;
      prefs.setBool('dumpit_lang_zh', _isZh);
    });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 1. 加载并直接弹窗/BottomSheet展示体验数据
  void _loadDemoData() {
    final langKey = _isZh ? 'zh' : 'en';
    final demo = _demoData[langKey]!;
    
    setState(() {
      _summary = demo['summary'];
      _actionItems = List<String>.from(demo['action_items']);
      _keyInsights = List<String>.from(demo['key_insights']);
      _calendarEvents = List<CalendarEvent>.from(demo['calendar_events']);
      _activeRecordId = 'demo-id';
    });

    _showSnackBar(_isZh ? '体验数据已加载' : 'Demo data loaded');
    _showRestructuredDetailsSheet();
  }

  // 2. 载入某条历史并弹窗展示四大 Tab
  void _loadHistoryRecord(HistoryRecord record) {
    setState(() {
      _summary = record.summary;
      _actionItems = record.actionItems;
      _keyInsights = record.keyInsights;
      _calendarEvents = record.calendarEvents;
      _activeRecordId = record.id;
      _status = 'done';
      _errorMsg = '';
    });
    Navigator.pop(context); // 收起 Drawer
    _showRestructuredDetailsSheet();
  }

  // 3. 弹出霓虹暗黑 TabView 详情 BottomSheet (手机核心体验)
  void _showRestructuredDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151622),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return RestructuredDetailsSheet(
          isZh: _isZh,
          summary: _summary,
          actionItems: _actionItems,
          keyInsights: _keyInsights,
          calendarEvents: _calendarEvents,
          onArchive: () {
            Navigator.pop(context);
            _archiveActiveRecord();
          },
          onDestroy: () {
            Navigator.pop(context);
            _destroyActiveRecord();
          },
          onSyncNotion: _syncActiveRecordToNotion,
          onTodosChanged: (updated) {
            setState(() {
              _actionItems = updated;
            });
            if (_activeRecordId != null && _activeRecordId != 'demo-id') {
              _historyList = _historyList.map((r) => r.id == _activeRecordId ? r.copyWith(actionItems: updated) : r).toList();
              _saveHistoryToLocal();
            }
          },
        );
      },
    );
  }

  // 归档卡片 (移入 Vault)
  void _archiveActiveRecord() async {
    if (_activeRecordId == null || _activeRecordId == 'demo-id') return;
    setState(() {
      _historyList = _historyList.map((r) {
        if (r.id == _activeRecordId) {
          return r.copyWith(folder: 'archive');
        }
        return r;
      }).toList();
      _clearActiveView();
    });
    await _saveHistoryToLocal();
    _showSnackBar(_isZh ? '已成功移入保险箱！' : 'Archived to Vault!');
  }

  // 移入回收站/永久删除
  void _destroyActiveRecord() async {
    if (_activeRecordId == null || _activeRecordId == 'demo-id') return;
    setState(() {
      if (_sidebarFolder == 'trash') {
        _historyList.removeWhere((r) => r.id == _activeRecordId);
        _showSnackBar(_isZh ? '记录已永久粉碎！' : 'Permanently destroyed!');
      } else {
        _historyList = _historyList.map((r) {
          if (r.id == _activeRecordId) {
            return r.copyWith(folder: 'trash');
          }
          return r;
        }).toList();
        _showSnackBar(_isZh ? '记录已移入回收站！' : 'Sent to Trash!');
      }
      _clearActiveView();
    });
    await _saveHistoryToLocal();
  }

  void _clearActiveView() {
    _summary = '';
    _actionItems = [];
    _keyInsights = [];
    _calendarEvents = [];
    _activeRecordId = null;
    _status = 'idle';
  }

  // 录音模块
  void _startTimer() {
    _recordingDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/dump_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _status = 'recording';
          _localAudioPath = path;
          _errorMsg = '';
        });
        _startTimer();
        _amplitudeSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
          setState(() {
            double normalized = (amp.current + 50.0) / 50.0;
            _currentAmplitude = normalized.clamp(0.0, 1.0);
          });
        });
      } else {
        setState(() {
          _status = 'error';
          _errorMsg = _isZh ? '麦克风授权失败' : 'Microphone permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'error';
        _errorMsg = '录音启动失败: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    _stopTimer();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _currentAmplitude = 0.0;
    });

    if (path != null && _localAudioPath != null) {
      final file = File(_localAudioPath!);
      if (await file.exists()) {
        await _uploadAndProcessAudio(file);
      }
    }
  }

  Future<void> _uploadAndProcessAudio(File file) async {
    setState(() {
      _status = 'uploading';
    });

    // 弹出一个正在转译处理的 BottomSheet
    _showUploadingSheet();

    try {
      final result = await ApiService.uploadAudio(
        audioFile: file,
        toneSample: _toneController.text,
        customPrompt: _promptController.text,
      );

      final List rawActions = result['action_items'] ?? [];
      final List rawInsights = result['key_insights'] ?? [];
      final List rawEvents = result['calendar_events'] ?? [];

      final summary = result['summary'] ?? '';
      final actions = rawActions.map((e) => e.toString()).toList();
      final insights = rawInsights.map((e) => e.toString()).toList();
      final events = rawEvents.map((e) => CalendarEvent.fromJson(e)).toList();

      // 先关闭 Loading Sheet
      Navigator.pop(context);

      setState(() {
        _summary = summary;
        _actionItems = actions;
        _keyInsights = insights;
        _calendarEvents = events;
        _status = 'done';

        final newRecord = HistoryRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          timestamp: DateTime.now().toLocal().toString().substring(0, 16),
          rawText: '',
          summary: summary,
          actionItems: actions,
          keyInsights: insights,
          calendarEvents: events,
          status: 'done',
          folder: 'inbox',
        );

        _historyList.insert(0, newRecord);
        _activeRecordId = newRecord.id;
      });

      await _saveHistoryToLocal();
      _showSnackBar(_isZh ? '脑力倾倒整理成功！' : 'Restructured successfully!');
      
      // 直接弹出结果详情页
      _showRestructuredDetailsSheet();
    } catch (e) {
      // 关闭 Loading Sheet
      Navigator.pop(context);
      setState(() {
        _status = 'error';
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar('⚠️ $_errorMsg');
    } finally {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  // 弹窗转译中 Loading
  void _showUploadingSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.purpleAccent),
              const SizedBox(height: 24),
              Text(
                _isZh ? 'AI 正在克隆您的语气并精细整理中...' : 'AI Restructuring, please wait...',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Whisper 转译 & 语气克隆正高速运行中',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              )
            ],
          ),
        );
      },
    );
  }

  // 弹出录音 BottomSheet (手机一键倾倒)
  void _showRecordingSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: !_isRecording,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // 发光呼吸环
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.purpleAccent, Colors.pinkAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 36),
                      onPressed: () async {
                        if (_isRecording) {
                          await _stopRecording();
                          Navigator.pop(context); // 录音完成关闭
                        } else {
                          await _startRecording();
                          setSheetState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? _formatDuration(_recordingDuration) : '00:00',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? (_isZh ? '倾倒中，再次点击按钮完成整理...' : 'Dumping... tap to stop.')
                        : (_isZh ? '点击上方麦克风开始录音' : 'Tap mic to start'),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 指南快捷响应
  void _executeGuideAction(String actionId) {
    if (actionId == 'focus-recorder') {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      _showRecordingSheet();
    } else {
      if (_summary.isEmpty) {
        _loadDemoData();
      } else {
        _showRestructuredDetailsSheet();
      }
    }
  }

  // 配置局域网 IP
  void _showIpConfig() {
    ConfigDialogs.showIpDialog(
      context: context,
      isZh: _isZh,
      ipController: _ipController,
      onSaved: (ip) {
        _showSnackBar(_isZh ? '后端连接已重定向' : 'API Redirected');
      },
    );
  }

  // 🕒 格式化计时器
  String _formatDuration(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // 📂 侧边栏抽屉分类文件夹按钮
  Widget _buildFolderBtn(String folder, String label) {
    final active = _sidebarFolder == folder;
    return GestureDetector(
      onTap: () {
        setState(() {
          _sidebarFolder = folder;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.purpleAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.purpleAccent : Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.purpleAccent : Colors.grey,
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translations = _isZh ? HomeTranslations.zh : HomeTranslations.en;
    final filteredHistory = _historyList.where((r) => r.folder == _sidebarFolder).toList();
    final recentDumps = _historyList.take(3).toList(); // 主页取最近 3 条记录

    return Scaffold(
      backgroundColor: const Color(0xFF09090F), // 极致深紫黑背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'BrainVent.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            if (_isPremium) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 0.8),
                ),
                child: const Text(
                  '👑',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: Colors.grey),
            onPressed: _showIpConfig,
          ),
          TextButton(
            onPressed: _toggleLanguage,
            child: Text(
              _isZh ? 'EN' : '中文',
              style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),

      // 🍔 侧边历史归档抽屉
      drawer: Drawer(
        backgroundColor: const Color(0xFF15161E),
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.transparent),
              child: Center(
                child: Text(
                  '🧠 Brain Vault',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(child: _buildFolderBtn('inbox', '📥 Inbox')),
                  const SizedBox(width: 4),
                  Expanded(child: _buildFolderBtn('archive', '📂 Vault')),
                  const SizedBox(width: 4),
                  Expanded(child: _buildFolderBtn('trash', '🗑️ Trash')),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(
                      child: Text(
                        _isZh ? '暂无记录' : 'No records',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final record = filteredHistory[index];
                        return ListTile(
                          title: Text(
                            record.timestamp,
                            style: const TextStyle(color: Colors.purpleAccent, fontSize: 11),
                          ),
                          subtitle: Text(
                            record.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          onTap: () => _loadHistoryRecord(record),
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1B1C26),
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(); // 先关闭侧边栏
                    ConfigDialogs.showLicenseDialog(
                      context: context,
                      isZh: _isZh,
                      licenseKeyController: _licenseKeyController,
                      onActivated: (key) {
                        setState(() {
                          _isPremium = true;
                        });
                      },
                      showSnackBar: _showSnackBar,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: _isPremium
                          ? const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)])
                          : null,
                      color: _isPremium ? null : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isPremium ? Colors.transparent : Colors.white10,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isPremium ? '👑' : '🔑',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPremium 
                              ? (_isZh ? 'Premium 黄金会员' : 'Premium Active') 
                              : (_isZh ? '激活 Premium 会员' : 'Activate Premium'),
                          style: TextStyle(
                            color: _isPremium ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 顶栏 Welcome
              Text(
                _isZh ? 'Welcome Back!' : 'Welcome Back!',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _isZh ? 'Hello, Restructurer 👋' : 'Hello, Restructurer 👋',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // 2. 大脑活跃卡片 (Total Balance 替换，绘制正弦脑波图)
              _buildBrainWaveCard(),
              const SizedBox(height: 20),

              // 2.5 🎤 语音录音倾倒中心大卡片
              _buildRecorderCard(),
              const SizedBox(height: 20),

              // 3. 配置折叠展开
              _buildConfigDrawer(),
              const SizedBox(height: 16),

              // 4. 最近活动列表 (Recent Activities)
              _buildRecentDumpsSection(recentDumps),
              const SizedBox(height: 28),

              // 5. 💡 大脑整理心流指南 (Mind Flow Guide)
              _buildGuideSection(translations),
              
              // 底部垫高，防止 FAB 遮挡
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // 大脑活跃趋势卡片 (内置正弦贝塞尔曲线 Canvas 绘制)
  Widget _buildBrainWaveCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 背景正弦波绘制
          Positioned.fill(
            child: CustomPaint(
              painter: _BrainWavePainter(),
            ),
          ),
          // 卡片层上层文字与动作
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🧠 Mind Clutter Index',
                  style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      '24.50%',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'RESTORED',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const Spacer(),
                // 霓虹快捷操作图标组
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNeonActionButton(Icons.auto_awesome, _isZh ? '示例' : 'Demo', _loadDemoData),
                    _buildNeonActionButton(Icons.bubble_chart, _isZh ? '网状图' : 'Web', () {
                      if (_summary.isEmpty) {
                        _loadDemoData();
                      } else {
                        _showRestructuredDetailsSheet();
                      }
                    }),
                    _buildNeonActionButton(Icons.archive, _isZh ? '箱库' : 'Vault', () {
                      Scaffold.of(context).openDrawer();
                    }),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNeonActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.purpleAccent, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  // 🎤 主屏语音倾倒大卡片 (恢复为原地直接控制，去除了 BottomSheet 遮挡)
  Widget _buildRecorderCard() {
    final activeColor = _isRecording ? Colors.pinkAccent : Colors.purpleAccent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: activeColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isZh ? '🎤 语音想法倾倒中心' : '🎤 Voice Dump Hub',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isZh ? '正在录音' : 'RECORDING',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                )
              else
                const Text(
                  'READY',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                )
            ],
          ),
          const SizedBox(height: 20),
          // 麦克风发光呼吸环
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100), // 缩短响应时长为 100ms 以紧密贴合音量
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [Colors.pinkAccent, Colors.redAccent]
                      : [Colors.purpleAccent, Colors.pinkAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: _isRecording ? (25.0 + _currentAmplitude * 20.0) : 12.0,
                    spreadRadius: _isRecording ? (6.0 + _currentAmplitude * 8.0) : 2.0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? _formatDuration(_recordingDuration) : '00:00',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording
                ? (_isZh ? '点击按钮完成录音并开始智能整理' : 'Tap to stop & trigger AI rewrite')
                : (_isZh ? '一键倾倒您的头脑灵感、琐碎情绪、待办计划' : 'Jot down thoughts, tasks & emotions in one click'),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 配置展开组件
  Widget _buildConfigDrawer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showConfig = !_showConfig),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showConfig ? (_isZh ? '收起偏好与文风' : 'Hide Config') : (_isZh ? '展开偏好与文风设置' : 'Show Config'),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Icon(
                  _showConfig ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 16,
                )
              ],
            ),
          ),
        ),
        if (_showConfig) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _toneController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: _isZh ? '贴入您平时手写的段落，AI克隆文风...' : 'Paste your text sample to clone your tone...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _saveToneSample,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: _isZh ? '本次处理的额外指令（选填）...' : 'Extra prompt for this dump (optional)...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notionTokenController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: _isZh ? '输入 Notion Integration Token (secret_...)' : 'Notion Integration Token...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _saveNotionToken,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notionPageController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: _isZh ? '输入 Notion 目标父 Page ID' : 'Notion Parent Page ID...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _saveNotionPageId,
          ),
        ]
      ],
    );
  }

  // 最近活动列表 UI
  Widget _buildRecentDumpsSection(List<HistoryRecord> recentDumps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isZh ? '最近倾倒 (Recent Activities)' : 'Recent Activities',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Text(
                _isZh ? '查看全部' : 'See All',
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (recentDumps.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: Text(
              _isZh ? '暂无数据，点击底部 + 开始倾倒' : 'No activity. Tap + to start.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        else
          ...recentDumps.map((record) {
            final isInbox = record.folder == 'inbox';
            final isArchive = record.folder == 'archive';
            
            // 指示灯颜色
            final badgeColor = isInbox 
                ? Colors.blueAccent 
                : (isArchive ? Colors.purpleAccent : Colors.redAccent);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2F).withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor.withOpacity(0.12),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Icon(
                    isInbox ? Icons.inbox : (isArchive ? Icons.lock_outline : Icons.delete_outline),
                    color: badgeColor,
                    size: 18,
                  ),
                ),
                title: Text(
                  record.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    record.timestamp,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${record.actionItems.length} Tasks',
                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () => _loadHistoryRecord(record),
              ),
            );
          }).toList(),
      ],
    );
  }

  // 大脑整理指南
  Widget _buildGuideSection(Map<String, dynamic> trans) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showGuide = !_showGuide),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trans['guideHeader'],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Icon(
                  _showGuide ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          if (_showGuide) ...[
            const SizedBox(height: 16),
            _buildGuideCard(trans['guide1Title'], trans['guide1Desc'], trans['guide1Tools'] as List<ToolLink>),
            _buildGuideCard(trans['guide2Title'], trans['guide2Desc'], trans['guide2Tools'] as List<ToolLink>),
            _buildGuideCard(trans['guide3Title'], trans['guide3Desc'], trans['guide3Tools'] as List<ToolLink>),
            _buildGuideCard(trans['guide4Title'], trans['guide4Desc'], trans['guide4Tools'] as List<ToolLink>),
            _buildGuideCard(trans['guide5Title'], trans['guide5Desc'], trans['guide5Tools'] as List<ToolLink>),
          ]
        ],
      ),
    );
  }

  Widget _buildGuideCard(String title, String desc, List<ToolLink> tools) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('可用工具：', style: TextStyle(fontSize: 10, color: Colors.white24)),
              const SizedBox(width: 4),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tools.map((tool) {
                    return GestureDetector(
                      onTap: () {
                        if (tool.actionId != null) {
                          _executeGuideAction(tool.actionId!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.1),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tool.text,
                          style: const TextStyle(fontSize: 11, color: Colors.purpleAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🧠 动态手绘渐变脑电波/波动 Painter (Total Balance 霓虹氛围还原)
class _BrainWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final paintLineCore = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.4);

    // 三次贝塞尔曲线模拟一段平滑高品质脑波
    path.cubicTo(
      size.width * 0.25, size.height * 0.2, 
      size.width * 0.35, size.height * 0.8, 
      size.width * 0.6, size.height * 0.5
    );
    path.cubicTo(
      size.width * 0.75, size.height * 0.3, 
      size.width * 0.85, size.height * 0.7, 
      size.width, size.height * 0.45
    );

    // 绘制发光阴影与核心白粉线
    canvas.drawPath(path, paintLine);
    canvas.drawPath(path, paintLineCore);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


