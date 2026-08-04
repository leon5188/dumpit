// 🌐 动态计算后端基准 API URL，优先使用用户配置的自定义基准地址，兼容本地/局域网及 HTTPS 部署
export function getBackendUrl(path: string): string {
	if (typeof window !== "undefined") {
		const savedUrl = localStorage.getItem("dumpit_backend_url");
		if (savedUrl) {
			const cleanBase = savedUrl.endsWith("/") ? savedUrl.slice(0, -1) : savedUrl;
			return `${cleanBase}${path}`;
		}
	}
	const defaultEnvUrl = process.env.NEXT_PUBLIC_API_URL;
	if (defaultEnvUrl) {
		const cleanEnv = defaultEnvUrl.endsWith("/") ? defaultEnvUrl.slice(0, -1) : defaultEnvUrl;
		return `${cleanEnv}${path}`;
	}
	if (typeof window === "undefined") return `http://localhost:8080${path}`;
	if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
		return `http://localhost:8080${path}`;
	}
	const protocol = window.location.protocol;
	const hostname = window.location.hostname;
	return `${protocol}//${hostname}:8080${path}`;
}

async function parseJsonOrThrow(res: Response, defaultErrorMsg: string): Promise<any> {
	const decoded = await res.json();
	if (res.ok) return decoded;
	throw new Error(decoded.error || defaultErrorMsg);
}

export async function postJson(path: string, body: unknown, defaultErrorMsg: string): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}

export async function postJsonAuthed(
	path: string,
	body: unknown,
	sessionToken: string,
	defaultErrorMsg: string
): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Authorization: `Bearer ${sessionToken}`,
		},
		body: JSON.stringify(body),
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}

export async function getJsonAuthed(path: string, sessionToken: string, defaultErrorMsg: string): Promise<any> {
	const res = await fetch(getBackendUrl(path), {
		headers: { Authorization: `Bearer ${sessionToken}` },
	});
	return parseJsonOrThrow(res, defaultErrorMsg);
}
