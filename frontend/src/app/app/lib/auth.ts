import {
	sendSignInLinkToEmail,
	isSignInWithEmailLink,
	signInWithEmailLink,
	signOut as firebaseSignOut,
} from "firebase/auth";
import { firebaseAuth } from "./firebase";
import { postJson } from "./api";

const SESSION_TOKEN_KEY = "dumpit_session_token";
const PENDING_EMAIL_KEY = "dumpit_pending_login_email";

export function getSessionToken(): string | null {
	if (typeof window === "undefined") return null;
	return localStorage.getItem(SESSION_TOKEN_KEY);
}

export function hasSessionToken(): boolean {
	return getSessionToken() !== null;
}

// 发送登录链接到邮箱；邮箱同时存本地，供同设备点击链接回跳时使用
export async function sendLoginLink(email: string): Promise<void> {
	const actionCodeSettings = {
		url: `${window.location.origin}/app`,
		handleCodeInApp: true,
	};
	await sendSignInLinkToEmail(firebaseAuth, email, actionCodeSettings);
	localStorage.setItem(PENDING_EMAIL_KEY, email);
}

// 检测当前 URL 是否是登录邮件里的链接；命中则完成登录并返回 true，不是则返回 false。
// 只支持同设备/同浏览器打开链接——本地找不到 pending email 时视为错误，不做跨设备补录邮箱的 UI。
export async function completeLoginLinkIfPresent(): Promise<boolean> {
	if (!isSignInWithEmailLink(firebaseAuth, window.location.href)) return false;

	const email = localStorage.getItem(PENDING_EMAIL_KEY);
	if (!email) {
		throw new Error("请在发送登录链接的同一浏览器中打开该链接");
	}

	const credential = await signInWithEmailLink(firebaseAuth, email, window.location.href);
	const idToken = await credential.user.getIdToken();

	const decoded = await postJson("/api/auth/verify", { id_token: idToken }, "登录验证失败");
	localStorage.setItem(SESSION_TOKEN_KEY, decoded.session_token as string);
	localStorage.removeItem(PENDING_EMAIL_KEY);

	window.history.replaceState({}, "", window.location.pathname);
	return true;
}

export async function logout(): Promise<void> {
	await firebaseSignOut(firebaseAuth);
	localStorage.removeItem(SESSION_TOKEN_KEY);
}
