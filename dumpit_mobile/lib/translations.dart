import 'views/home_page.dart';

// 国际化静态资源
class HomeTranslations {
  static const Map<String, dynamic> zh = {
    'guideHeader': '💡 大脑整理心流指南 (Mind Flow Guide)',
    'guide1Title': '1. 无过滤记录',
    'guide1Desc': '快速说出或写下所有点子、待办或情绪。不要管对错和顺序。就像打开水龙头，让水流出来。',
    'guide1Tools': [
      ToolLink(text: '🎤 触发原生录音', actionId: 'focus-recorder'),
    ],
    'guide2Title': '2. 思维解构',
    'guide2Desc': '把大问题拆成小碎块。比如，把“写报告”拆成“查资料”、“写大纲”、“填内容”三步。这能降低大脑的压力。',
    'guide2Tools': [
      ToolLink(text: '📋 切换至原生待办', actionId: 'focus-todo'),
    ],
    'guide3Title': '3. 可戏化关联',
    'guide3Desc': '无需下载第三方绘图软件，AI会根据你的灵感与任务，自动绘制一个可交互拖拽的发光网状想法图，看清思维链路。',
    'guide3Tools': [
      ToolLink(text: '🕸️ 查看连线网状图', actionId: 'focus-web'),
    ],
    'guide4Title': '4. 分类与清洗',
    'guide4Desc': '一键理清你的心流。有用的灵感一键归档归仓，无用的多余杂音直接粉碎粉末，告别信息堆积焦虑。',
    'guide4Tools': [
      ToolLink(text: '📂 一键归档保险箱', actionId: 'direct-archive'),
      ToolLink(text: '💥 回收站粉碎数据', actionId: 'direct-destroy'),
    ],
    'guide5Title': '5. 行动转化',
    'guide5Desc': '将想法变成具体的下一步时间点。例如，把“学做饭”变成“今晚去超市买西红柿和鸡蛋”，在时间轴上有序排列。',
    'guide5Tools': [
      ToolLink(text: '📅 查看原生时间轴', actionId: 'focus-calendar'),
    ],
  };

  static const Map<String, dynamic> en = {
    'guideHeader': '💡 Mind Flow Guide (ADHD Friendly)',
    'guide1Title': '1. Free Output',
    'guide1Desc': 'Jot down all ideas, tasks, or emotions. Ignore correctness and order. Like opening a tap to let water flow.',
    'guide1Tools': [
      ToolLink(text: '🎤 Start Native Mic', actionId: 'focus-recorder'),
    ],
    'guide2Title': '2. Deconstruct',
    'guide2Desc': 'Break big goals into micro-tasks. Turn "write report" into "research", "outline", and "draft" to reduce mental friction.',
    'guide2Tools': [
      ToolLink(text: '📋 Switch to Todo', actionId: 'focus-todo'),
    ],
    'guide3Title': '3. Visual Connection',
    'guide3Desc': 'No diagram software required. AI automatically maps your insights & tasks into an interactive dragging web diagram.',
    'guide3Tools': [
      ToolLink(text: '🕸️ View Mind Web', actionId: 'focus-web'),
    ],
    'guide4Title': '4. Sort & Clean',
    'guide4Desc': 'Clean up your thoughts in seconds. Archive valuable insights to Vault and shred useless noise to Trash.',
    'guide4Tools': [
      ToolLink(text: '📂 Archive to Vault', actionId: 'direct-archive'),
      ToolLink(text: '💥 Move to Trash', actionId: 'direct-destroy'),
    ],
    'guide5Title': '5. Action Translation',
    'guide5Desc': 'Translate vague thoughts into concrete timelines. See tasks automatically mapped onto a linear timeline.',
    'guide5Tools': [
      ToolLink(text: '📅 View Timeline', actionId: 'focus-calendar'),
    ],
  };
}
