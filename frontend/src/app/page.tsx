"use client";

import React, { useState } from "react";
import Link from "next/link";
import styles from "./page.module.css";

export default function LandingPage() {
	const [billingPeriod, setBillingPeriod] = useState<"monthly" | "annually">("monthly");

	return (
		<div className={styles.container}>
			{/* 🪐 顶部导航栏 */}
			<header className={styles.header}>
				<div className={styles.logoContainer}>
					<img src="/logo.jpg" alt="BrainVent. Logo" className={styles.logoImg} />
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
						Open your mic, dump everything out. No filters, no edits. AI filters out the filler words, structures your thoughts, and syncs to Notion in 1-click.
					</p>

					<div className={styles.heroActions}>
						<Link href="/app" className={styles.btnPrimary}>
							Start Dumping Free
						</Link>
						<a href="#pricing" className={styles.btnSecondary}>
							View Plans
						</a>
					</div>
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
							<span className={styles.previewLabel}>🧠 Mind Clutter Index:</span>
							<span className={styles.previewValueGlow}>24.50% restored</span>
						</div>
						<div className={styles.previewChart}>
							{/* Canvas 动态脑波线示意 */}
							<svg width="100%" height="60" style={{ overflow: "visible" }}>
								<path
									d="M0 30 C 50 10, 100 50, 150 20 C 200 10, 250 60, 300 30 C 350 15, 400 50, 450 30 L 500 30"
									fill="none"
									stroke="url(#neonGradient)"
									strokeWidth="3"
								/>
								<defs>
									<linearGradient id="neonGradient" x1="0%" y1="0%" x2="100%" y2="0%">
										<stop offset="0%" stopColor="#8B5CF6" />
										<stop offset="100%" stopColor="#EC4899" />
									</linearGradient>
								</defs>
							</svg>
						</div>

						{/* Before & After Demo */}
						<div className={styles.demoContainer}>
							<div className={styles.demoBox}>
								<div className={styles.demoHeader}>🎤 YOUR VOICE (MESSY & DUMPED)</div>
								<div className={styles.demoTextRaw}>
									"So, uh, we need to like... design a new logo by Friday... and oh, don't forget to email Sarah about the pricing update."
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
							Skip blank-page procrastination. Open the mic, talk naturally with stutters. AI auto-removes filler words ("ums", "likes") and instantly structures your stream of consciousness.
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
