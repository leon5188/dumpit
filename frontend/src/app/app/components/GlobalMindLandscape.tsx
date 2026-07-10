"use client";

import React, { useState, useEffect, useRef } from "react";

interface CalendarEvent {
	title: string;
	time: string;
}

interface HistoryRecord {
	id: string;
	timestamp: string;
	rawText: string;
	summary: string;
	actionItems: string[];
	keyInsights: string[];
	calendarEvents: CalendarEvent[];
	folder?: "inbox" | "archive" | "trash";
}

interface Node {
	id: string;
	label: string;
	type: "record" | "insight" | "todo";
	x: number;
	y: number;
	vx: number;
	vy: number;
	fx?: number;
	fy?: number;
	radius: number;
	glowColor: string;
	parentRecordId?: string;
}

interface Edge {
	source: string;
	target: string;
	isSemantic: boolean; // 是否是跨文本的语义重合虚线连接
}

interface GlobalMindLandscapeProps {
	historyList: HistoryRecord[];
	isZh: boolean;
	onClose: () => void;
}

export default function GlobalMindLandscape({ historyList, isZh, onClose }: GlobalMindLandscapeProps) {
	const svgRef = useRef<SVGSVGElement | null>(null);
	const [nodes, setNodes] = useState<Node[]>([]);
	const [edges, setEdges] = useState<Edge[]>([]);

	// 缩放与拖拽状态
	const [transform, setTransform] = useState({ x: 0, y: 0, scale: 1 });
	const [draggedNodeId, setDraggedNodeId] = useState<string | null>(null);
	const [isPanning, setIsPanning] = useState(false);
	const panStart = useRef({ x: 0, y: 0 });

	// 力学控制滑块
	const [linkDistance, setLinkDistance] = useState(120);
	const [repulsionStrength, setRepulsionStrength] = useState(800);

	// 1. 初始化图结构（节点与边）
	useEffect(() => {
		const validRecords = historyList.filter((r) => r.folder !== "trash");
		if (validRecords.length === 0) return;

		const tempNodes: Node[] = [];
		const tempEdges: Edge[] = [];
		const nodeMap = new Map<string, boolean>();

		const centerX = 400;
		const centerY = 300;

		// 助手函数：检测中文常见停用词，提取粗颗粒关键词
		const extractKeywords = (text: string): string[] => {
			const clean = text.replace(/[.,\/#!$%\^&\*;:{}=\-_`~()？。，！；：“”']/g, " ");
			const words = clean.split(/\s+/);
			return words.filter((w) => w.length >= 2 && !["的", "了", "和", "是", "就", "都", "而", "及", "与"].includes(w));
		};

		// 记录每条记录所包含的名词/关键词，用于计算跨文本的连线
		const recordKeywordsMap = new Map<string, string[]>();

		validRecords.forEach((record, index) => {
			const recordNodeId = `rec_${record.id}`;
			const angle = (index / validRecords.length) * Math.PI * 2;
			const radius = 200;

			// A. 添加 Record 主节点
			const rNode: Node = {
				id: recordNodeId,
				label: record.summary.slice(0, 16) + "...",
				type: "record",
				x: centerX + Math.cos(angle) * radius + (Math.random() - 0.5) * 50,
				y: centerY + Math.sin(angle) * radius + (Math.random() - 0.5) * 50,
				vx: 0,
				vy: 0,
				radius: 24,
				glowColor: "rgba(139, 92, 246, 0.8)", // 深紫发光
			};
			tempNodes.push(rNode);
			nodeMap.set(recordNodeId, true);

			// 收集关键词用于文本重叠连线
			const allWords = extractKeywords(record.rawText + " " + record.summary);
			recordKeywordsMap.set(record.id, allWords);

			// B. 提取并添加 Insights 节点
			record.keyInsights.slice(0, 3).forEach((insight, insIdx) => {
				const insNodeId = `ins_${record.id}_${insIdx}`;
				const insNode: Node = {
					id: insNodeId,
					label: insight,
					type: "insight",
					x: rNode.x + Math.cos(insIdx * 1.5) * 60,
					y: rNode.y + Math.sin(insIdx * 1.5) * 60,
					vx: 0,
					vy: 0,
					radius: 12,
					glowColor: "rgba(236, 72, 153, 0.7)", // 玫瑰粉发光
					parentRecordId: record.id,
				};
				tempNodes.push(insNode);
				nodeMap.set(insNodeId, true);

				// 连线：Record -> Insight
				tempEdges.push({ source: recordNodeId, target: insNodeId, isSemantic: false });
			});

			// C. 提取并添加 Todos 节点
			record.actionItems.slice(0, 3).forEach((todo, todoIdx) => {
				const todoNodeId = `todo_${record.id}_${todoIdx}`;
				const todoNode: Node = {
					id: todoNodeId,
					label: todo,
					type: "todo",
					x: rNode.x + Math.cos(todoIdx * 1.5 + 2) * 60,
					y: rNode.y + Math.sin(todoIdx * 1.5 + 2) * 60,
					vx: 0,
					vy: 0,
					radius: 10,
					glowColor: "rgba(34, 211, 238, 0.7)", // 青蓝发光
					parentRecordId: record.id,
				};
				tempNodes.push(todoNode);
				nodeMap.set(todoNodeId, true);

				// 连线：Record -> Todo
				tempEdges.push({ source: recordNodeId, target: todoNodeId, isSemantic: false });
			});
		});

		// D. 语义交叉连线逻辑（不同 Record 之间若包含相同的有意义词，则画虚线连线）
		for (let i = 0; i < validRecords.length; i++) {
			for (let j = i + 1; j < validRecords.length; j++) {
				const r1 = validRecords[i];
				const r2 = validRecords[j];
				const words1 = recordKeywordsMap.get(r1.id) || [];
				const words2 = recordKeywordsMap.get(r2.id) || [];

				// 找交集
				const intersection = words1.filter((w) => words2.includes(w));
				if (intersection.length > 0) {
					// 共享关键词，创建跨想法虚线连接
					tempEdges.push({
						source: `rec_${r1.id}`,
						target: `rec_${r2.id}`,
						isSemantic: true,
					});
				}
			}
		}

		setNodes(tempNodes);
		setEdges(tempEdges);
	}, [historyList]);

	// 2. 二维质点力学弹簧引擎 (Force Loop)
	useEffect(() => {
		if (nodes.length === 0) return;

		let animationId: number;

		const updatePhysics = () => {
			setNodes((prevNodes) => {
				const nextNodes = prevNodes.map((n) => ({ ...n }));
				const nodeIndexMap = new Map<string, Node>();
				nextNodes.forEach((n) => nodeIndexMap.set(n.id, n));

				const kLink = 0.05; // 弹簧弹性系数
				const damping = 0.85; // 阻尼系数（摩擦力）

				// A. 节点间排斥力 (库伦定律简化版)
				for (let i = 0; i < nextNodes.length; i++) {
					for (let j = i + 1; j < nextNodes.length; j++) {
						const n1 = nextNodes[i];
						const n2 = nextNodes[j];
						if (n1.id === draggedNodeId || n2.id === draggedNodeId) continue;

						const dx = n2.x - n1.x;
						const dy = n2.y - n1.y;
						const dist = Math.sqrt(dx * dx + dy * dy) || 1;

						// 防止距离过近产生无穷大排斥
						if (dist < 400) {
							const force = repulsionStrength / (dist * dist);
							const fx = (dx / dist) * force;
							const fy = (dy / dist) * force;

							// 反向排斥
							n1.vx -= fx;
							n1.vy -= fy;
							n2.vx += fx;
							n2.vy += fy;
						}
					}
				}

				// B. 连线拉力 (胡克定律弹簧力)
				edges.forEach((edge) => {
					const nSource = nodeIndexMap.get(edge.source);
					const nTarget = nodeIndexMap.get(edge.target);
					if (!nSource || !nTarget) return;

					const dx = nTarget.x - nSource.x;
					const dy = nTarget.y - nSource.y;
					const dist = Math.sqrt(dx * dx + dy * dy) || 1;

					// 跨卡片虚线连线拉力较弱，防止星团堆叠在一起
					const targetDist = edge.isSemantic ? linkDistance * 1.8 : linkDistance;
					const force = (dist - targetDist) * kLink * (edge.isSemantic ? 0.3 : 1);

					const fx = (dx / dist) * force;
					const fy = (dy / dist) * force;

					nSource.vx += fx;
					nSource.vy += fy;
					nTarget.vx -= fx;
					nTarget.vy -= fy;
				});

				// C. 向中心温和吸引（避免漂移到屏幕外部）
				const cx = 500;
				const cy = 400;
				nextNodes.forEach((n) => {
					const dx = cx - n.x;
					const dy = cy - n.y;
					n.vx += dx * 0.005;
					n.vy += dy * 0.005;
				});

				// D. 更新位置与速度
				nextNodes.forEach((n) => {
					if (n.id === draggedNodeId) {
						// 拖拽节点不更新物理位置
						n.vx = 0;
						n.vy = 0;
						return;
					}

					n.vx *= damping;
					n.vy *= damping;

					n.x += n.vx;
					n.y += n.vy;
				});

				return nextNodes;
			});

			animationId = requestAnimationFrame(updatePhysics);
		};

		animationId = requestAnimationFrame(updatePhysics);
		return () => cancelAnimationFrame(animationId);
	}, [nodes.length, edges, draggedNodeId, linkDistance, repulsionStrength]);

	// 3. 拖拽与缩放事件处理
	const handleMouseDown = (e: React.MouseEvent<SVGSVGElement>) => {
		const target = e.target as SVGElement;
		const nodeId = target.getAttribute("data-node-id");

		if (nodeId) {
			setDraggedNodeId(nodeId);
		} else {
			setIsPanning(true);
			panStart.current = { x: e.clientX - transform.x, y: e.clientY - transform.y };
		}
	};

	const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
		if (draggedNodeId) {
			const rect = svgRef.current?.getBoundingClientRect();
			if (!rect) return;

			const mouseCanvasX = (e.clientX - rect.left - transform.x) / transform.scale;
			const mouseCanvasY = (e.clientY - rect.top - transform.y) / transform.scale;

			setNodes((prevNodes) =>
				prevNodes.map((n) => {
					if (n.id === draggedNodeId) {
						return { ...n, x: mouseCanvasX, y: mouseCanvasY, vx: 0, vy: 0 };
					}
					return n;
				})
			);
		} else if (isPanning) {
			setTransform((prev) => ({
				...prev,
				x: e.clientX - panStart.current.x,
				y: e.clientY - panStart.current.y,
			}));
		}
	};

	const handleMouseUp = () => {
		setDraggedNodeId(null);
		setIsPanning(false);
	};

	const handleWheel = (e: React.WheelEvent<SVGSVGElement>) => {
		e.preventDefault();
		const scaleAmount = 0.05;
		const nextScale = e.deltaY < 0 ? transform.scale + scaleAmount : transform.scale - scaleAmount;
		const boundedScale = Math.min(Math.max(nextScale, 0.2), 3);

		setTransform((prev) => ({
			...prev,
			scale: boundedScale,
		}));
	};

	return (
		<div className="fixed inset-0 z-50 bg-[#07080E]/95 backdrop-blur-md flex flex-col items-center justify-between text-white select-none">
			{/* 顶部标题栏 */}
			<div className="w-full flex items-center justify-between px-6 py-4 bg-white/5 border-b border-white/10 backdrop-blur-md">
				<div>
					<h1 className="text-xl font-bold tracking-wider text-purple-400 flex items-center gap-2">
						🌌 {isZh ? "全局脑力星空" : "Global Mind Landscape"}
					</h1>
					<p className="text-xs text-gray-400 mt-1">
						{isZh
							? "将您多次倾倒的想法与待办聚合成霓虹星团。发光实线为卡片内部关系，微弱虚线为跨文档想法的关联线。"
							: "Interactive landscape aggregating your mental dumps. Glow solid lines map raw connections; dashed lines represent cross-document relations."}
					</p>
				</div>
				<button
					onClick={onClose}
					className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/20 transition-all font-semibold border border-white/15"
				>
					{isZh ? "返回面板" : "Close"}
				</button>
			</div>

			{/* SVG 力导向渲染画布 */}
			<div className="flex-1 w-full relative overflow-hidden bg-[radial-gradient(circle_at_center,#181928_0%,#07080E_100%)]">
				<svg
					ref={svgRef}
					className="w-full h-full cursor-grab active:cursor-grabbing"
					onMouseDown={handleMouseDown}
					onMouseMove={handleMouseMove}
					onMouseUp={handleMouseUp}
					onMouseLeave={handleMouseUp}
					onWheel={handleWheel}
				>
					<g transform={`translate(${transform.x}, ${transform.y}) scale(${transform.scale})`}>
						{/* 绘制连线 */}
						{edges.map((edge, idx) => {
							const sourceNode = nodes.find((n) => n.id === edge.source);
							const targetNode = nodes.find((n) => n.id === edge.target);
							if (!sourceNode || !targetNode) return null;

							return (
								<line
									key={`edge_${idx}`}
									x1={sourceNode.x}
									y1={sourceNode.y}
									x2={targetNode.x}
									y2={targetNode.y}
									stroke={edge.isSemantic ? "rgba(168, 85, 247, 0.25)" : "rgba(255, 255, 255, 0.15)"}
									strokeWidth={edge.isSemantic ? 1.5 : 2}
									strokeDasharray={edge.isSemantic ? "4 6" : undefined}
									style={{
										filter: edge.isSemantic ? "drop-shadow(0 0 3px rgba(168, 85, 247, 0.4))" : undefined,
									}}
								/>
							);
						})}

						{/* 绘制节点 */}
						{nodes.map((node) => (
							<g
								key={node.id}
								transform={`translate(${node.x}, ${node.y})`}
								style={{ transition: draggedNodeId === node.id ? "none" : "transform 0.1s ease-out" }}
							>
								{/* 节点外层发光环 */}
								<circle
									r={node.radius + 6}
									fill="transparent"
									stroke={node.glowColor}
									strokeWidth={2}
									opacity={0.3}
									style={{ filter: `blur(4px)` }}
								/>
								{/* 节点实体圆 */}
								<circle
									r={node.radius}
									fill={
										node.type === "record"
											? "#8B5CF6"
											: node.type === "insight"
											? "#EC4899"
											: "#22D3EE"
									}
									stroke="white"
									strokeWidth={1.5}
									data-node-id={node.id}
									style={{
										cursor: "pointer",
										filter: `drop-shadow(0 0 10px ${node.glowColor})`,
									}}
								/>
								{/* 节点文字描述标签 */}
								<text
									y={node.radius + 16}
									textAnchor="middle"
									fill="#C5C6C7"
									fontSize={node.type === "record" ? 12 : 10}
									fontWeight={node.type === "record" ? "bold" : "normal"}
									className="pointer-events-none select-none bg-black/40"
									style={{
										paintOrder: "stroke",
										stroke: "#07080E",
										strokeWidth: 3,
										strokeLinejoin: "round",
									}}
								>
									{node.label}
								</text>
							</g>
						))}
					</g>
				</svg>

				{/* 悬浮力学控制器 */}
				<div className="absolute bottom-6 left-6 p-4 rounded-xl bg-black/60 border border-white/10 backdrop-blur-md flex flex-col gap-3 w-64">
					<div className="text-xs font-bold text-gray-300">⚙️ {isZh ? "星空引力微调" : "Physics Tuner"}</div>
					
					{/* 连线弹力 */}
					<div className="flex flex-col gap-1">
						<div className="flex justify-between text-[10px] text-gray-400">
							<span>{isZh ? "节点间距" : "Link Distance"}</span>
							<span>{linkDistance}px</span>
						</div>
						<input
							type="range"
							min="60"
							max="240"
							value={linkDistance}
							onChange={(e) => setLinkDistance(Number(e.target.value))}
							className="w-full h-1 bg-purple-900 rounded-lg appearance-none cursor-pointer"
						/>
					</div>

					{/* 节点排斥 */}
					<div className="flex flex-col gap-1">
						<div className="flex justify-between text-[10px] text-gray-400">
							<span>{isZh ? "排斥强度" : "Repulsion Strength"}</span>
							<span>{repulsionStrength}</span>
						</div>
						<input
							type="range"
							min="200"
							max="1600"
							value={repulsionStrength}
							onChange={(e) => setRepulsionStrength(Number(e.target.value))}
							className="w-full h-1 bg-purple-900 rounded-lg appearance-none cursor-pointer"
						/>
					</div>

					<div className="text-[10px] text-purple-400 mt-1 italic text-center">
						{isZh ? "✨ 鼠标滚轮可无限缩放画布，按住空白处可拖动拖拽" : "✨ Scroll wheel to scale. Drag background to pan."}
					</div>
				</div>

				{/* 图例（Legend） */}
				<div className="absolute top-6 left-6 p-4 rounded-xl bg-black/60 border border-white/10 backdrop-blur-md flex flex-col gap-2">
					<div className="text-xs font-bold text-gray-300 mb-1">{isZh ? "图例说明" : "Legend"}</div>
					<div className="flex items-center gap-2">
						<span className="w-3 h-3 rounded-full bg-[#8B5CF6] inline-block shadow-[0_0_6px_#8B5CF6]"></span>
						<span className="text-xs text-gray-300">{isZh ? "倾倒卡片" : "Record Node"}</span>
					</div>
					<div className="flex items-center gap-2">
						<span className="w-3 h-3 rounded-full bg-[#EC4899] inline-block shadow-[0_0_6px_#EC4899]"></span>
						<span className="text-xs text-gray-300">{isZh ? "核心想法" : "Insight Node"}</span>
					</div>
					<div className="flex items-center gap-2">
						<span className="w-3 h-3 rounded-full bg-[#22D3EE] inline-block shadow-[0_0_6px_#22D3EE]"></span>
						<span className="text-xs text-gray-300">{isZh ? "行动待办" : "Todo Node"}</span>
					</div>
				</div>
			</div>
		</div>
	);
}
