"use client";

import React, { useState } from "react";

interface TodoManagerProps {
	actionItems: string[];
	todoTitle: string;
	noTodo: string;
	todoPlaceholder: string;
	onTodosChange: (updatedTodos: string[]) => void;
}

export default function TodoManager({
	actionItems,
	todoTitle,
	noTodo,
	todoPlaceholder,
	onTodosChange
}: TodoManagerProps) {
	const [newTodoText, setNewTodoText] = useState("");
	const [checkedItems, setCheckedItems] = useState<Record<number, boolean>>({});

	const handleAddTodo = (e: React.FormEvent) => {
		e.preventDefault();
		if (!newTodoText.trim()) return;
		
		const updatedTodos = [...actionItems, newTodoText.trim()];
		onTodosChange(updatedTodos);
		setNewTodoText("");
	};

	const handleDeleteTodo = (indexToDelete: number, e: React.MouseEvent) => {
		e.stopPropagation();
		const updatedTodos = actionItems.filter((_, idx) => idx !== indexToDelete);
		onTodosChange(updatedTodos);
		
		// 同时清理勾选状态
		const newChecked = { ...checkedItems };
		delete newChecked[indexToDelete];
		// 重新映射剩下的勾选状态（因为索引位移了）
		const mappedChecked: Record<number, boolean> = {};
		updatedTodos.forEach((_, idx) => {
			const originalIdx = idx >= indexToDelete ? idx + 1 : idx;
			if (checkedItems[originalIdx]) {
				mappedChecked[idx] = true;
			}
		});
		setCheckedItems(mappedChecked);
	};

	const toggleTodo = (index: number) => {
		setCheckedItems((prev) => ({
			...prev,
			[index]: !prev[index],
		}));
	};

	return (
		<div className="glass-panel">
			<div className="panel-header">
				<h2 className="panel-title">{todoTitle}</h2>
			</div>
			
			<div className="todo-list">
				{actionItems.length === 0 ? (
					<div style={{ color: "var(--text-dark)", fontSize: "0.85rem", padding: "0.5rem 0" }}>{noTodo}</div>
				) : (
					actionItems.map((todo, idx) => (
						<div key={idx} className="todo-item" onClick={() => toggleTodo(idx)}>
							<div className={`todo-checkbox ${checkedItems[idx] ? "checked" : ""}`}>
								{checkedItems[idx] && "✓"}
							</div>
							<span className="todo-text">{todo}</span>
							
							<button 
								className="todo-item-delete"
								onClick={(e) => handleDeleteTodo(idx, e)}
								title="Delete task"
							>
								×
							</button>
						</div>
					))
				)}
			</div>

			<form className="todo-input-container" onSubmit={handleAddTodo}>
				<input
					type="text"
					className="todo-add-input"
					placeholder={todoPlaceholder}
					value={newTodoText}
					onChange={(e) => setNewTodoText(e.target.value)}
				/>
				<button type="submit" className="todo-add-btn">+</button>
			</form>
		</div>
	);
}
