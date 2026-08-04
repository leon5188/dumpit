// ADHD 减压反馈音效：oscillator 现场合成，不依赖音频文件/库。
// AudioContext 需要用户手势后才能起振，两个 play 函数只在点击回调里调用，天然满足这个限制。

let ctx: AudioContext | null = null;

function getCtx(): AudioContext | null {
	if (typeof window === "undefined") return null;
	const Ctor = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
	if (!Ctor) return null;
	if (!ctx) ctx = new Ctor();
	if (ctx.state === "suspended") void ctx.resume();
	return ctx;
}

function tone(freqStart: number, freqEnd: number, durationMs: number, gainPeak: number) {
	const audio = getCtx();
	if (!audio) return;

	const osc = audio.createOscillator();
	const gain = audio.createGain();
	osc.connect(gain);
	gain.connect(audio.destination);

	const now = audio.currentTime;
	const duration = durationMs / 1000;

	osc.type = "sine";
	osc.frequency.setValueAtTime(freqStart, now);
	osc.frequency.exponentialRampToValueAtTime(Math.max(freqEnd, 1), now + duration);

	gain.gain.setValueAtTime(0, now);
	gain.gain.linearRampToValueAtTime(gainPeak, now + 0.01);
	gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

	osc.start(now);
	osc.stop(now + duration);
}

// 想法被“吸走接管”音：高音滑向低音，配合吸入动画
export function playSuckSound() {
	tone(800, 200, 150, 0.15);
}

// 任务勾选“叮”音：干净短促
export function playChimeSound() {
	tone(1000, 1000, 80, 0.12);
}
