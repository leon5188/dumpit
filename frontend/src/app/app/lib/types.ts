import { CalendarEvent } from "../locales";

export interface HistoryRecord {
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
