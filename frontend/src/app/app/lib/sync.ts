import { getSessionToken } from "./auth";
import { postJsonAuthed, getJsonAuthed } from "./api";
import { HistoryRecord } from "./types";
import { CalendarEvent } from "../locales";

export interface ImportResult {
	failedIds: string[];
	idMapping: Record<string, string>;
}

interface ImportResponse {
	failed?: string[];
	imported?: { client_id: string; server_id: string }[];
}

interface BackendHistoryRecord {
	id: string;
	created_at?: string;
	raw_text?: string;
	summary?: {
		summary?: string;
		action_items?: string[];
		key_insights?: string[];
		calendar_events?: CalendarEvent[];
	};
	archived?: boolean;
}

interface HistoryListResponse {
	records?: BackendHistoryRecord[];
}

interface SubscriptionResponse {
	subscribed?: boolean;
	expires_at?: string | null;
}

function toBackendSummary(record: HistoryRecord) {
	return {
		summary: record.summary,
		action_items: record.actionItems,
		key_insights: record.keyInsights,
		calendar_events: record.calendarEvents,
	};
}

// 首次登录时，把本地全部历史记录一次性导入云端
export async function importLocalHistory(records: HistoryRecord[]): Promise<ImportResult> {
	const sessionToken = getSessionToken();
	if (!sessionToken || records.length === 0) return { failedIds: [], idMapping: {} };

	const payload = records.map((r) => ({
		client_id: r.id,
		summary: toBackendSummary(r),
		raw_text: r.rawText,
	}));

	const decoded = (await postJsonAuthed(
		"/api/history/import",
		{ records: payload },
		sessionToken,
		"历史记录导入失败"
	)) as ImportResponse;

	const failedIds: string[] = decoded.failed || [];
	const idMapping: Record<string, string> = {};
	for (const entry of decoded.imported || []) {
		idMapping[entry.client_id] = entry.server_id;
	}
	return { failedIds, idMapping };
}

// 新建一条记录后同步到云端；失败静默，调用方不应因此阻塞当前操作
export async function pushRecord(record: HistoryRecord): Promise<void> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return;
	try {
		await postJsonAuthed(
			"/api/history",
			{ summary: toBackendSummary(record), raw_text: record.rawText },
			sessionToken,
			"云端保存失败"
		);
	} catch (err) {
		console.warn("pushRecord failed", err);
	}
}

// 拉取云端全部历史记录（全量，不做增量，重装/换设备场景足够用）
export async function pullAllHistory(): Promise<HistoryRecord[]> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return [];

	const decoded = (await getJsonAuthed("/api/history", sessionToken, "拉取历史记录失败")) as HistoryListResponse;
	const rawRecords = decoded.records || [];

	return rawRecords.map((r) => ({
		id: r.id,
		timestamp: (r.created_at || "").replace("T", " "),
		rawText: r.raw_text || "",
		summary: r.summary?.summary || "",
		actionItems: r.summary?.action_items || [],
		keyInsights: r.summary?.key_insights || [],
		calendarEvents: r.summary?.calendar_events || [],
		status: "done" as const,
		folder: r.archived ? ("archive" as const) : ("inbox" as const),
	}));
}

// 拉取当前账号的订阅状态；只做恢复，返回 false 时调用方不应吊销本地已有的会员状态
export async function fetchSubscription(): Promise<boolean> {
	const sessionToken = getSessionToken();
	if (!sessionToken) return false;
	try {
		const decoded = (await getJsonAuthed("/api/subscription", sessionToken, "拉取订阅状态失败")) as SubscriptionResponse;
		if (decoded.subscribed !== true) return false;
		const expiresAt = decoded.expires_at;
		return !expiresAt || new Date(expiresAt) > new Date();
	} catch {
		return false;
	}
}
