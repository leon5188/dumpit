"use client";

import React, { useState, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import styles from "./page.module.css";

const APP_STORE_URL = "https://apps.apple.com/app/id6791209882";

const AppStoreBadge = () => (
	<a
		href={APP_STORE_URL}
		className={styles.appStoreBadge}
		target="_blank"
		rel="noopener noreferrer"
	>
		<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true">
			<path fill="currentColor" d="M16.365 1.43c0 1.14-.46 2.2-1.2 2.98-.86.9-2.27 1.6-3.43 1.51-.14-1.1.43-2.27 1.1-3 .77-.83 2.16-1.46 3.27-1.49.07.33.1.66.26.99zM20.5 17.2c-.55 1.27-.82 1.84-1.53 2.96-.99 1.57-2.39 3.52-4.12 3.53-1.54.02-1.94-1-4.03-.99-2.09.01-2.53 1.01-4.07.99-1.73-.02-3.05-1.78-4.04-3.35C-.02 16.6-.36 11.3 1.36 8.6 2.45 6.7 4.28 5.55 6.04 5.55c1.83 0 2.98 1 4.49 1 1.45 0 2.34-1 4.43-1 1.58 0 3.26.86 4.46 2.34-3.92 2.15-3.29 7.74.68 9.31z" />
		</svg>
		<span className={styles.badgeText}>
			<small>Download on the</small>
			<strong>App Store</strong>
		</span>
	</a>
);

export default function LandingPage() {
	const [billingPeriod, setBillingPeriod] = useState<"monthly" | "annually">("monthly");

	// 设备感知：移动流量（尤其 TikTok/Reels 导来的 iOS 用户）直接给商店入口
	// 用惰性初始化在首次渲染时判定，避免 effect 内同步 setState 触发级联渲染
	// 支持 ?force=ios|android|other 调试预览（桌面也能看各分支）
	const [device] = useState<"ios" | "android" | "other">(() => {
		if (typeof window === "undefined") return "other";
		const params = new URLSearchParams(window.location.search);
		const force = params.get("force");
		if (force === "ios" || force === "android" || force === "other") return force;
		const ua = navigator.userAgent || "";
		if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
		if (/Android/i.test(ua)) return "android";
		return "other";
	});
	const [waitlistEmail, setWaitlistEmail] = useState("");
	const [waitlistDone, setWaitlistDone] = useState(false);

	const handleWaitlist = (e: React.FormEvent) => {
		e.preventDefault();
		if (!waitlistEmail) return;
		try {
			const existing = JSON.parse(localStorage.getItem("dumpit_android_waitlist") || "[]");
			if (!existing.includes(waitlistEmail)) existing.push(waitlistEmail);
			localStorage.setItem("dumpit_android_waitlist", JSON.stringify(existing));
		} catch {
			/* localStorage 不可用时静默降级 */
		}
		setWaitlistDone(true);
	};

	// 管理员导出候补名单：访问 /?export=android 即把 localStorage 名单打到页面
	useEffect(() => {
		try {
			const params = new URLSearchParams(window.location.search);
			if (params.get("export") === "android") {
				const list = JSON.parse(localStorage.getItem("dumpit_android_waitlist") || "[]");
				console.log("ANDROID_WAITLIST:", JSON.stringify(list, null, 2));
			}
		} catch {
			/* ignore */
		}
	}, []);

	return (
		<div className={styles.container}>
			{/* 🪐 顶部导航栏 */}
			<header className={styles.header}>
				<div className={styles.logoContainer}>
					<Image src="/logo.jpg" alt="BrainVent. Logo" width={30} height={30} className={styles.logoImg} />
					<span className={styles.logoText}>BrainVent.</span>
				</div>
				<nav className={styles.nav}>
					<a href="#features" className={styles.navLink}>Features</a>
					<a href="#how-it-works" className={styles.navLink}>How it Works</a>
					<a href="#pricing" className={styles.navLink}>Pricing</a>
				</nav>
				<Link href="/app" className={styles.btnLaunch}>
					Launch App
				</Link>
			</header>

			{/* 🌌 首屏 Hero Section (大发光渐变) */}
			<section className={styles.hero}>
				<div className={styles.glow1}></div>
				<div className={styles.glow2}></div>

				<div className={styles.heroContent}>
					<div className={styles.tagLine}>⚡ FOR ADHD, CREATORS & OVERTHINKERS</div>
					<h1 className={styles.heroTitle}>
						Jot Down Chaos.<br />
						Let AI <span className={styles.gradientText}>Restructure Your Mind</span>.
					</h1>
					<p className={styles.heroSubtitle}>
						Open your mic, dump everything out. No filters, no edits. AI structures your messy voice into a clean summary, action list, and insights — in your own tone. Free to start.
					</p>

					<div className={styles.heroActions}>
						{/* App Store 徽章桌面也常驻显示（iOS + desktop），仅安卓分支让位给候补名单 */}
						{device !== "android" && (
							<AppStoreBadge />
						)}
						{device === "android" && (
							<div className={styles.androidWaitlist}>
								{waitlistDone ? (
									<div className={styles.waitlistDone}>✅ You&apos;re on the list. Android launch is coming soon.</div>
								) : (
									<form onSubmit={handleWaitlist} className={styles.waitlistForm}>
										<input
											type="email"
											required
											placeholder="you@email.com"
											value={waitlistEmail}
											onChange={(e) => setWaitlistEmail(e.target.value)}
											className={styles.waitlistInput}
											aria-label="Email for Android early access"
										/>
										<button type="submit" className={styles.btnPrimary}>
											Notify Me
										</button>
									</form>
								)}
								<p className={styles.waitlistHint}>BrainVent for Android — get early access.</p>
							</div>
						)}
						{device === "other" && (
							<>
								<Link href="/app" className={styles.btnPrimary}>
									Start Dumping Free
								</Link>
								<a href="#pricing" className={styles.btnSecondary}>
									View Plans
								</a>
							</>
						)}
					</div>

					{(device === "ios" || device === "android") && (
						<div className={styles.storeSubActions}>
							<Link href="/app" className={styles.btnSecondary}>
								Or use the Web App
							</Link>
						</div>
					)}
				</div>

				{/* 🚀 互动控制台预览 (极简霓虹) */}
				<div className={styles.consolePreview}>
					<div className={styles.previewHeader}>
						<div className={styles.previewDotRed}></div>
						<div className={styles.previewDotYellow}></div>
						<div className={styles.previewDotGreen}></div>
						<span className={styles.previewTitle}>BrainVent. Dashboard Preview</span>
					</div>
					<div className={styles.previewBody}>
						<div className={styles.previewRow}>
							<span className={styles.previewLabel}>🧠 Brain Load:</span>
							<span className={styles.previewValueGlow}>62% cluttered</span>
						</div>
						<div className={styles.brainBarTrack}>
							{/* 渐变轨道：红(满)→黄→绿(空) */}
							<div className={styles.brainBarMask}></div>
							<div className={styles.brainBarFill}></div>
							<div className={styles.brainBarGlow}></div>
						</div>
						<div className={styles.brainHint}>
							Dump a thought → brain drops 5–10% 💨
						</div>

						{/* Before & After Demo */}
						<div className={styles.demoContainer}>
							<div className={styles.demoBox}>
								<div className={styles.demoHeader}>🎤 YOUR VOICE (MESSY & DUMPED)</div>
								<div className={styles.demoTextRaw}>
									&quot;So, uh, we need to like... design a new logo by Friday... and oh, don&apos;t forget to email Sarah about the pricing update.&quot;
								</div>
							</div>
							<div className={styles.demoArrow}>⬇️</div>
							<div className={styles.demoBoxActive}>
								<div className={styles.demoHeaderActive}>⚡ AUTO-STRUCTURED (NOTION SYNCED)</div>
								<div className={styles.demoTextStructured}>
									<strong>Action Items:</strong>
									<ul style={{ margin: "5px 0 0 15px", padding: 0, fontSize: "0.8rem", color: "#A7F3D0" }}>
										<li>🎯 Design a new logo (Deadline: Friday)</li>
										<li>✉️ Email Sarah re: pricing update</li>
									</ul>
								</div>
							</div>
						</div>

						<div className={styles.previewButtons}>
							<div className={styles.previewBtn}>🎤 Click to Dump</div>
							<div className={styles.previewBtnActive}>⚡ 1-Click Sync Notion</div>
						</div>
					</div>
				</div>
			</section>

			{/* 💡 核心卖点 Features Section */}
			<section id="features" className={styles.features}>
				<h2 className={styles.sectionTitle}>Built for ADHD & Fast Thinkers</h2>
				<div className={styles.featureGrid}>
					<div className={styles.featureCard}>
						<div className={styles.featureIcon}>🎤</div>
						<h3 className={styles.featureTitle}>Zero-Barrier Voice Capture</h3>
						<p className={styles.featureDesc}>
							Skip blank-page procrastination. Open the mic, talk naturally with stutters. AI auto-removes filler words (&quot;ums&quot;, &quot;likes&quot;) and instantly structures your stream of consciousness.
						</p>
					</div>
					<div className={styles.featureCard}>
						<div className={styles.featureIcon}>✍️</div>
						<h3 className={styles.featureTitle}>Keeps Your Voice (Tone Cloning)</h3>
						<p className={styles.featureDesc}>
							AI learns how you speak and write, so the structured output still sounds like you—just clearer.
						</p>
					</div>
					<div className={styles.featureCard}>
						<div className={styles.featureIcon}>🕸️</div>
						<h3 className={styles.featureTitle}>Interactive Mind Web</h3>
						<p className={styles.featureDesc}>
							Watch your scattered ideas automatically link together into an interactive, draggable neon node web. Understand your thought paths in 3D.
						</p>
					</div>
				</div>
			</section>

			{/* 💸 商业收费定价板 Pricing Section */}
			<section id="pricing" className={styles.pricing}>
				<div className={styles.glow3}></div>
				<h2 className={styles.sectionTitle}>SaaS Pricing for Every Brain</h2>
				<p className={styles.sectionSubtitle}>Start organizing your mind today. Unlock Notion automation.</p>

				{/* 周期切换按钮 */}
				<div className={styles.billingToggle}>
					<button
						className={billingPeriod === "monthly" ? styles.toggleActive : styles.toggleInactive}
						onClick={() => setBillingPeriod("monthly")}
					>
						Monthly
					</button>
					<button
						className={billingPeriod === "annually" ? styles.toggleActive : styles.toggleInactive}
						onClick={() => setBillingPeriod("annually")}
					>
						Annually (Save 33%)
					</button>
				</div>

				<div className={styles.pricingGrid}>
					{/* 免费计划 */}
					<div className={styles.priceCard}>
						<h3 className={styles.pricePlanTitle}>Starter Core</h3>
						<div className={styles.priceValue}>$0</div>
						<p className={styles.priceTerm}>Forever Free</p>
						<ul className={styles.priceFeatures}>
							<li>🧠 Neon Brainwave Dashboard</li>
							<li>🕸️ Drag & Drop Mind Web</li>
							<li>📋 Local Action Items Tasklist</li>
							<li>⏳ Max 3 AI Dumps / week</li>
							<li className={styles.disabledFeature}>🚫 Notion 1-Click Sync</li>
							<li className={styles.disabledFeature}>🚫 iCloud Multi-Device Backup</li>
						</ul>
						<Link href="/app" className={styles.btnPriceSecondary}>
							Get Started Free
						</Link>
					</div>

					{/* 黄金会员计划 (发光主推) */}
					<div className={styles.priceCardGlow}>
						<div className={styles.badgePopular}>MOST POPULAR</div>
						<h3 className={styles.pricePlanTitleGlow}>Premium Mind</h3>
						<div className={styles.priceValue}>
							{billingPeriod === "monthly" ? "$4.99" : "$3.29"}
							<span style={{ fontSize: "1rem", color: "rgba(255,255,255,0.4)" }}> / mo</span>
						</div>
						<p className={styles.priceTermGlow}>
							{billingPeriod === "monthly" ? "Billed monthly" : "Billed annually ($39.99/yr)"}
						</p>
						<ul className={styles.priceFeatures}>
							<li style={{ color: "#E0E7FF" }}>🚀 **Unlimited** AI Tone-Cloned Dumps</li>
							<li style={{ color: "#FBBF24", fontWeight: "bold" }}>⚡ Notion 1-Click Sync Automation</li>
							<li>🕸️ Advanced Draggable Thought Maps</li>
							<li>📅 Linear Timeline Schedule Generation</li>
							<li>☁️ iCloud / Multi-Device Cloud Backup</li>
							<li>👑 Priority API Processing Speed</li>
						</ul>
						<Link href="/app" className={styles.btnPricePrimary}>
							Upgrade to Premium
						</Link>
					</div>

					{/* 终身买断计划 */}
					<div className={styles.priceCard}>
						<h3 className={styles.pricePlanTitle}>Lifetime Vault</h3>
						<div className={styles.priceValue}>$59.99</div>
						<p className={styles.priceTerm}>Pay once, own forever</p>
						<ul className={styles.priceFeatures}>
							<li>♾️ All Premium Mind Privileges Forever</li>
							<li>📦 Lifetime Updates & No Subscriptions</li>
							<li>🎨 Exclusive Premium Dashboard Colors</li>
							<li>🎁 Free Notion Master Brain Template</li>
							<li>🔑 Direct OpenAI API Key Integration Option</li>
						</ul>
						<Link href="/app" className={styles.btnPriceSecondary}>
							Buy Lifetime Access
						</Link>
					</div>
				</div>
			</section>

			{/* 🪐 Footer */}
			<footer className={styles.footer}>
				<p>© 2026 BrainVent. All rights reserved. Built for productive minds.</p>
			</footer>
		</div>
	);
}
