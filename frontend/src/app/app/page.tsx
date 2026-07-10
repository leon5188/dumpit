"use client";

import React, { useState, useEffect, useRef } from "react";
import { translations, CalendarEvent, ToolLink } from "./locales";
import MindWeb from "./components/MindWeb";
import TodoManager from "./components/TodoManager";
import TimelineView from "./components/TimelineView";
import GlobalMindLandscape from "./components/GlobalMindLandscape";

// 历史记录接口
interface HistoryRecord {
	id: string;
	timestamp: string;
	rawText: string;
	summary: string;
	actionItems: string[];
	keyInsights: string[];
	calendarEvents: CalendarEvent[];
	status?: "done" | "offline_pending" | "syncing" | "error";
	folder?: "inbox" | "archive" | "trash";
	offlineAudio?: string;
	toneSample?: string;
	prompt?: string;
}

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
	const [showGlobalLandscape, setShowGlobalLandscape] = useState(false);

	// 当前处理结果
	const [summary, setSummary] = useState("");
	const [actionItems, setActionItems] = useState<string[]>([]);
	const [keyInsights, setKeyInsights] = useState<string[]>([]);
	const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);

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
			let errMsg = lang === "zh" ? "无法访问麦克风，请检查浏览器权限！" : "Failed to access mic, check settings!";
			if (!navigator.mediaDevices) {
				errMsg = lang === "zh"
					? "⚠️ 浏览器安全策略限制：当前非 HTTPS 或 localhost 环境，浏览器已禁止网页访问麦克风。请使用 localhost (http://localhost:3000) 进行本地访问，或为您的域名配置 HTTPS！"
					: "⚠️ Security restriction: navigator.mediaDevices is undefined. Please access via localhost or HTTPS!";
			}
			setErrorMessage(errMsg);
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
				folder: "inbox",
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

			setSummary(data.summary);
			setActionItems(data.action_items || []);
			setKeyInsights(data.key_insights || []);
			setCalendarEvents(data.calendar_events || []);

			const newRecord: HistoryRecord = {
				id: Date.now().toString(),
				timestamp: new Date().toLocaleString(),
				rawText: "",
				summary: data.summary,
				actionItems: data.action_items || [],
				keyInsights: data.key_insights || [],
				calendarEvents: data.calendar_events || [],
				status: "done",
				folder: "inbox",
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
		setActiveRecordId(record.id);
		setStatus(record.status === "offline_pending" ? "idle" : "done");
		if (record.status === "offline_pending") {
			setErrorMessage(lang === "zh" ? "该条记录处于离线状态，联网后将自动同步处理。" : "Offline pending, waiting for network to sync.");
		} else {
			setErrorMessage("");
		}
	};

	// 11. 归档到本地保险箱
	const archiveRecord = () => {
		if (!activeRecordId) return;
		const updated = historyList.map(r => r.id === activeRecordId ? { ...r, folder: "archive" as const } : r);
		setHistoryList(updated);
		localStorage.setItem("dumpit_history", JSON.stringify(updated));
		showToast(t.toastArchive);
		
		setSummary("");
		setActionItems([]);
		setKeyInsights([]);
		setCalendarEvents([]);
		setActiveRecordId(null);
		setStatus("idle");
	};

	// 12. 移入回收站/永久删除
	const destroyRecord = () => {
		if (!activeRecordId) return;
		
		let updated: HistoryRecord[] = [];
		if (sidebarFolder === "trash") {
			updated = historyList.filter(r => r.id !== activeRecordId);
			showToast(t.toastDeleteForever);
		} else {
			updated = historyList.map(r => r.id === activeRecordId ? { ...r, folder: "trash" as const } : r);
			showToast(t.toastDestroy);
		}

		setHistoryList(updated);
		localStorage.setItem("dumpit_history", JSON.stringify(updated));
		
		setSummary("");
		setActionItems([]);
		setKeyInsights([]);
		setCalendarEvents([]);
		setActiveRecordId(null);
		setStatus("idle");
	};

	// 监听待办组件修改同步历史库
	const handleTodosChange = (updatedTodos: string[]) => {
		setActionItems(updatedTodos);
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
${actionItems.map((item) => `- [ ] ${item}`).join("\n")}

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

	const formatTime = (seconds: number) => {
		const mins = Math.floor(seconds / 60);
		const secs = seconds % 60;
		return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
	};

	const showToast = (msg: string) => {
		setToastMessage(msg);
		setTimeout(() => setToastMessage(""), 3000);
	};

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
				
				<div className="sidebar-footer" style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
					<button 
						className="sidebar-tab-btn" 
						style={{ 
							width: "100%", 
							background: "rgba(139, 92, 246, 0.1)", 
							border: "1px solid rgba(139, 92, 246, 0.3)", 
							color: "#a78bfa", 
							display: "flex", 
							alignItems: "center", 
							justifyContent: "center", 
							gap: "0.5rem",
							padding: "0.5rem",
							borderRadius: "8px",
							cursor: "pointer",
							fontSize: "0.85rem",
							fontWeight: "bold",
							boxShadow: "0 0 10px rgba(139, 92, 246, 0.1)"
						}}
						onClick={() => setShowGlobalLandscape(true)}
					>
						🌌 {lang === "zh" ? "查看全局脑力星空" : "View Global Landscape"}
					</button>
					<div style={{ textAlign: "center", opacity: 0.5, fontSize: "0.75rem" }}>
						BrainVent & KeepIt v2.0.0
					</div>
				</div>
			</aside>

			{/* 主内容区 */}
			<main className="main-content">
				<div className="top-nav">
					<button className="lang-switch-btn" onClick={toggleLanguage}>
						🌐 {lang === "zh" ? "English" : "简体中文"}
					</button>
				</div>

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
											onChange={(e) => setLicenseKey(e.target.value)}
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
									
									<button className="panel-action-btn" onClick={archiveRecord}>
										{t.archiveBtn}
									</button>
									<button className="panel-action-btn btn-destroy" onClick={destroyRecord}>
										{sidebarFolder === "trash" ? t.deleteForeverBtn : t.destroyBtn}
									</button>
								</div>
							</div>
							<div className="summary-content" style={{ whiteSpace: "pre-wrap", lineHeight: "1.6" }}>{summary}</div>
							
							{/* SVG 拓扑图独立组件 */}
							<div ref={mindWebRef}>
								<MindWeb 
									summary={summary} 
									keyInsights={keyInsights} 
									actionItems={actionItems} 
									title={t.mindWebTitle}
								/>
							</div>
						</div>

						{/* 右侧面板：待办、日程与灵感 */}
						<div style={{ display: "flex", alignSelf: "stretch", flexDirection: "column", gap: "2rem" }}>
							
							{/* 原生交互待办管理器组件 */}
							<div ref={todoCardRef}>
								<TodoManager 
									actionItems={actionItems}
									todoTitle={t.todoTitle}
									noTodo={t.noTodo}
									todoPlaceholder={t.todoPlaceholder}
									onTodosChange={handleTodosChange}
								/>
							</div>

							{/* 时间轴日程安排组件 */}
							<div ref={calendarCardRef}>
								<TimelineView 
									calendarEvents={calendarEvents}
									calendarTitle={t.calendarTitle}
									noCalendar={t.noCalendar}
								/>
							</div>

							{/* 灵感创意卡片 */}
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

				{/* 💡 大脑整理心流指南 */}
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

			{showGlobalLandscape && (
				<GlobalMindLandscape
					historyList={historyList}
					isZh={lang === "zh"}
					onClose={() => setShowGlobalLandscape(false)}
				/>
			)}
		</div>
	);
}
