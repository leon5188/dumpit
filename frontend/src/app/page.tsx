"use client";

import React, { useState } from "react";
import Link from "next/link";

export default function LandingPage() {
	const [billingPeriod, setBillingPeriod] = useState<"monthly" | "annually">("monthly");

	return (
		<div style={styles.container}>
			{/* 🪐 顶部导航栏 */}
			<header style={styles.header}>
				<div style={styles.logoContainer}>
					<img src="/logo.jpg" alt="BrainVent. Logo" style={styles.logoImg} />
					<span style={styles.logoText}>BrainVent.</span>
				</div>
				<nav style={styles.nav}>
					<a href="#features" style={styles.navLink}>Features</a>
					<a href="#how-it-works" style={styles.navLink}>How it Works</a>
					<a href="#pricing" style={styles.navLink}>Pricing</a>
				</nav>
				<Link href="/app" style={styles.btnLaunch}>
					Launch App
				</Link>
			</header>

			{/* 🌌 首屏 Hero Section (大发光渐变) */}
			<section style={styles.hero}>
				<div style={styles.glow1}></div>
				<div style={styles.glow2}></div>

				<div style={styles.heroContent}>
					<div style={styles.tagLine}>⚡ FOR ADHD, CREATORS & OVERTHINKERS</div>
					<h1 style={styles.heroTitle}>
						Jot Down Chaos.<br />
						Let AI <span style={styles.gradientText}>Restructure Your Mind</span>.
					</h1>
					<p style={styles.heroSubtitle}>
						Open your mic, dump everything out. No filters, no edits. AI filters out the filler words, structures your thoughts, and syncs to Notion in 1-click.
					</p>

					<div style={styles.heroActions}>
						<Link href="/app" style={styles.btnPrimary}>
							Start Dumping Free
						</Link>
						<a href="#pricing" style={styles.btnSecondary}>
							View Plans
						</a>
					</div>
				</div>

				{/* 🚀 互动控制台预览 (极简霓虹) */}
				<div style={styles.consolePreview}>
					<div style={styles.previewHeader}>
						<div style={styles.previewDotRed}></div>
						<div style={styles.previewDotYellow}></div>
						<div style={styles.previewDotGreen}></div>
						<span style={styles.previewTitle}>BrainVent. Dashboard Preview</span>
					</div>
					<div style={styles.previewBody}>
						<div style={styles.previewRow}>
							<span style={styles.previewLabel}>🧠 Mind Clutter Index:</span>
							<span style={styles.previewValueGlow}>24.50% restored</span>
						</div>
						<div style={styles.previewChart}>
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
						<div style={styles.demoContainer}>
							<div style={styles.demoBox}>
								<div style={styles.demoHeader}>🎤 YOUR VOICE (MESSY & DUMPED)</div>
								<div style={styles.demoTextRaw}>
									"So, uh, we need to like... design a new logo by Friday... and oh, don't forget to email Sarah about the pricing update."
								</div>
							</div>
							<div style={styles.demoArrow}>⬇️</div>
							<div style={styles.demoBoxActive}>
								<div style={styles.demoHeaderActive}>⚡ AUTO-STRUCTURED (NOTION SYNCED)</div>
								<div style={styles.demoTextStructured}>
									<strong>Action Items:</strong>
									<ul style={{ margin: "5px 0 0 15px", padding: 0, fontSize: "0.8rem", color: "#A7F3D0" }}>
										<li>🎯 Design a new logo (Deadline: Friday)</li>
										<li>✉️ Email Sarah re: pricing update</li>
									</ul>
								</div>
							</div>
						</div>

						<div style={styles.previewButtons}>
							<div style={styles.previewBtn}>🎤 Click to Dump</div>
							<div style={styles.previewBtnActive}>⚡ 1-Click Sync Notion</div>
						</div>
					</div>
				</div>
			</section>

			{/* 💡 核心卖点 Features Section */}
			<section id="features" style={styles.features}>
				<h2 style={styles.sectionTitle}>Built for ADHD & Fast Thinkers</h2>
				<div style={styles.featureGrid}>
					<div style={styles.featureCard}>
						<div style={styles.featureIcon}>🎤</div>
						<h3 style={styles.featureTitle}>Zero-Barrier Voice Capture</h3>
						<p style={styles.featureDesc}>
							Skip blank-page procrastination. Open the mic, talk naturally with stutters. AI auto-removes filler words ("ums", "likes") and instantly structures your stream of consciousness.
						</p>
					</div>
					<div style={styles.featureCard}>
						<div style={styles.featureIcon}>✍️</div>
						<h3 style={styles.featureTitle}>Keeps Your Voice (Tone Cloning)</h3>
						<p style={styles.featureDesc}>
							AI learns how you speak and write, so the structured output still sounds like you—just clearer.
						</p>
					</div>
					<div style={styles.featureCard}>
						<div style={styles.featureIcon}>🕸️</div>
						<h3 style={styles.featureTitle}>Interactive Mind Web</h3>
						<p style={styles.featureDesc}>
							Watch your scattered ideas automatically link together into an interactive, draggable neon node web. Understand your thought paths in 3D.
						</p>
					</div>
				</div>
			</section>

			{/* 💸 商业收费定价板 Pricing Section */}
			<section id="pricing" style={styles.pricing}>
				<div style={styles.glow3}></div>
				<h2 style={styles.sectionTitle}>SaaS Pricing for Every Brain</h2>
				<p style={styles.sectionSubtitle}>Start organizing your mind today. Unlock Notion automation.</p>

				{/* 周期切换按钮 */}
				<div style={styles.billingToggle}>
					<button
						style={billingPeriod === "monthly" ? styles.toggleActive : styles.toggleInactive}
						onClick={() => setBillingPeriod("monthly")}
					>
						Monthly
					</button>
					<button
						style={billingPeriod === "annually" ? styles.toggleActive : styles.toggleInactive}
						onClick={() => setBillingPeriod("annually")}
					>
						Annually (Save 33%)
					</button>
				</div>

				<div style={styles.pricingGrid}>
					{/* 免费计划 */}
					<div style={styles.priceCard}>
						<h3 style={styles.pricePlanTitle}>Starter Core</h3>
						<div style={styles.priceValue}>$0</div>
						<p style={styles.priceTerm}>Forever Free</p>
						<ul style={styles.priceFeatures}>
							<li>🧠 Neon Brainwave Dashboard</li>
							<li>🕸️ Drag & Drop Mind Web</li>
							<li>📋 Local Action Items Tasklist</li>
							<li>⏳ Max 3 AI Dumps / week</li>
							<li style={styles.disabledFeature}>🚫 Notion 1-Click Sync</li>
							<li style={styles.disabledFeature}>🚫 iCloud Multi-Device Backup</li>
						</ul>
						<Link href="/app" style={styles.btnPriceSecondary}>
							Get Started Free
						</Link>
					</div>

					{/* 黄金会员计划 (发光主推) */}
					<div style={styles.priceCardGlow}>
						<div style={styles.badgePopular}>MOST POPULAR</div>
						<h3 style={styles.pricePlanTitleGlow}>Premium Mind</h3>
						<div style={styles.priceValue}>
							{billingPeriod === "monthly" ? "$4.99" : "$3.29"}
							<span style={{ fontSize: "1rem", color: "rgba(255,255,255,0.4)" }}> / mo</span>
						</div>
						<p style={styles.priceTermGlow}>
							{billingPeriod === "monthly" ? "Billed monthly" : "Billed annually ($39.99/yr)"}
						</p>
						<ul style={styles.priceFeatures}>
							<li style={{ color: "#E0E7FF" }}>🚀 **Unlimited** AI Tone-Cloned Dumps</li>
							<li style={{ color: "#FBBF24", fontWeight: "bold" }}>⚡ Notion 1-Click Sync Automation</li>
							<li>🕸️ Advanced Draggable Thought Maps</li>
							<li>📅 Linear Timeline Schedule Generation</li>
							<li>☁️ iCloud / Multi-Device Cloud Backup</li>
							<li>👑 Priority API Processing Speed</li>
						</ul>
						<Link href="/app" style={styles.btnPricePrimary}>
							Upgrade to Premium
						</Link>
					</div>

					{/* 终身买断计划 */}
					<div style={styles.priceCard}>
						<h3 style={styles.pricePlanTitle}>Lifetime Vault</h3>
						<div style={styles.priceValue}>$59.99</div>
						<p style={styles.priceTerm}>Pay once, own forever</p>
						<ul style={styles.priceFeatures}>
							<li>♾️ All Premium Mind Privileges Forever</li>
							<li>📦 Lifetime Updates & No Subscriptions</li>
							<li>🎨 Exclusive Premium Dashboard Colors</li>
							<li>🎁 Free Notion Master Brain Template</li>
							<li>🔑 Direct OpenAI API Key Integration Option</li>
						</ul>
						<Link href="/app" style={styles.btnPriceSecondary}>
							Buy Lifetime Access
						</Link>
					</div>
				</div>
			</section>

			{/* 🪐 Footer */}
			<footer style={styles.footer}>
				<p>© 2026 BrainVent. All rights reserved. Built for productive minds.</p>
			</footer>
		</div>
	);
}

// 🎨 极致奢华暗黑渐变霓虹行联样式 (Pure Vanilla Inline CSS)
const styles = {
	container: {
		backgroundColor: "#05050A",
		color: "#FFFFFF",
		minHeight: "100vh",
		fontFamily: "Inter, system-ui, sans-serif",
		overflowX: "hidden" as const,
		position: "relative" as const,
	},
	header: {
		display: "flex",
		justifyContent: "space-between",
		alignItems: "center",
		padding: "1.5rem 2rem",
		borderBottom: "1px solid rgba(255, 255, 255, 0.05)",
		backdropFilter: "blur(10px)",
		position: "sticky" as const,
		top: 0,
		zIndex: 100,
	},
	logoContainer: {
		display: "flex",
		alignItems: "center",
		gap: "0.6rem",
	},
	logoImg: {
		width: "30px",
		height: "30px",
		borderRadius: "8px",
		border: "1.5px solid #8B5CF6",
	},
	logoText: {
		fontSize: "1.3rem",
		fontWeight: "bold",
		letterSpacing: "1px",
		background: "linear-gradient(90deg, #8B5CF6 0%, #EC4899 100%)",
		WebkitBackgroundClip: "text",
		WebkitTextFillColor: "transparent",
	},
	nav: {
		display: "flex",
		gap: "2.5rem",
	},
	navLink: {
		color: "rgba(255, 255, 255, 0.6)",
		textDecoration: "none",
		fontSize: "0.95rem",
		fontWeight: "500",
		transition: "color 0.2s",
	},
	btnLaunch: {
		background: "rgba(255, 255, 255, 0.05)",
		border: "1px solid rgba(255, 255, 255, 0.1)",
		color: "#FFF",
		padding: "0.6rem 1.2rem",
		borderRadius: "10px",
		textDecoration: "none",
		fontWeight: "bold",
		fontSize: "0.9rem",
		transition: "all 0.2s",
	},
	hero: {
		display: "flex",
		flexDirection: "column" as const,
		alignItems: "center",
		justifyContent: "center",
		textAlign: "center" as const,
		padding: "6rem 2rem 4rem 2rem",
		position: "relative" as const,
		maxWidth: "1000px",
		margin: "0 auto",
	},
	glow1: {
		position: "absolute" as const,
		width: "400px",
		height: "400px",
		background: "radial-gradient(circle, rgba(139, 92, 246, 0.15) 0%, rgba(0,0,0,0) 70%)",
		top: "10%",
		left: "-10%",
		zIndex: 0,
		pointerEvents: "none" as const,
	},
	glow2: {
		position: "absolute" as const,
		width: "450px",
		height: "450px",
		background: "radial-gradient(circle, rgba(236, 72, 153, 0.15) 0%, rgba(0,0,0,0) 70%)",
		bottom: "10%",
		right: "-10%",
		zIndex: 0,
		pointerEvents: "none" as const,
	},
	heroContent: {
		zIndex: 1,
		position: "relative" as const,
		maxWidth: "800px",
	},
	tagLine: {
		fontSize: "0.8rem",
		letterSpacing: "2.5px",
		color: "#8B5CF6",
		fontWeight: "bold",
		marginBottom: "1rem",
	},
	heroTitle: {
		fontSize: "3.5rem",
		fontWeight: "800",
		lineHeight: "1.25",
		letterSpacing: "-1px",
		marginBottom: "1.5rem",
	},
	gradientText: {
		background: "linear-gradient(90deg, #8B5CF6 0%, #EC4899 100%)",
		WebkitBackgroundClip: "text",
		WebkitTextFillColor: "transparent",
	},
	heroSubtitle: {
		fontSize: "1.2rem",
		color: "rgba(255,255,255,0.6)",
		lineHeight: "1.7",
		maxWidth: "600px",
		margin: "0 auto 2.5rem auto",
	},
	heroActions: {
		display: "flex",
		gap: "1.2rem",
		justifyContent: "center",
		marginBottom: "4rem",
	},
	btnPrimary: {
		background: "linear-gradient(90deg, #8B5CF6 0%, #EC4899 100%)",
		boxShadow: "0 4px 15px rgba(139, 92, 246, 0.4)",
		color: "#FFF",
		padding: "0.9rem 1.8rem",
		borderRadius: "12px",
		textDecoration: "none",
		fontWeight: "bold",
		fontSize: "1rem",
	},
	btnSecondary: {
		background: "rgba(255, 255, 255, 0.03)",
		border: "1px solid rgba(255, 255, 255, 0.08)",
		color: "rgba(255,255,255,0.8)",
		padding: "0.9rem 1.8rem",
		borderRadius: "12px",
		textDecoration: "none",
		fontWeight: "bold",
		fontSize: "1rem",
	},
	consolePreview: {
		width: "100%",
		maxWidth: "500px",
		background: "#12131F",
		borderRadius: "16px",
		border: "1px solid rgba(255,255,255,0.06)",
		boxShadow: "0 20px 40px rgba(0,0,0,0.5)",
		overflow: "hidden",
		zIndex: 1,
	},
	previewHeader: {
		display: "flex",
		alignItems: "center",
		padding: "0.8rem 1rem",
		background: "#181928",
		borderBottom: "1px solid rgba(255,255,255,0.04)",
	},
	previewDotRed: { width: "10px", height: "10px", borderRadius: "50%", background: "#EF4444", marginRight: "6px" },
	previewDotYellow: { width: "10px", height: "10px", borderRadius: "50%", background: "#F59E0B", marginRight: "6px" },
	previewDotGreen: { width: "10px", height: "10px", borderRadius: "50%", background: "#10B981", marginRight: "12px" },
	previewTitle: { fontSize: "0.75rem", color: "rgba(255,255,255,0.4)", fontWeight: "500" },
	previewBody: {
		padding: "1.5rem",
		textAlign: "left" as const,
	},
	previewRow: {
		display: "flex",
		justifyContent: "space-between",
		marginBottom: "1rem",
	},
	previewLabel: { color: "rgba(255,255,255,0.4)", fontSize: "0.85rem" },
	previewValueGlow: { color: "#10B981", fontSize: "0.85rem", fontWeight: "bold", textShadow: "0 0 8px rgba(16,185,129,0.3)" },
	previewChart: {
		margin: "1.5rem 0",
	},
	previewButtons: {
		display: "flex",
		gap: "0.8rem",
	},
	previewBtn: {
		flex: 1,
		background: "rgba(255,255,255,0.02)",
		border: "1px solid rgba(255,255,255,0.04)",
		color: "rgba(255,255,255,0.6)",
		padding: "0.6rem",
		borderRadius: "8px",
		textAlign: "center" as const,
		fontSize: "0.75rem",
		fontWeight: "bold",
	},
	previewBtnActive: {
		flex: 1,
		background: "rgba(251,191,36,0.06)",
		border: "1px solid rgba(251,191,36,0.3)",
		color: "#FBBF24",
		padding: "0.6rem",
		borderRadius: "8px",
		textAlign: "center" as const,
		fontSize: "0.75rem",
		fontWeight: "bold",
	},
	demoContainer: {
		display: "flex",
		flexDirection: "column" as const,
		gap: "0.8rem",
		margin: "1rem 0 1.5rem 0",
	},
	demoBox: {
		background: "rgba(255, 255, 255, 0.02)",
		border: "1px solid rgba(255, 255, 255, 0.05)",
		borderRadius: "8px",
		padding: "0.8rem",
	},
	demoHeader: {
		fontSize: "0.7rem",
		color: "rgba(255, 255, 255, 0.4)",
		fontWeight: "bold",
		marginBottom: "0.4rem",
		letterSpacing: "0.5px",
	},
	demoTextRaw: {
		fontSize: "0.8rem",
		color: "rgba(255, 255, 255, 0.7)",
		lineHeight: "1.4",
		fontStyle: "italic",
	},
	demoArrow: {
		textAlign: "center" as const,
		color: "#8B5CF6",
		fontSize: "1rem",
		margin: "-0.2rem 0",
	},
	demoBoxActive: {
		background: "rgba(16, 185, 129, 0.03)",
		border: "1px solid rgba(16, 185, 129, 0.2)",
		borderRadius: "8px",
		padding: "0.8rem",
	},
	demoHeaderActive: {
		fontSize: "0.7rem",
		color: "#10B981",
		fontWeight: "bold",
		marginBottom: "0.4rem",
		letterSpacing: "0.5px",
	},
	demoTextStructured: {
		fontSize: "0.8rem",
		color: "#E0E7FF",
		lineHeight: "1.4",
	},
	features: {
		padding: "6rem 2rem",
		background: "#080912",
		borderTop: "1px solid rgba(255,255,255,0.03)",
		borderBottom: "1px solid rgba(255,255,255,0.03)",
		textAlign: "center" as const,
	},
	sectionTitle: {
		fontSize: "2.2rem",
		fontWeight: "800",
		marginBottom: "2.5rem",
	},
	sectionSubtitle: {
		fontSize: "1.1rem",
		color: "rgba(255,255,255,0.5)",
		marginTop: "-1.5rem",
		marginBottom: "3rem",
	},
	featureGrid: {
		display: "flex",
		gap: "2rem",
		justifyContent: "center",
		maxWidth: "1000px",
		margin: "0 auto",
		flexWrap: "wrap" as const,
	},
	featureCard: {
		flex: 1,
		minWidth: "280px",
		background: "#12131F",
		padding: "2rem",
		borderRadius: "16px",
		border: "1px solid rgba(255,255,255,0.04)",
		textAlign: "left" as const,
	},
	featureIcon: {
		fontSize: "2rem",
		marginBottom: "1.2rem",
	},
	featureTitle: {
		fontSize: "1.25rem",
		fontWeight: "bold",
		marginBottom: "0.8rem",
	},
	featureDesc: {
		fontSize: "0.9rem",
		color: "rgba(255,255,255,0.5)",
		lineHeight: "1.6",
	},
	pricing: {
		padding: "7rem 2rem",
		textAlign: "center" as const,
		position: "relative" as const,
		maxWidth: "1100px",
		margin: "0 auto",
	},
	glow3: {
		position: "absolute" as const,
		width: "500px",
		height: "500px",
		background: "radial-gradient(circle, rgba(139, 92, 246, 0.12) 0%, rgba(0,0,0,0) 70%)",
		top: "20%",
		left: "25%",
		zIndex: 0,
		pointerEvents: "none" as const,
	},
	billingToggle: {
		display: "inline-flex",
		background: "rgba(255,255,255,0.03)",
		border: "1px solid rgba(255,255,255,0.05)",
		padding: "4px",
		borderRadius: "10px",
		marginBottom: "3rem",
		zIndex: 1,
		position: "relative" as const,
	},
	toggleActive: {
		background: "#8B5CF6",
		border: "none",
		color: "#FFF",
		padding: "0.5rem 1.2rem",
		borderRadius: "8px",
		fontWeight: "bold",
		fontSize: "0.85rem",
		cursor: "pointer",
	},
	toggleInactive: {
		background: "transparent",
		border: "none",
		color: "rgba(255,255,255,0.6)",
		padding: "0.5rem 1.2rem",
		borderRadius: "8px",
		fontWeight: "bold",
		fontSize: "0.85rem",
		cursor: "pointer",
	},
	pricingGrid: {
		display: "flex",
		gap: "2rem",
		justifyContent: "center",
		alignItems: "stretch",
		flexWrap: "wrap" as const,
		zIndex: 1,
		position: "relative" as const,
	},
	priceCard: {
		flex: 1,
		minWidth: "290px",
		background: "#12131F",
		border: "1px solid rgba(255,255,255,0.04)",
		borderRadius: "20px",
		padding: "2.5rem 2rem",
		display: "flex",
		flexDirection: "column" as const,
		textAlign: "left" as const,
	},
	priceCardGlow: {
		flex: 1,
		minWidth: "290px",
		background: "#18192C",
		border: "2px solid #8B5CF6",
		boxShadow: "0 10px 30px rgba(139, 92, 246, 0.25)",
		borderRadius: "20px",
		padding: "2.5rem 2rem",
		display: "flex",
		flexDirection: "column" as const,
		textAlign: "left" as const,
		position: "relative" as const,
	},
	badgePopular: {
		position: "absolute" as const,
		top: "-12px",
		left: "50%",
		transform: "translateX(-50%)",
		background: "linear-gradient(90deg, #8B5CF6 0%, #EC4899 100%)",
		color: "#FFF",
		padding: "4px 12px",
		borderRadius: "20px",
		fontSize: "0.7rem",
		fontWeight: "bold",
		letterSpacing: "1px",
	},
	pricePlanTitle: {
		fontSize: "1.1rem",
		fontWeight: "bold",
		color: "rgba(255,255,255,0.7)",
		marginBottom: "1rem",
	},
	pricePlanTitleGlow: {
		fontSize: "1.2rem",
		fontWeight: "bold",
		color: "#E0E7FF",
		marginBottom: "1rem",
	},
	priceValue: {
		fontSize: "2.5rem",
		fontWeight: "800",
		marginBottom: "0.3rem",
	},
	priceTerm: {
		fontSize: "0.85rem",
		color: "rgba(255,255,255,0.4)",
		marginBottom: "2rem",
	},
	priceTermGlow: {
		fontSize: "0.85rem",
		color: "rgba(255,255,255,0.5)",
		marginBottom: "2rem",
	},
	priceFeatures: {
		listStyleType: "none",
		padding: 0,
		margin: "0 0 2.5rem 0",
		display: "flex",
		flexDirection: "column" as const,
		gap: "0.8rem",
		fontSize: "0.9rem",
		color: "rgba(255,255,255,0.65)",
	},
	disabledFeature: {
		color: "rgba(255,255,255,0.25)",
		textDecoration: "line-through",
	},
	btnPricePrimary: {
		background: "linear-gradient(90deg, #8B5CF6 0%, #EC4899 100%)",
		color: "#FFF",
		textAlign: "center" as const,
		padding: "0.8rem",
		borderRadius: "10px",
		textDecoration: "none",
		fontWeight: "bold",
		fontSize: "0.95rem",
		marginTop: "auto",
	},
	btnPriceSecondary: {
		background: "rgba(255, 255, 255, 0.03)",
		border: "1px solid rgba(255, 255, 255, 0.08)",
		color: "rgba(255,255,255,0.8)",
		textAlign: "center" as const,
		padding: "0.8rem",
		borderRadius: "10px",
		textDecoration: "none",
		fontWeight: "bold",
		fontSize: "0.95rem",
		marginTop: "auto",
	},
	footer: {
		padding: "3rem 2rem",
		textAlign: "center" as const,
		fontSize: "0.85rem",
		color: "rgba(255,255,255,0.3)",
		borderTop: "1px solid rgba(255,255,255,0.05)",
		background: "#05050A",
	},
};
