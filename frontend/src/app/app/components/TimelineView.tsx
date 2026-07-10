"use client";

import React from "react";
import { CalendarEvent } from "../locales";

interface TimelineViewProps {
	calendarEvents: CalendarEvent[];
	calendarTitle: string;
	noCalendar: string;
}

export default function TimelineView({ calendarEvents, calendarTitle, noCalendar }: TimelineViewProps) {
	return (
		<div className="glass-panel">
			<div className="panel-header">
				<h2 className="panel-title">{calendarTitle}</h2>
			</div>
			{calendarEvents.length === 0 ? (
				<div style={{ color: "var(--text-dark)", fontSize: "0.9rem" }}>{noCalendar}</div>
			) : (
				<div className="timeline-container">
					<div className="timeline-line"></div>
					{calendarEvents.map((event, idx) => (
						<div key={idx} className="timeline-item">
							<div className="timeline-badge"></div>
							<div className="timeline-content">
								<div className="timeline-title">{event.title}</div>
								<div className="timeline-time">
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
										<circle cx="12" cy="12" r="10"/>
										<path d="M12 6v6l4 2"/>
									</svg>
									{event.time}
								</div>
							</div>
						</div>
					))}
				</div>
			)}
		</div>
	);
}
