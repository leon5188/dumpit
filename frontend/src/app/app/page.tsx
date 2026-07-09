"use client";

import React, { useState, useEffect, useRef } from "react";

// 日程安排接口
interface CalendarEvent {
	title: string;
	time: string;
}

// 推荐工具链接结构
interface ToolLink {
	text: string;
	url?: string;
	actionId?: string;
}

// 拓扑节点结构
interface GraphNode {
	id: string;
	label: string;
	type: "insight" | "todo";
	x: number;
	y: number;
}

// 拓扑连线结构
interface GraphEdge {
	source: string;
	target: string;
}

// 升级版历史记录接口 (新增分类支持)
interface HistoryRecord {
	id: string;
	timestamp: string;
	rawText: string;
	summary: string;
	actionItems: string[];
	keyInsights: string[];
	calendarEvents: CalendarEvent[];
	status?: "done" | "offline_pending" | "syncing" | "error";
	folder?: "inbox" | "archive" | "trash"; // 新增：文件夹分类
	offlineAudio?: string;
	toneSample?: string;
	prompt?: string;
}

// i18n 字典升级 (把大厂工具替换为自研原生工具)
const translations = {
	zh: {
		title: "把混乱想法交给我",
		subtitle: "点击录音，开启无压力的脑力倾倒。AI 会自动过滤赘词并克隆您的文风。",
		placeholderTone: "在此贴入您平时随手写的、带有自己强烈口头语或措辞风格的段落，AI 将克隆您的文风...",
		placeholderPrompt: "例如：请翻译成英文、主要关注里面的周报内容、用大纲形式呈现...",
		startRecord: "点击上方麦克风开始录音",
		recording: "倾倒中，再次点击按钮完成整理...",
		uploading: "AI 正在进行智能语气克隆与多维度整理，请稍候...",
		emptyAudio: "未检测到明显的语音内容，请重新录音倾倒。",
		historyTitle: "历史记录",
		noHistory: "暂无记录",
		configLabel: "展开偏好与文风设置（克隆语气）",
		configLabelActive: "收起偏好与文风设置",
		toneSampleLabel: "我的写作与表达风格参考样例（AI 会以此文风重构）：",
		promptLabel: "本次处理的额外指令/要求（选填）：",
		toastSuccess: "脑力倾倒整理成功！",
		toastOffline: "当前处于离线状态，录音已安全保存在本地。",
		toastOfflineSync: "检测到网络已恢复，自动同步离线倾倒记录...",
		toastSyncSuccess: "离线记录同步成功！",
		toastLoadSuccess: "历史记录加载成功",
		toastCopy: "整理文本已复制到剪贴板",
		toastExport: "成功导出为 Markdown 文件",
		toastDestroy: "记录已放入回收站！",
		toastDeleteForever: "记录已永久粉碎！",
		toastArchive: "记录已成功移入保险箱！",
		offlineBanner: "📶 当前处于离线状态 — 您的所有脑力倾倒将安全保存在本地浏览器中。",
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
		guide3Desc: "无需下载Xmind，AI会根据你的灵感与任务，自动绘制一个可交互拖拽的发光网状想法图，看清思维链路。",
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
		toastSuccess: "Brain dump restructured successfully!",
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
		guide3Desc: "No Xmind required. AI automatically maps your insights & tasks into an interactive dragging web diagram.",
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

export default function Home() {
	// 多语言控制
	const [lang, setLang] = useState<"zh" | "en">("zh");
	const t = translations[lang];

	// 侧边栏文件夹切换
	const [sidebarFolder, setSidebarFolder] = useState<"inbox" | "archive" | "trash">("inbox");

	// 录音状态与编译
	const [isRecording, setIsRecording] = useState(false);
	const [recordingTime, setRecordingTime] = useState(0);
	const [status, setStatus] = useState<"idle" | "recording" | "uploading" | "done" | "error">("idle");
	const [errorMessage, setErrorMessage] = useState("");
	const [isOnline, setIsOnline] = useState(true);

	// 输入配置
	const [userToneSample, setUserToneSample] = useState("");
	const [customPrompt, setCustomPrompt] = useState("");
	const [notionToken, setNotionToken] = useState("");
	const [notionPageId, setNotionPageId] = useState("");
	const [licenseKey, setLicenseKey] = useState("");
	const [isPremium, setIsPremium] = useState(false);
	const [showConfig, setShowConfig] = useState(false);
	const [showGuide, setShowGuide] = useState(true);

	// 当前处理结果
	const [summary, setSummary] = useState("");
	const [actionItems, setActionItems] = useState<string[]>([]);
	const [newTodoText, setNewTodoText] = useState(""); // 新待办输入
	const [checkedItems, setCheckedItems] = useState<Record<number, boolean>>({});
	const [keyInsights, setKeyInsights] = useState<string[]>([]);
	const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);

	// 🕸️ 原生拓扑网状图状态
	const [nodes, setNodes] = useState<GraphNode[]>([]);
	const [edges, setEdges] = useState<GraphEdge[]>([]);
	const [draggedNodeId, setDraggedNodeId] = useState<string | null>(null);

	// 历史记录
	const [historyList, setHistoryList] = useState<HistoryRecord[]>([]);
	const [activeRecordId, setActiveRecordId] = useState<string | null>(null);

	// 提示消息
	const [toastMessage, setToastMessage] = useState("");

	// 录音 Refs
	const mediaRecorderRef = useRef<MediaRecorder | null>(null);
	const audioChunksRef = useRef<Blob[]>([]);
	const timerRef = useRef<NodeJS.Timeout | null>(null);

	// 聚焦与光晕 Ref
	const recorderRef = useRef<HTMLDivElement | null>(null);
	const summaryCardRef = useRef<HTMLDivElement | null>(null);
	const todoCardRef = useRef<HTMLDivElement | null>(null);
	const calendarCardRef = useRef<HTMLDivElement | null>(null);
	const mindWebRef = useRef<HTMLDivElement | null>(null);

	// 1. 初始化
	useEffect(() => {
		if (typeof window !== "undefined") {
			setIsOnline(navigator.onLine);

			const handleOnlineStatus = () => setIsOnline(true);
			const handleOfflineStatus = () => setIsOnline(false);

			window.addEventListener("online", handleOnlineStatus);
			window.addEventListener("offline", handleOfflineStatus);

			const savedLang = localStorage.getItem("dumpit_lang");
			if (savedLang === "zh" || savedLang === "en") setLang(savedLang);

			const savedTone = localStorage.getItem("dumpit_user_tone");
			if (savedTone) setUserToneSample(savedTone);

			const savedNotionToken = localStorage.getItem("dumpit_notion_token");
			if (savedNotionToken) setNotionToken(savedNotionToken);

			const savedNotionPage = localStorage.getItem("dumpit_notion_page_id");
			if (savedNotionPage) setNotionPageId(savedNotionPage);

			const savedLicenseKey = localStorage.getItem("dumpit_license_key");
			if (savedLicenseKey) setLicenseKey(savedLicenseKey);

			const savedIsPremium = localStorage.getItem("dumpit_is_premium");
			if (savedIsPremium === "true") setIsPremium(true);

			const savedHistory = localStorage.getItem("dumpit_history");
			if (savedHistory) {
				try {
					setHistoryList(JSON.parse(savedHistory));
				} catch (e) {
					console.error("Failed to parse history", e);
				}
			}

			return () => {
				window.removeEventListener("online", handleOnlineStatus);
				window.removeEventListener("offline", handleOfflineStatus);
			};
		}
	}, []);

	// 切换语言
	const toggleLanguage = () => {
		const nextLang = lang === "zh" ? "en" : "zh";
		setLang(nextLang);
		localStorage.setItem("dumpit_lang", nextLang);
	};

	// Base64 转 Blob 辅助函数 (离线同步)
	const base64ToBlob = (base64: string, mimeType: string): Blob => {
		const byteCharacters = atob(base64.split(",")[1] || base64);
		const byteNumbers = new Array(byteCharacters.length);
		for (let i = 0; i < byteCharacters.length; i++) {
			byteNumbers[i] = byteCharacters.charCodeAt(i);
		}
		const byteArray = new Uint8Array(byteNumbers);
		return new Blob([byteArray], { type: mimeType });
	};

	// ⚡ 向 Go 后端发起同步到 Notion 的请求
	const syncToNotion = async () => {
		if (!isPremium) {
			alert(lang === "zh" ? "🔒 提示: 一键同步到 Notion 是黄金会员专属特权！请在下方偏好配置中填写激活码激活授权。" : "🔒 Notice: Notion 1-Click Sync is a Premium privilege! Please activate your license key in settings.");
			return;
		}

		if (!notionToken || !notionPageId) {
			alert(lang === "zh" ? "⚠️ 请先展开配置并填写 Notion Token 与 Page ID" : "⚠️ Please fill Notion Token & Page ID first");
			return;
		}

		alert(lang === "zh" ? "正在同步到 Notion..." : "Syncing to Notion...");

		try {
			const res = await fetch("http://localhost:8080/api/notion/sync", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify({
					notion_token: notionToken,
					parent_page_id: notionPageId,
					summary: summary,
					action_items: actionItems,
					key_insights: keyInsights,
					calendar_events: calendarEvents.map(e => ({
						title: e.title,
						time: e.time,
					})),
				}),
			});

			const data = await res.json();
			if (res.ok) {
				alert(lang === "zh" ? "🎉 同步成功！已在 Notion 中创建页面。" : "🎉 Synced to Notion successfully!");
			} else {
				alert(lang === "zh" ? `⚠️ 同步失败: ${data.error}` : `⚠️ Sync failed: ${data.error}`);
			}
		} catch (err) {
			alert(lang === "zh" ? `⚠️ 网络错误: ${err}` : `⚠️ Network error: ${err}`);
		}
	};

	// 🔒 调用后端核销激活码
	const verifyLicense = async () => {
		if (!licenseKey) {
			alert(lang === "zh" ? "⚠️ 请先输入激活码" : "⚠️ Please input license key first");
			return;
		}

		alert(lang === "zh" ? "正在连接支付中心校验激活码..." : "Verifying license key with payment center...");

		try {
			const res = await fetch("http://localhost:8080/api/license/verify", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify({
					license_key: licenseKey,
					instance_name: "BrainVent Web App Client"
				}),
			});

			const data = await res.json();
			if (res.ok && data.success) {
				setIsPremium(true);
				localStorage.setItem("dumpit_is_premium", "true");
				localStorage.setItem("dumpit_license_key", licenseKey);
				alert(lang === "zh" ? "🎉 激活成功！欢迎成为 BrainVent. 黄金会员！" : "🎉 Activated successfully! Welcome to BrainVent. Premium!");
			} else {
				alert(lang === "zh" ? `⚠️ 激活失败: ${data.error}` : `⚠️ Activation failed: ${data.error}`);
			}
		} catch (err) {
			alert(lang === "zh" ? `⚠️ 激活网络错误: ${err}` : `⚠️ Network error during activation: ${err}`);
		}
	};

	// 2. 自动构建 SVG 拓扑网状节点（圆周坐标分布）
	useEffect(() => {
		if (summary && (keyInsights.length > 0 || actionItems.length > 0)) {
			const newNodes: GraphNode[] = [];
			const newEdges: GraphEdge[] = [];
			
			const centerX = 250;
			const centerY = 190;
			const radius = 100;
			
			const totalItems = keyInsights.length + actionItems.length;
			
			keyInsights.forEach((insight, idx) => {
				const angle = (idx / totalItems) * 2 * Math.PI;
				newNodes.push({
					id: `insight-${idx}`,
					label: insight.length > 15 ? insight.slice(0, 15) + "..." : insight,
					type: "insight",
					x: centerX + radius * Math.cos(angle),
					y: centerY + radius * Math.sin(angle),
				});
			});
			
			actionItems.forEach((todo, idx) => {
				const angle = ((keyInsights.length + idx) / totalItems) * 2 * Math.PI;
				newNodes.push({
					id: `todo-${idx}`,
					label: todo.length > 15 ? todo.slice(0, 15) + "..." : todo,
					type: "todo",
					x: centerX + radius * Math.cos(angle),
					y: centerY + radius * Math.sin(angle),
				});
			});
			
			// 建立连接边结构（让节点串联成网状）
			for (let i = 0; i < newNodes.length; i++) {
				newEdges.push({
					source: newNodes[i].id,
					target: newNodes[(i + 1) % newNodes.length].id,
				});
				if (newNodes[i].type === "todo" && newNodes.length > 2) {
					newEdges.push({
						source: newNodes[i].id,
						target: newNodes[0].id,
					});
				}
			}
			
			setNodes(newNodes);
			setEdges(newEdges);
		} else {
			setNodes([]);
			setEdges([]);
		}
	}, [summary, keyInsights, actionItems]);

	// 3. SVG 节点拖拽事件绑定
	const handleMouseDown = (nodeId: string) => {
		setDraggedNodeId(nodeId);
	};

	const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
		if (!draggedNodeId) return;
		const rect = e.currentTarget.getBoundingClientRect();
		const mouseX = e.clientX - rect.left;
		const mouseY = e.clientY - rect.top;
		
		setNodes((prev) =>
			prev.map((node) =>
				node.id === draggedNodeId ? { ...node, x: mouseX, y: mouseY } : node
			)
		);
	};

	const handleMouseUp = () => {
		setDraggedNodeId(null);
	};

	// 4. 录音计时
	useEffect(() => {
		if (isRecording) {
			timerRef.current = setInterval(() => {
				setRecordingTime((prev) => prev + 1);
			}, 1000);
		} else {
			if (timerRef.current) {
				clearInterval(timerRef.current);
				timerRef.current = null;
			}
			setRecordingTime(0);
		}
		return () => {
			if (timerRef.current) clearInterval(timerRef.current);
		};
	}, [isRecording]);

	// 5. 离线暂存自动同步
	useEffect(() => {
		if (isOnline && historyList.some(r => r.status === "offline_pending")) {
			showToast(t.toastOfflineSync);
			syncOfflineRecords();
		}
	}, [isOnline, historyList]);

	// 6. 录制开始与停止
	const startRecording = async () => {
		audioChunksRef.current = [];
		try {
			const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
			let options = {};
			if (MediaRecorder.isTypeSupported("audio/webm")) {
				options = { mimeType: "audio/webm" };
			} else if (MediaRecorder.isTypeSupported("audio/mp4")) {
				options = { mimeType: "audio/mp4" };
			}

			const mediaRecorder = new MediaRecorder(stream, options);
			mediaRecorderRef.current = mediaRecorder;

			mediaRecorder.ondataavailable = (event) => {
				if (event.data.size > 0) {
					audioChunksRef.current.push(event.data);
				}
			};

			mediaRecorder.onstop = async () => {
				const audioBlob = new Blob(audioChunksRef.current, { type: mediaRecorder.mimeType });
				stream.getTracks().forEach((track) => track.stop());
				
				if (navigator.onLine) {
					await uploadAndProcess(audioBlob);
				} else {
					await saveOffline(audioBlob);
				}
			};

			mediaRecorder.start(250);
			setIsRecording(true);
			setStatus("recording");
			setErrorMessage("");
		} catch (err: any) {
			console.error("Mic error", err);
			setErrorMessage(lang === "zh" ? "无法访问麦克风，请检查浏览器权限！" : "Failed to access mic, check settings!");
			setStatus("error");
		}
	};

	const stopRecording = () => {
		if (mediaRecorderRef.current && isRecording) {
			mediaRecorderRef.current.stop();
			setIsRecording(false);
		}
	};

	// 7. 离线保存
	const saveOffline = async (audioBlob: Blob) => {
		setStatus("idle");
		showToast(t.toastOffline);

		const reader = new FileReader();
		reader.readAsDataURL(audioBlob);
		reader.onloadend = () => {
			const base64Audio = reader.result as string;
			const newRecord: HistoryRecord = {
				id: Date.now().toString(),
				timestamp: new Date().toLocaleString(),
				rawText: "",
				summary: t.offlinePendingSummary,
				actionItems: [],
				keyInsights: [],
				calendarEvents: [],
				status: "offline_pending",
				folder: "inbox", // 默认在 Inbox
				offlineAudio: base64Audio,
				toneSample: userToneSample,
				prompt: customPrompt,
			};

			const updatedHistory = [newRecord, ...historyList].slice(0, 50);
			setHistoryList(updatedHistory);
			localStorage.setItem("dumpit_history", JSON.stringify(updatedHistory));
			setActiveRecordId(newRecord.id);
		};
	};

	// 8. 离线静默同步
	const syncOfflineRecords = async () => {
		const recordsToSync = historyList.filter(r => r.status === "offline_pending");
		let currentHistory = [...historyList];

		for (const record of recordsToSync) {
			currentHistory = currentHistory.map(r => r.id === record.id ? { ...r, status: "syncing", summary: t.syncingSummary } : r);
			setHistoryList(currentHistory);

			if (!record.offlineAudio) continue;

			try {
				const audioBlob = base64ToBlob(record.offlineAudio, "audio/webm");
				const formData = new FormData();
				const audioFile = new File([audioBlob], `sync_audio.webm`, { type: audioBlob.type });
				formData.append("audio", audioFile);
				formData.append("user_tone_sample", record.toneSample || "");
				formData.append("custom_prompt", record.prompt || "");

				const response = await fetch("http://localhost:8080/api/process-audio", {
					method: "POST",
					body: formData,
				});

				if (!response.ok) throw new Error("Sync failed");

				const data = await response.json();

				currentHistory = currentHistory.map(r => r.id === record.id ? {
					...r,
					summary: data.summary,
					actionItems: data.action_items || [],
					keyInsights: data.key_insights || [],
					calendarEvents: data.calendar_events || [],
					status: "done",
					offlineAudio: undefined,
				} : r);
				
				if (activeRecordId === record.id) {
					setSummary(data.summary);
					setActionItems(data.action_items || []);
					setKeyInsights(data.key_insights || []);
					setCalendarEvents(data.calendar_events || []);
				}

				showToast(t.toastSyncSuccess);
			} catch (err) {
				console.error("Failed to sync record: " + record.id, err);
				currentHistory = currentHistory.map(r => r.id === record.id ? { ...r, status: "error", summary: t.syncFailed } : r);
			}

			setHistoryList(currentHistory);
			localStorage.setItem("dumpit_history", JSON.stringify(currentHistory));
		}
	};

	// 9. 在线音频提交
	const uploadAndProcess = async (audioBlob: Blob) => {
		setStatus("uploading");
		
		const formData = new FormData();
		const ext = mediaRecorderRef.current?.mimeType.includes("webm") ? "webm" : "mp4";
		const audioFile = new File([audioBlob], `dump_audio.${ext}`, { type: audioBlob.type });
		
		formData.append("audio", audioFile);
		formData.append("user_tone_sample", userToneSample);
		formData.append("custom_prompt", customPrompt);

		try {
			const response = await fetch("http://localhost:8080/api/process-audio", {
				method: "POST",
				body: formData,
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(errorData.error || "Server processing failed");
			}

			const data = await response.json();

			// 填充当前状态
			setSummary(data.summary);
			setActionItems(data.action_items || []);
			setKeyInsights(data.key_insights || []);
			setCalendarEvents(data.calendar_events || []);
			setCheckedItems({});

			// 写入历史数据库
			const newRecord: HistoryRecord = {
				id: Date.now().toString(),
				timestamp: new Date().toLocaleString(),
				rawText: "",
				summary: data.summary,
				actionItems: data.action_items || [],
				keyInsights: data.key_insights || [],
				calendarEvents: data.calendar_events || [],
				status: "done",
				folder: "inbox", // 默认放入收件箱
			};

			const updatedHistory = [newRecord, ...historyList].slice(0, 50);
			setHistoryList(updatedHistory);
			localStorage.setItem("dumpit_history", JSON.stringify(updatedHistory));
			setActiveRecordId(newRecord.id);

			setStatus("done");
			showToast(t.toastSuccess);
		} catch (err: any) {
			console.error("Processing failed", err);
			setErrorMessage(err.message || "Service temporarily offline.");
			setStatus("error");
		}
	};

	// 10. 载入历史卡片
	const loadRecord = (record: HistoryRecord) => {
		setSummary(record.summary);
		setActionItems(record.actionItems || []);
		setKeyInsights(record.keyInsights || []);
		setCalendarEvents(record.calendarEvents || []);
		setCheckedItems({});
		setActiveRecordId(record.id);
		setStatus(record.status === "offline_pending" ? "idle" : "done");
		if (record.status === "offline_pending") {
			setErrorMessage(lang === "zh" ? "该条记录处于离线状态，联网后将自动同步处理。" : "Offline pending, waiting for network to sync.");
		} else {
			setErrorMessage("");
		}
	};

	// 11. 归档到本地保险箱 (Notion 替代方案)
	const archiveRecord = () => {
		if (!activeRecordId) return;
		const updated = historyList.map(r => r.id === activeRecordId ? { ...r, folder: "archive" as const } : r);
		setHistoryList(updated);
		localStorage.setItem("dumpit_history", JSON.stringify(updated));
		showToast(t.toastArchive);
		
		// 归档后清空当前视图
		setSummary("");
		setActionItems([]);
		setKeyInsights([]);
		setCalendarEvents([]);
		setCheckedItems({});
		setActiveRecordId(null);
		setStatus("idle");
	};

	// 12. 移入回收站/永久删除 (粉碎动作升级)
	const destroyRecord = () => {
		if (!activeRecordId) return;
		
		let updated: HistoryRecord[] = [];
		if (sidebarFolder === "trash") {
			// 如果已经在垃圾桶里，点击粉碎代表【永久删除】
			updated = historyList.filter(r => r.id !== activeRecordId);
			showToast(t.toastDeleteForever);
		} else {
			// 在 Inbox 或 Archive 里，点击粉碎代表【移入回收站】
			updated = historyList.map(r => r.id === activeRecordId ? { ...r, folder: "trash" as const } : r);
			showToast(t.toastDestroy);
		}

		setHistoryList(updated);
		localStorage.setItem("dumpit_history", JSON.stringify(updated));
		
		setSummary("");
		setActionItems([]);
		setKeyInsights([]);
		setCalendarEvents([]);
		setCheckedItems({});
		setActiveRecordId(null);
		setStatus("idle");
	};

	// 【功能升级】：待办管理器的添加和删除 (代替滴答清单)
	const handleAddTodo = (e: React.FormEvent) => {
		e.preventDefault();
		if (!newTodoText.trim()) return;
		
		const updatedTodos = [...actionItems, newTodoText.trim()];
		setActionItems(updatedTodos);
		setNewTodoText("");

		// 同步更新本地历史数据库中的这条记录
		if (activeRecordId) {
			const updated = historyList.map(r => r.id === activeRecordId ? { ...r, actionItems: updatedTodos } : r);
			setHistoryList(updated);
			localStorage.setItem("dumpit_history", JSON.stringify(updated));
		}
	};

	const handleDeleteTodo = (indexToDelete: number, e: React.MouseEvent) => {
		e.stopPropagation(); // 防止触发 todo 勾选事件
		const updatedTodos = actionItems.filter((_, idx) => idx !== indexToDelete);
		setActionItems(updatedTodos);

		// 重置 checkedItems 的索引映射
		const newChecked: Record<number, boolean> = {};
		Object.entries(checkedItems).forEach(([key, val]) => {
			const numericKey = parseInt(key, 10);
			if (numericKey < indexToDelete) {
				newChecked[numericKey] = val;
			} else if (numericKey > indexToDelete) {
				newChecked[numericKey - 1] = val;
			}
		});
		setCheckedItems(newChecked);

		if (activeRecordId) {
			const updated = historyList.map(r => r.id === activeRecordId ? { ...r, actionItems: updatedTodos } : r);
			setHistoryList(updated);
			localStorage.setItem("dumpit_history", JSON.stringify(updated));
		}
	};

	// 指南操作聚焦分配器
	const executeGuideAction = (actionId: string) => {
		let targetRef: React.RefObject<HTMLDivElement | null> | null = null;
		
		if (actionId === "focus-recorder") {
			targetRef = recorderRef;
		} else if (actionId === "focus-todo") {
			targetRef = todoCardRef;
		} else if (actionId === "focus-calendar") {
			targetRef = calendarCardRef;
		} else if (actionId === "focus-web") {
			targetRef = mindWebRef;
		} else if (actionId === "direct-archive") {
			if (!summary) {
				showToast(lang === "zh" ? "请先录音生成数据以启用归档" : "Please record to generate data first");
				return;
			}
			archiveRecord();
			return;
		} else if (actionId === "direct-destroy") {
			if (!summary) {
				showToast(lang === "zh" ? "请先录音生成数据以启用粉碎" : "Please record to generate data first");
				return;
			}
			destroyRecord();
			return;
		}

		if (targetRef && targetRef.current) {
			targetRef.current.scrollIntoView({ behavior: "smooth", block: "center" });
			targetRef.current.classList.add("highlight-flash");
			const el = targetRef.current;
			setTimeout(() => {
				el?.classList.remove("highlight-flash");
			}, 1200);
		} else {
			showToast(lang === "zh" ? "请先录音生成数据以显示对应卡片" : "Please record first to display this card");
		}
	};

	// 导出 Markdown
	const exportToMarkdown = () => {
		const mdContent = `# BrainVent Restructured - ${new Date().toLocaleString()}

## Summary
${summary}

## Action Items
${actionItems.map((item, idx) => `- [${checkedItems[idx] ? "x" : " "}] ${item}`).join("\n")}

## Key Insights
${keyInsights.map(item => `- ${item}`).join("\n")}

## Calendar Schedule
${calendarEvents.map(event => `- **${event.title}** (${event.time})`).join("\n")}
`;
		const blob = new Blob([mdContent], { type: "text/markdown;charset=utf-8;" });
		const url = URL.createObjectURL(blob);
		const link = document.createElement("a");
		link.href = url;
		link.setAttribute("download", `BrainVent_Record_${Date.now()}.md`);
		document.body.appendChild(link);
		link.click();
		document.body.removeChild(link);
		showToast(t.toastExport);
	};

	const copyToClipboard = () => {
		navigator.clipboard.writeText(summary);
		showToast(t.toastCopy);
	};

	const toggleTodo = (index: number) => {
		setCheckedItems((prev) => ({
			...prev,
			[index]: !prev[index],
		}));
	};

	const formatTime = (seconds: number) => {
		const mins = Math.floor(seconds / 60);
		const secs = seconds % 60;
		return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
	};

	const showToast = (msg: string) => {
		setToastMessage(msg);
		setTimeout(() => setToastMessage(""), 3000);
	};

	// 过滤出对应侧边栏文件夹下的历史记录
	const filteredHistory = historyList.filter(record => (record.folder || "inbox") === sidebarFolder);

	return (
		<div className="app-container">
			{/* 侧边栏：分类箱与历史列表 */}
			<aside className="sidebar">
				<div className="logo-container" style={{ display: "flex", alignItems: "center", flexWrap: "wrap", gap: "4px" }}>
					<div style={{ display: "flex", alignItems: "center" }}>
						<img src="/logo.jpg" alt="BrainVent" style={{ width: "30px", height: "30px", borderRadius: "8px", border: "1.5px solid #8B5CF6", marginRight: "6px" }} />
						<div className="logo-text">
							BrainVent<span className="logo-dot">.</span>
						</div>
					</div>
					{isPremium && (
						<span style={{ fontSize: "10px", padding: "2px 6px", borderRadius: "20px", background: "linear-gradient(90deg, #FBBF24 0%, #F59E0B 100%)", color: "#000", fontWeight: "bold", marginLeft: "4px", boxShadow: "0 0 8px rgba(251,191,36,0.5)" }}>
							👑 PREMIUM
						</span>
					)}
				</div>

				{/* 【功能升级】：Inbox / Archive / Trash 本地分类箱 */}
				<div className="sidebar-tabs">
					<button 
						className={`sidebar-tab-btn ${sidebarFolder === "inbox" ? "active" : ""}`}
						onClick={() => setSidebarFolder("inbox")}
						title="Inbox"
					>
						📥 Inbox
					</button>
					<button 
						className={`sidebar-tab-btn ${sidebarFolder === "archive" ? "active" : ""}`}
						onClick={() => setSidebarFolder("archive")}
						title="Vault"
					>
						📂 Vault
					</button>
					<button 
						className={`sidebar-tab-btn ${sidebarFolder === "trash" ? "active" : ""}`}
						onClick={() => setSidebarFolder("trash")}
						title="Trash"
					>
						🗑️ Trash
					</button>
				</div>
				
				<h3 className="sidebar-title">{t.historyTitle}</h3>
				<ul className="history-list">
					{filteredHistory.length === 0 ? (
						<li style={{ padding: "1rem", fontSize: "0.85rem", color: "var(--text-dark)", textAlign: "center" }}>
							{t.noHistory}
						</li>
					) : (
						filteredHistory.map((record) => (
							<li
								key={record.id}
								className={`history-item ${activeRecordId === record.id ? "active" : ""}`}
								onClick={() => loadRecord(record)}
							>
								<span className="history-time">{record.timestamp}</span>
								<div className={`history-preview ${record.status === "syncing" ? "status-syncing" : ""}`}>
									{record.summary}
								</div>
							</li>
						))
					)}
				</ul>
				
				<div className="sidebar-footer">
					BrainVent & KeepIt v2.0.0
				</div>
			</aside>

			{/* 主内容区 */}
			<main className="main-content">
				{/* 语言切换 */}
				<div className="top-nav">
					<button className="lang-switch-btn" onClick={toggleLanguage}>
						🌐 {lang === "zh" ? "English" : "简体中文"}
					</button>
				</div>

				{/* 离线通知 */}
				{!isOnline && (
					<div className="offline-banner">
						<div>
							<strong>{t.offlineBanner}</strong>
						</div>
						<div className="offline-sync-badge">{t.offlineBadge}</div>
					</div>
				)}

				<header className="header">
					<h1>{t.title}</h1>
					<p>{t.subtitle}</p>
				</header>

				{/* 录音卡片 */}
				<section ref={recorderRef} className="recorder-card">
					{status === "uploading" ? (
						<div className="loader-container">
							<div className="spinner"></div>
							<div className="recorder-status">{t.uploading}</div>
						</div>
					) : (
						<>
							<div className={`record-btn-container ${isRecording ? "pulse-active" : ""}`}>
								<div className="pulse-ring"></div>
								<button
									className="record-btn"
									onClick={isRecording ? stopRecording : startRecording}
									title={isRecording ? "Stop" : "Record"}
								>
									{isRecording ? (
										<svg viewBox="0 0 24 24"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>
									) : (
										<svg viewBox="0 0 24 24"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z"/></svg>
									)}
								</button>
							</div>

							<div className="recorder-timer">
								{isRecording ? formatTime(recordingTime) : "00:00"}
							</div>
							
							<div className="recorder-status">
								{isRecording ? t.recording : t.startRecord}
							</div>
						</>
					)}

					{status === "error" && (
						<div style={{ color: "var(--color-error)", marginTop: "1rem", fontSize: "0.9rem" }}>
							⚠️ {errorMessage}
						</div>
					)}

					{/* 配置抽屉 */}
					<div className="config-section">
						<button 
							className={`config-toggle ${showConfig ? "active" : ""}`}
							onClick={() => setShowConfig(!showConfig)}
						>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M6 9l6 6 6-6"/></svg>
							{showConfig ? t.configLabelActive : t.configLabel}
						</button>

						{showConfig && (
							<div className="config-fields">
								<div className="input-group">
									<label htmlFor="tone-sample">{t.toneSampleLabel}</label>
									<textarea
										id="tone-sample"
										className="textarea-field"
										placeholder={t.placeholderTone}
										value={userToneSample}
										onChange={(e) => {
											setUserToneSample(e.target.value);
											localStorage.setItem("dumpit_user_tone", e.target.value);
										}}
									/>
								</div>
								<div className="input-group">
									<label htmlFor="custom-prompt">{t.promptLabel}</label>
									<textarea
										id="custom-prompt"
										className="textarea-field"
										placeholder={t.placeholderPrompt}
										value={customPrompt}
										onChange={(e) => setCustomPrompt(e.target.value)}
									/>
								</div>
								<div className="input-group">
									<label htmlFor="notion-token" style={{ color: "#8B5CF6", fontWeight: "bold" }}>{lang === "zh" ? "⚡ Notion Integration Token (secret_...)" : "⚡ Notion Integration Token (secret_...)"}</label>
									<input
										id="notion-token"
										type="password"
										className="input-field"
										placeholder="secret_..."
										value={notionToken}
										onChange={(e) => {
											setNotionToken(e.target.value);
											localStorage.setItem("dumpit_notion_token", e.target.value);
										}}
										style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.08)", color: "#fff", padding: "0.5rem", borderRadius: "8px", outline: "none", fontSize: "12px", marginTop: "4px" }}
									/>
								</div>
								<div className="input-group" style={{ marginTop: "10px" }}>
									<label htmlFor="notion-page-id" style={{ color: "#8B5CF6", fontWeight: "bold" }}>{lang === "zh" ? "⚡ Notion 目标父 Page ID" : "⚡ Notion Parent Page ID"}</label>
									<input
										id="notion-page-id"
										type="text"
										className="input-field"
										placeholder="32位十六进制 ID"
										value={notionPageId}
										onChange={(e) => {
											setNotionPageId(e.target.value);
											localStorage.setItem("dumpit_notion_page_id", e.target.value);
										}}
										style={{ background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.08)", color: "#fff", padding: "0.5rem", borderRadius: "8px", outline: "none", fontSize: "12px", marginTop: "4px" }}
									/>
								</div>
								<div className="input-group" style={{ marginTop: "10px" }}>
									<label htmlFor="license-key" style={{ color: "#FBBF24", fontWeight: "bold" }}>{lang === "zh" ? "🔑 BrainVent. 黄金会员激活码 (License Key)" : "🔑 BrainVent. Premium License Key"}</label>
									<div style={{ display: "flex", gap: "8px", marginTop: "4px" }}>
										<input
											id="license-key"
											type="password"
											className="input-field"
											placeholder="e.g. LSQ-..."
											value={licenseKey}
											onChange={(e) => {
												setLicenseKey(e.target.value);
											}}
											style={{ flex: 1, background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.08)", color: "#fff", padding: "0.5rem", borderRadius: "8px", outline: "none", fontSize: "12px" }}
										/>
										<button 
											onClick={verifyLicense}
											style={{ background: "linear-gradient(90deg, #FBBF24 0%, #F59E0B 100%)", color: "#000", border: "none", borderRadius: "8px", padding: "0 1rem", fontSize: "12px", fontWeight: "bold", cursor: "pointer" }}
										>
											{lang === "zh" ? "激活" : "Activate"}
										</button>
									</div>
								</div>
							</div>
						)}
					</div>
				</section>

				{/* 整理结果 */}
				{summary && (
					<section className="results-grid">
						{/* 整理主卡片 */}
						<div ref={summaryCardRef} className="glass-panel">
							<div className="panel-header">
								<h2 className="panel-title">{t.summaryTitle}</h2>
								<div className="panel-actions-wrapper">
									<button className="panel-action-btn" onClick={copyToClipboard}>
										{t.copyBtn}
									</button>
									<button className="panel-action-btn" onClick={exportToMarkdown}>
										{t.exportBtn}
									</button>
									<button className="panel-action-btn btn-sync-notion" onClick={syncToNotion} style={{ color: "#FBBF24", border: "1px solid rgba(251,191,36,0.3)", background: "rgba(251,191,36,0.05)" }}>
										{t.notionSyncBtn}
									</button>
									
									{/* 【功能升级】：原生归档与删除/彻底粉碎按钮 */}
									<button className="panel-action-btn" onClick={archiveRecord}>
										{t.archiveBtn}
									</button>
									<button className="panel-action-btn btn-destroy" onClick={destroyRecord}>
										{sidebarFolder === "trash" ? t.deleteForeverBtn : t.destroyBtn}
									</button>
								</div>
							</div>
							<div className="summary-content" style={{ whiteSpace: "pre-wrap", lineHeight: "1.6" }}>{summary}</div>
							
							{/* 【功能升级】：原生发光的拖拽拓扑想法网络图 (Mind Web) */}
							<div ref={mindWebRef} className="panel-header" style={{ marginTop: "2rem", marginBottom: "0.5rem" }}>
								<h2 className="panel-title">{t.mindWebTitle}</h2>
							</div>
							<div className="mind-web-container">
								<svg 
									className="mind-web-svg" 
									onMouseMove={handleMouseMove} 
									onMouseUp={handleMouseUp}
									onMouseLeave={handleMouseUp}
								>
									{/* 渲染线连接 */}
									{edges.map((edge, idx) => {
										const sourceNode = nodes.find(n => n.id === edge.source);
										const targetNode = nodes.find(n => n.id === edge.target);
										if (!sourceNode || !targetNode) return null;
										return (
											<line
												key={idx}
												className="edge-line"
												x1={sourceNode.x}
												y1={sourceNode.y}
												x2={targetNode.x}
												y2={targetNode.y}
											/>
										);
									})}
									
									{/* 渲染发光的点和文本 */}
									{nodes.map((node) => (
										<g
											key={node.id}
											className="node-group"
											transform={`translate(${node.x}, ${node.y})`}
											onMouseDown={() => handleMouseDown(node.id)}
										>
											<circle
												className="node-circle"
												r="7"
												fill={node.type === "insight" ? "var(--color-primary)" : "var(--color-success)"}
												style={{ filter: "drop-shadow(0px 0px 4px rgba(139, 92, 246, 0.6))" }}
											/>
											<text
												className="node-text"
												dx="12"
												dy="4"
											>
												{node.label}
											</text>
										</g>
									))}
								</svg>
							</div>
						</div>

						{/* 右侧边栏：待办、日程与灵感 */}
						<div style={{ display: "flex", alignSelf: "stretch", flexDirection: "column", gap: "2rem" }}>
							
							{/* 【功能升级】：原生交互待办管理器 */}
							<div ref={todoCardRef} className="glass-panel">
								<div className="panel-header">
									<h2 className="panel-title">{t.todoTitle}</h2>
								</div>
								
								<div className="todo-list">
									{actionItems.length === 0 ? (
										<div style={{ color: "var(--text-dark)", fontSize: "0.85rem", padding: "0.5rem 0" }}>{t.noTodo}</div>
									) : (
										actionItems.map((todo, idx) => (
											<div key={idx} className="todo-item" onClick={() => toggleTodo(idx)}>
												<div className={`todo-checkbox ${checkedItems[idx] ? "checked" : ""}`}>
													{checkedItems[idx] && "✓"}
												</div>
												<span className="todo-text">{todo}</span>
												
												{/* 手动删除待办 */}
												<button 
													className="todo-item-delete"
													onClick={(e) => handleDeleteTodo(idx, e)}
													title="Delete task"
												>
													×
												</button>
											</div>
										))
									)}
								</div>

								{/* 添加待办输入表单 */}
								<form className="todo-input-container" onSubmit={handleAddTodo}>
									<input
										type="text"
										className="todo-add-input"
										placeholder={t.todoPlaceholder}
										value={newTodoText}
										onChange={(e) => setNewTodoText(e.target.value)}
									/>
									<button type="submit" className="todo-add-btn">+</button>
								</form>
							</div>

							{/* 【功能升级】：纵向时间轴日程安排 */}
							<div ref={calendarCardRef} className="glass-panel">
								<div className="panel-header">
									<h2 className="panel-title">{t.calendarTitle}</h2>
								</div>
								{calendarEvents.length === 0 ? (
									<div style={{ color: "var(--text-dark)", fontSize: "0.9rem" }}>{t.noCalendar}</div>
								) : (
									<div className="timeline-container">
										<div className="timeline-line"></div>
										{calendarEvents.map((event, idx) => (
											<div key={idx} className="timeline-item">
												<div className="timeline-badge"></div>
												<div className="timeline-content">
													<div className="timeline-title">{event.title}</div>
													<div className="timeline-time">
														<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
														{event.time}
													</div>
												</div>
											</div>
										))}
									</div>
								)}
							</div>

							{/* 灵感创意 */}
							<div className="glass-panel">
								<div className="panel-header">
									<h2 className="panel-title">{t.insightTitle}</h2>
								</div>
								{keyInsights.length === 0 ? (
									<div style={{ color: "var(--text-dark)", fontSize: "0.9rem" }}>{t.noInsight}</div>
								) : (
									<div className="insight-container">
										{keyInsights.map((insight, idx) => (
											<div key={idx} className="insight-card">
												<p className="insight-text">{insight}</p>
											</div>
										))}
									</div>
								)}
							</div>
						</div>
					</section>
				)}

				{/* 💡 大脑整理心流指南 (Mind Flow Guide) */}
				<section className="guide-section">
					<div className="guide-section-header" onClick={() => setShowGuide(!showGuide)}>
						<h2 className="guide-section-title">
							{t.guideHeader}
						</h2>
						<svg 
							width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
							style={{ transform: showGuide ? "rotate(180deg)" : "rotate(0deg)", transition: "transform 0.2s ease" }}
						>
							<path d="M6 9l6 6 6-6"/>
						</svg>
					</div>

					{showGuide && (
						<div className="guide-grid">
							{/* 卡片 1 */}
							<div className="guide-card">
								<div className="guide-card-icon">🌊</div>
								<h3 className="guide-card-title">{t.guide1Title}</h3>
								<p className="guide-card-desc">{t.guide1Desc}</p>
								<div className="guide-tools-wrapper">
									<span className="guide-tool-item">{t.guide1Label}</span>
									<div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
										{t.guide1Tools.map((tool, idx) => (
											<button key={idx} onClick={() => tool.actionId && executeGuideAction(tool.actionId)} className="guide-tool-action">
												{tool.text}
											</button>
										))}
									</div>
								</div>
							</div>

							{/* 卡片 2 */}
							<div className="guide-card">
								<div className="guide-card-icon">🧩</div>
								<h3 className="guide-card-title">{t.guide2Title}</h3>
								<p className="guide-card-desc">{t.guide2Desc}</p>
								<div className="guide-tools-wrapper">
									<span className="guide-tool-item">{t.guide2Label}</span>
									<div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
										{t.guide2Tools.map((tool, idx) => (
											<button key={idx} onClick={() => tool.actionId && executeGuideAction(tool.actionId)} className="guide-tool-action">
												{tool.text}
											</button>
										))}
									</div>
								</div>
							</div>

							{/* 卡片 3 */}
							<div className="guide-card">
								<div className="guide-card-icon">🕸️</div>
								<h3 className="guide-card-title">{t.guide3Title}</h3>
								<p className="guide-card-desc">{t.guide3Desc}</p>
								<div className="guide-tools-wrapper">
									<span className="guide-tool-item">{t.guide3Label}</span>
									<div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
										{t.guide3Tools.map((tool, idx) => (
											<button key={idx} onClick={() => tool.actionId && executeGuideAction(tool.actionId)} className="guide-tool-action">
												{tool.text}
											</button>
										))}
									</div>
								</div>
							</div>

							{/* 卡片 4 */}
							<div className="guide-card">
								<div className="guide-card-icon">🧹</div>
								<h3 className="guide-card-title">{t.guide4Title}</h3>
								<p className="guide-card-desc">{t.guide4Desc}</p>
								<div className="guide-tools-wrapper">
									<span className="guide-tool-item">{t.guide4Label}</span>
									<div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
										{t.guide4Tools.map((tool, idx) => (
											<button key={idx} onClick={() => tool.actionId && executeGuideAction(tool.actionId)} className="guide-tool-action">
												{tool.text}
											</button>
										))}
									</div>
								</div>
							</div>

							{/* 卡片 5 */}
							<div className="guide-card">
								<div className="guide-card-icon">🏃</div>
								<h3 className="guide-card-title">{t.guide5Title}</h3>
								<p className="guide-card-desc">{t.guide5Desc}</p>
								<div className="guide-tools-wrapper">
									<span className="guide-tool-item">{t.guide5Label}</span>
									<div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
										{t.guide5Tools.map((tool, idx) => (
											<button key={idx} onClick={() => tool.actionId && executeGuideAction(tool.actionId)} className="guide-tool-action">
												{tool.text}
											</button>
										))}
									</div>
								</div>
							</div>
						</div>
					)}
				</section>
			</main>

			{/* Toast */}
			{toastMessage && (
				<div className="toast">
					{toastMessage}
				</div>
			)}
		</div>
	);
}
