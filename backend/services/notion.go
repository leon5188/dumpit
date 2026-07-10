package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type NotionService struct{}

func NewNotionService() *NotionService {
	return &NotionService{}
}

// NotionSyncRequest 定义了向 Notion 同步的请求体
type NotionSyncRequest struct {
	Token          string          `json:"notion_token"`
	ParentPageID   string          `json:"parent_page_id"`
	Summary        string          `json:"summary"`
	ActionItems    []string        `json:"action_items"`
	KeyInsights    []string        `json:"key_insights"`
	CalendarEvents []CalendarEvent `json:"calendar_events"`
}

// SyncToNotion 将整理的内容推送到 Notion 页面下
func (s *NotionService) SyncToNotion(req NotionSyncRequest) error {
	url := "https://api.notion.com/v1/pages"

	// 1. 构建 Notion API Body
	var children []map[string]interface{}

	// 添加 H2 整理文标题
	children = append(children, map[string]interface{}{
		"object": "block",
		"type":   "heading_2",
		"heading_2": map[string]interface{}{
			"rich_text": []map[string]interface{}{
				{
					"text": map[string]interface{}{
						"content": "📝 语气重构整理 (Summary)",
					},
				},
			},
		},
	})

	// 添加整理文内容段落
	children = append(children, map[string]interface{}{
		"object": "block",
		"type":   "paragraph",
		"paragraph": map[string]interface{}{
			"rich_text": []map[string]interface{}{
				{
					"text": map[string]interface{}{
						"content": req.Summary,
					},
				},
			},
		},
	})

	// 添加 H2 待办清单标题
	if len(req.ActionItems) > 0 {
		children = append(children, map[string]interface{}{
			"object": "block",
			"type":   "heading_2",
			"heading_2": map[string]interface{}{
				"rich_text": []map[string]interface{}{
					{
						"text": map[string]interface{}{
							"content": "✅ 行动待办清单 (Todos)",
						},
					},
				},
			},
		})

		// 遍历添加 to_do 类型的 block
		for _, item := range req.ActionItems {
			children = append(children, map[string]interface{}{
				"object": "block",
				"type":   "to_do",
				"to_do": map[string]interface{}{
					"rich_text": []map[string]interface{}{
						{
							"text": map[string]interface{}{
								"content": item,
							},
						},
					},
					"checked": false,
				},
			})
		}
	}

	// 添加 H2 脑力网状连线（作为 bullet 点）
	if len(req.KeyInsights) > 0 {
		children = append(children, map[string]interface{}{
			"object": "block",
			"type":   "heading_2",
			"heading_2": map[string]interface{}{
				"rich_text": []map[string]interface{}{
					{
						"text": map[string]interface{}{
							"content": "🕸️ 深度脑力洞察 (Insights)",
						},
					},
				},
			},
		})

		for _, insight := range req.KeyInsights {
			children = append(children, map[string]interface{}{
				"object": "block",
				"type":   "bulleted_list_item",
				"bulleted_list_item": map[string]interface{}{
					"rich_text": []map[string]interface{}{
						{
							"text": map[string]interface{}{
								"content": insight,
							},
						},
					},
				},
			})
		}
	}

	// 添加日程时间轴
	if len(req.CalendarEvents) > 0 {
		children = append(children, map[string]interface{}{
			"object": "block",
			"type":   "heading_2",
			"heading_2": map[string]interface{}{
				"rich_text": []map[string]interface{}{
					{
						"text": map[string]interface{}{
							"content": "📅 时间轴行程规划 (Timeline)",
						},
					},
				},
			},
		})

		for _, event := range req.CalendarEvents {
			children = append(children, map[string]interface{}{
				"object": "block",
				"type":   "to_do",
				"to_do": map[string]interface{}{
					"rich_text": []map[string]interface{}{
						{
							"text": map[string]interface{}{
								"content": fmt.Sprintf("[%s] %s", event.Time, event.Title),
							},
						},
					},
					"checked": false,
				},
			})
		}
	}

	// 组装最终 JSON Body
	nowStr := time.Now().Format("2006-01-02 15:04")
	bodyMap := map[string]interface{}{
		"parent": map[string]interface{}{
			"page_id": req.ParentPageID,
		},
		"properties": map[string]interface{}{
			"title": map[string]interface{}{
				"title": []map[string]interface{}{
					{
						"text": map[string]interface{}{
							"content": fmt.Sprintf("🧠 BrainVent. Mind Restructured (%s)", nowStr),
						},
					},
				},
			},
		},
		"children": children,
	}

	jsonBytes, err := json.Marshal(bodyMap)
	if err != nil {
		return fmt.Errorf("failed to marshal notion request: %w", err)
	}

	// 2. 发起 HTTP 请求
	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonBytes))
	if err != nil {
		return fmt.Errorf("failed to create http request: %w", err)
	}

	httpReq.Header.Set("Authorization", "Bearer "+req.Token)
	httpReq.Header.Set("Notion-Version", "2022-06-28")
	httpReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		return fmt.Errorf("failed to execute notion api call: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		var errResp map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&errResp)
		return fmt.Errorf("notion api error (status %d): %v", resp.StatusCode, errResp["message"])
	}

	return nil
}
