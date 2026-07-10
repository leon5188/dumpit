// 推荐工具链接结构
export interface ToolLink {
	text: string;
	url?: string;
	actionId?: string;
}

export interface CalendarEvent {
	title: string;
	time: string;
}

export const translations = {
	zh: {
		title: "把混乱想法交给我",
		subtitle: "点击录音，开启无压力的脑力倾倒。AI 会自动过滤赘词并克隆您的文风。",
		placeholderTone: "在此贴入您平时随手写的、带有自己强烈口头语或措辞风格的段落，AI 将克隆您的文风...",
		placeholderPrompt: "例如：请翻译成英文、主要关注里面的周报内容、用大纲形式呈现...",
		startRecord: "点击上方麦克风开始录音",
		recording: "倾倒中，再次点击按钮完成整理...",
		uploading: "AI 正在进行智能语气克隆与多维度整理，请稍候...",
		emptyAudio: "未检测到明显的语音内容，请重新录音。",
		historyTitle: "历史记录",
		noHistory: "暂无记录",
		configLabel: "展开偏好与文风设置（克隆语气）",
		configLabelActive: "收起偏好与文风设置",
		toneSampleLabel: "我的写作与表达风格参考样例（AI 会以此文风重构）：",
		promptLabel: "本次处理的额外指令/要求（选填）：",
		toastSuccess: "BrainVent 整理成功！",
		toastOffline: "当前处于离线状态，录音已安全保存在本地。",
		toastOfflineSync: "检测到网络已恢复，自动同步离线 BrainVent 记录...",
		toastSyncSuccess: "离线记录同步成功！",
		toastLoadSuccess: "历史记录加载成功",
		toastCopy: "整理文本已复制到剪贴板",
		toastExport: "成功导出为 Markdown 文件",
		toastDestroy: "记录已放入回收站！",
		toastDeleteForever: "记录已永久粉碎！",
		toastArchive: "记录已成功移入保险箱！",
		offlineBanner: "📶 当前处于离线状态 — 您的所有记录将安全保存在本地浏览器中。",
		offlineBadge: "离线模式",
		syncingSummary: "🔄 正在自动同步中...",
		syncFailed: "⚠️ 同步失败，等待下次尝试",
		offlinePendingSummary: "⏳ 离线保存：等待网络连接恢复后自动同步...",
		summaryTitle: "📝 语气重构整理",
		copyBtn: "复制内容",
		exportBtn: "📥 导出 Markdown",
		notionSyncBtn: "⚡ 同步到 Notion",
		archiveBtn: "📂 归档到保险箱",
		destroyBtn: "🗑️ 移入回收站",
		deleteForeverBtn: "💥 永久销毁",
		todoTitle: "✅ 原生待办事项管理器",
		noTodo: "双击这里或下方添加你的第一个具体行动...",
		todoPlaceholder: "输入具体行动，回车添加...",
		calendarTitle: "📅 原生时间轴行动日程",
		noCalendar: "未提取到日程，请录音倾倒包含时间的任务",
		insightTitle: "💡 闪光创意卡片",
		noInsight: "未识别到突出创意点",
		mindWebTitle: "🕸️ 原生脑力网状关联图",
		guideHeader: "💡 大脑整理心流指南 (Mind Flow Guide)",
		
		// 5大原生卡片指南
		guide1Title: "1. 无过滤记录",
		guide1Desc: "快速说出或写下所有点子、待办或情绪。不要管对错和顺序。就像打开水龙头，让水流出来。",
		guide1Label: "原生工具：",
		guide1Tools: [
			{ text: "🎤 点击聚焦麦克风", actionId: "focus-recorder" }
		] as ToolLink[],
		
		guide2Title: "2. 思维解构",
		guide2Desc: "把大问题拆成小碎块。比如，把“写报告”拆成“查资料”、“写大纲”、“填内容”三步。这能降低大脑的压力。",
		guide2Label: "原生工具：",
		guide2Tools: [
			{ text: "📋 使用内置待办面板", actionId: "focus-todo" }
		] as ToolLink[],
		
		guide3Title: "3. 可视化关联",
		guide3Desc: "无需下载外部绘图软件，AI会根据你的灵感与任务，自动绘制一个可交互拖拽的发光网状想法图，看清思维链路。",
		guide3Label: "原生工具：",
		guide3Tools: [
			{ text: "🕸️ 聚焦内置网状图", actionId: "focus-web" }
		] as ToolLink[],
		
		guide4Title: "4. 分类与清洗",
		guide4Desc: "一键理清你的心流。有用的灵感一键归档归仓，无用的多余杂音直接粉碎粉末，告别信息堆积焦虑。",
		guide4Label: "原生工具：",
		guide4Tools: [
			{ text: "📂 归档到本地保险箱", actionId: "direct-archive" },
			{ text: "💥 永久销毁垃圾信息", actionId: "direct-destroy" }
		] as ToolLink[],
		
		guide5Title: "5. 行动转化",
		guide5Desc: "将想法变成具体的下一步时间点。例如，把“学做饭”变成“今晚去超市买西红柿和鸡蛋”，在时间轴上有序排列。",
		guide5Label: "原生工具：",
		guide5Tools: [
			{ text: "📅 聚焦内置时间轴", actionId: "focus-calendar" }
		] as ToolLink[]
	},
	en: {
		title: "Dump Your Chaos",
		subtitle: "Click record to start stress-free brain dumping. AI will filter noise and clone your tone.",
		placeholderTone: "Paste your typical writing style sample here. AI will clone this style...",
		placeholderPrompt: "e.g., Translate to English, focus on weekly report items, output as a humorous outline...",
		startRecord: "Click the microphone above to start recording",
		recording: "Dumping in progress, click again to restructure...",
		uploading: "AI is cloning your tone and restructuring your mind, please wait...",
		emptyAudio: "No clear audio detected, please try recording again.",
		historyTitle: "Dumps List",
		noHistory: "No records",
		configLabel: "Expand Preferences & Tone Setting",
		configLabelActive: "Collapse Preferences & Tone Setting",
		toneSampleLabel: "My writing style sample (AI will mimic this style):",
		promptLabel: "Extra prompt/instructions for this dump (optional):",
		toastSuccess: "BrainVent restructured successfully!",
		toastOffline: "Offline mode. Recording saved locally.",
		toastOfflineSync: "Network restored, automatically syncing offline records...",
		toastSyncSuccess: "Offline record synced successfully!",
		toastLoadSuccess: "History loaded",
		toastCopy: "Copied to clipboard",
		toastExport: "Successfully exported Markdown",
		toastDestroy: "Sent to Trash!",
		toastDeleteForever: "Permanently destroyed!",
		toastArchive: "Archived to Vault!",
		offlineBanner: "📶 Currently Offline — Your dumps are safely stored in your local browser.",
		offlineBadge: "offline mode",
		syncingSummary: "🔄 Auto syncing...",
		syncFailed: "⚠️ Sync failed, waiting for next attempt",
		offlinePendingSummary: "⏳ Saved Offline: Waiting for network connection to sync...",
		summaryTitle: "📝 Restructured Summary",
		copyBtn: "Copy Text",
		exportBtn: "📥 Export MD",
		notionSyncBtn: "⚡ Sync to Notion",
		archiveBtn: "📂 Archive to Vault",
		destroyBtn: "🗑️ Move to Trash",
		deleteForeverBtn: "💥 Destroy Forever",
		todoTitle: "✅ Native Todo Manager",
		noTodo: "Double-click here or add your first task below...",
		todoPlaceholder: "Enter task and press enter...",
		calendarTitle: "📅 Native Action Timeline",
		noCalendar: "No schedules found. Try dumping events with times",
		insightTitle: "💡 Key Insights",
		noInsight: "No creative insights found",
		mindWebTitle: "🕸️ Native Mind Web (Interactive)",
		guideHeader: "💡 Mind Flow Guide (ADHD Friendly)",
		
		// 5 Tools
		guide1Title: "1. Free Output",
		guide1Desc: "Jot down all ideas, tasks, or emotions. Ignore correctness and order. Like opening a tap to let water flow.",
		guide1Label: "Tools:",
		guide1Tools: [
			{ text: "🎤 Focus Mic", actionId: "focus-recorder" }
		] as ToolLink[],
		
		guide2Title: "2. Deconstruct",
		guide2Desc: "Break big goals into micro-tasks. Turn 'write report' into 'research', 'outline', and 'draft' to reduce mental friction.",
		guide2Label: "Tools:",
		guide2Tools: [
			{ text: "📋 Open Native Todo", actionId: "focus-todo" }
		] as ToolLink[],
		
		guide3Title: "3. Visual Connection",
		guide3Desc: "No diagram software required. AI automatically maps your insights & tasks into an interactive dragging web diagram.",
		guide3Label: "Tools:",
		guide3Tools: [
			{ text: "🕸️ Focus Mind Web", actionId: "focus-web" }
		] as ToolLink[],
		
		guide4Title: "4. Sort & Clean",
		guide4Desc: "Clean up your thoughts in seconds. Archive valuable insights to Vault and shred useless noise to Trash.",
		guide4Label: "Tools:",
		guide4Tools: [
			{ text: "📂 Archive to Vault", actionId: "direct-archive" },
			{ text: "💥 Permanent Destroy", actionId: "direct-destroy" }
		] as ToolLink[],
		
		guide5Title: "5. Action Translation",
		guide5Desc: "Translate vague thoughts into concrete timelines. See tasks automatically mapped onto a linear timeline.",
		guide5Label: "Tools:",
		guide5Tools: [
			{ text: "📅 Focus Timeline", actionId: "focus-calendar" }
		] as ToolLink[]
	}
};
