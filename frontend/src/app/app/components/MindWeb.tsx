"use client";

import React, { useState, useEffect } from "react";

interface GraphNode {
	id: string;
	label: string;
	type: "insight" | "todo";
	x: number;
	y: number;
}

interface GraphEdge {
	source: string;
	target: string;
}

interface MindWebProps {
	summary: string;
	keyInsights: string[];
	actionItems: string[];
	title: string;
}

export default function MindWeb({ summary, keyInsights, actionItems, title }: MindWebProps) {
	const [nodes, setNodes] = useState<GraphNode[]>([]);
	const [edges, setEdges] = useState<GraphEdge[]>([]);
	const [draggedNodeId, setDraggedNodeId] = useState<string | null>(null);

	useEffect(() => {
		if (summary && (keyInsights.length > 0 || actionItems.length > 0)) {
			const newNodes: GraphNode[] = [];
			const newEdges: GraphEdge[] = [];
			
			const centerX = 250;
			const centerY = 190;
			const radius = 100;
			
			const totalItems = keyInsights.length + actionItems.length;
			
			keyInsights.forEach((insight, idx) => {
				const angle = (idx / totalItems) * 2 * Math.PI;
				newNodes.push({
					id: `insight-${idx}`,
					label: insight.length > 15 ? insight.slice(0, 15) + "..." : insight,
					type: "insight",
					x: centerX + radius * Math.cos(angle),
					y: centerY + radius * Math.sin(angle),
				});
			});
			
			actionItems.forEach((todo, idx) => {
				const angle = ((keyInsights.length + idx) / totalItems) * 2 * Math.PI;
				newNodes.push({
					id: `todo-${idx}`,
					label: todo.length > 15 ? todo.slice(0, 15) + "..." : todo,
					type: "todo",
					x: centerX + radius * Math.cos(angle),
					y: centerY + radius * Math.sin(angle),
				});
			});
			
			for (let i = 0; i < newNodes.length; i++) {
				newEdges.push({
					source: newNodes[i].id,
					target: newNodes[(i + 1) % newNodes.length].id,
				});
				if (newNodes[i].type === "todo" && newNodes.length > 2) {
					newEdges.push({
						source: newNodes[i].id,
						target: newNodes[0].id,
					});
				}
			}
			
			setNodes(newNodes);
			setEdges(newEdges);
		} else {
			setNodes([]);
			setEdges([]);
		}
	}, [summary, keyInsights, actionItems]);

	const handleMouseDown = (nodeId: string) => {
		setDraggedNodeId(nodeId);
	};

	const handleMouseMove = (e: React.MouseEvent<SVGSVGElement>) => {
		if (!draggedNodeId) return;
		const rect = e.currentTarget.getBoundingClientRect();
		const mouseX = e.clientX - rect.left;
		const mouseY = e.clientY - rect.top;
		
		setNodes((prev) =>
			prev.map((node) =>
				node.id === draggedNodeId ? { ...node, x: mouseX, y: mouseY } : node
			)
		);
	};

	const handleMouseUp = () => {
		setDraggedNodeId(null);
	};

	return (
		<>
			<div className="panel-header" style={{ marginTop: "2rem", marginBottom: "0.5rem" }}>
				<h2 className="panel-title">{title}</h2>
			</div>
			<div className="mind-web-container">
				<svg 
					className="mind-web-svg" 
					onMouseMove={handleMouseMove} 
					onMouseUp={handleMouseUp}
					onMouseLeave={handleMouseUp}
				>
					{edges.map((edge, idx) => {
						const sourceNode = nodes.find(n => n.id === edge.source);
						const targetNode = nodes.find(n => n.id === edge.target);
						if (!sourceNode || !targetNode) return null;
						return (
							<line
								key={idx}
								className="edge-line"
								x1={sourceNode.x}
								y1={sourceNode.y}
								x2={targetNode.x}
								y2={targetNode.y}
							/>
						);
					})}
					
					{nodes.map((node) => (
						<g
							key={node.id}
							className="node-group"
							transform={`translate(${node.x}, ${node.y})`}
							onMouseDown={() => handleMouseDown(node.id)}
						>
							<circle
								className="node-circle"
								r="7"
								fill={node.type === "insight" ? "var(--color-primary)" : "var(--color-success)"}
								style={{ filter: "drop-shadow(0px 0px 4px rgba(139, 92, 246, 0.6))" }}
							/>
							<text
								className="node-text"
								dx="12"
								dy="4"
							>
								{node.label}
							</text>
						</g>
					))}
				</svg>
			</div>
		</>
	);
}
