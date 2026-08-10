package services

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/sashabaranov/go-openai"
)

// CalendarEvent 定义了从脑力倾倒中识别并提取出的日程安排
type CalendarEvent struct {
	Title string `json:"title"` // 日程标题
	Time  string `json:"time"`  // 预估具体时间（例如："今天下午3点", "下周五" 等）
}

// ImportanceItem 带 AI 重要度评分的结构化条目（action_item / key_insight 通用）
type ImportanceItem struct {
	Text       string  `json:"text"`        // 条目原文
	Importance float64 `json:"importance"`  // 0.0~1.0，AI 判定该条目的紧迫/重要程度
}

// UnmarshalJSON 解析时自动将 importance 夹到 0~1，避免 AI 越界污染下游排序
func (it *ImportanceItem) UnmarshalJSON(data []byte) error {
	var raw struct {
		Text       string  `json:"text"`
		Importance float64 `json:"importance"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	it.Text = raw.Text
	it.Importance = normalizeImportance(raw.Importance)
	return nil
}

// ProcessedDump 定义了 AI 整理脑力倾倒后的结构化输出格式
type ProcessedDump struct {
	Summary        string            `json:"summary"`          // 语气克隆后的重组整理文
	ActionItems    []ImportanceItem  `json:"action_items_v2"`  // 带重要度评分的待办（向后兼容新字段）
	KeyInsights    []ImportanceItem  `json:"key_insights_v2"`  // 带重要度评分的灵感（向后兼容新字段）
	InfoItems      []ImportanceItem  `json:"info_items_v2"`    // 带重要度评分的备忘信息（新维度）
	CalendarEvents []CalendarEvent   `json:"calendar_events"`  // 自动识别并提取的日程安排
	Emotion        string            `json:"emotion"`          // 情绪标签（如：焦虑/兴奋/平静/混乱）

	// 向后兼容：旧客户端（v1.1.0 及更早）期望 action_items / key_insights 为纯字符串数组。
	// 这里保留旧字段名，由 RestructureDump 在返回前填充，避免已上线版本解析失败。
	LegacyActionItems []string `json:"action_items"`
	LegacyKeyInsights []string `json:"key_insights"`
	LegacyInfoItems   []string `json:"info_items"`
}

// normalizeImportance 把 AI 返回的任意数值夹到 0~1 区间，容错缺失/越界
func normalizeImportance(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

type OpenAIService struct {
	client *openai.Client
}

func NewOpenAIService() *OpenAIService {
	apiKey := os.Getenv("OPENAI_API_KEY")
	return &OpenAIService{
		client: openai.NewClient(apiKey),
	}
}

// TranscribeAudio 调用 Whisper API 将音频文件转译为原始文本
func (s *OpenAIService) TranscribeAudio(ctx context.Context, audioFilePath string) (string, error) {
	req := openai.AudioRequest{
		Model:    openai.Whisper1,
		FilePath: audioFilePath,
		// 使用英语 prompt 强行引导模型输出英语（如果不提供 language 参数，Whisper 会根据 prompt 的语言偏向来检测）
		Prompt: "Hello, this is a voice memo. Please transcribe the audio exactly as spoken in its original language. Do not translate.",
	}

	resp, err := s.client.CreateTranscription(ctx, req)
	if err != nil {
		return "", fmt.Errorf("whisper transcription failed: %w", err)
	}

	return resp.Text, nil
}

// RestructureDump 利用 GPT 根据用户风格重构脑力倾倒文本，返回结构化的 JSON 数据
func (s *OpenAIService) RestructureDump(ctx context.Context, rawText string, userToneSample string, customPrompt string) (*ProcessedDump, error) {
	// 默认的系统提示词，确立 AI 角色与重组规则
	systemPrompt := `You are "BrainVent", an ADHD-friendly brain dump restructuring assistant.
Your task is to take a chaotic brain dump (speech-to-text) and restructure it into a clean JSON format.

【CRITICAL LANGUAGE RULE】
1. The user will speak in English, Chinese, or a mix of both.
2. DO NOT TRANSLATE. You must detect the spoken language(s) from the transcript.
3. If the transcript is in English, YOU MUST WRITE EVERYTHING (summary, action_items, key_insights, info_items, calendar_events, emotion) IN ENGLISH. Do NOT output Chinese.
4. If the transcript is in Chinese, write everything in Chinese.
5. If it's a mix, maintain the exact same mixed vocabulary as the user.

【YOUR TASK】
Transform the chaotic input into the following 5 components, returning ONLY valid JSON:

1. "summary": A well-structured, coherent summary that STRICTLY keeps the user's original tone and POV. Do NOT add chatty introductions like "I was thinking today" or "Here is what you said". Just speak as if the user articulated their thoughts perfectly.
2. "action_items": Actionable tasks (empty array if none).
   { "text": "task description", "importance": <0.0~1.0, higher is more urgent> }
3. "key_insights": Core ideas, creative sparks, or a-ha moments (empty array if none).
   { "text": "insight description", "importance": <0.0~1.0, higher is more profound> }
4. "info_items": Facts, links, accounts, or decisions that just need to be remembered, no action needed (empty array if none).
   { "text": "info description", "importance": <0.0~1.0, higher is more useful> }
5. "calendar_events": Any schedule, meeting, or deadline mentioned. Extract ANY time clues (e.g., "tomorrow at 3pm" -> "Tomorrow 15:00", "before Friday" -> "Before this Friday").
   { "title": "short event title", "time": "normalized time description" }
6. "emotion": A single word describing their emotional state (e.g., Anxious, Excited, Calm, Chaotic, Exhausted, Expectant, Frustrated, Satisfied).

【IMPORTANCE SCORING (0.0~1.0)】
- Urgent with clear deadline: 0.8~1.0
- Important but not urgent: 0.5~0.79
- Vague, casual, can be delayed: 0.2~0.49
- Pure record/insight, no pressure: 0.1~0.4

Return ONLY pure JSON. No markdown wrappers, no explanations.`

	// 拼接用户输入
	userContent := fmt.Sprintf("原始转录文本:\n\"%s\"\n\n", rawText)
	if userToneSample != "" {
		userContent += fmt.Sprintf("用户的文风参考样例:\n\"%s\"\n\n", userToneSample)
	}
	if customPrompt != "" {
		userContent += fmt.Sprintf("用户的额外要求:\n\"%s\"\n\n", customPrompt)
	}

	resp, err := s.client.CreateChatCompletion(
		ctx,
		openai.ChatCompletionRequest{
			Model: openai.GPT4oMini,
			Messages: []openai.ChatCompletionMessage{
				{
					Role:    openai.ChatMessageRoleSystem,
					Content: systemPrompt,
				},
				{
					Role:    openai.ChatMessageRoleUser,
					Content: userContent,
				},
			},
			ResponseFormat: &openai.ChatCompletionResponseFormat{
				Type: openai.ChatCompletionResponseFormatTypeJSONObject, // 强制返回 JSON 格式
			},
			Temperature: 0.7,
		},
	)
	if err != nil {
		return nil, fmt.Errorf("gpt chat completion failed: %w", err)
	}

	if len(resp.Choices) == 0 {
		return nil, fmt.Errorf("no response choices returned from gpt")
	}

	// 解析 JSON 结果。AI 返回的是 { action_items: [{text, importance}], key_insights: [...], info_items: [...], emotion: "..." }
	var raw struct {
		Summary        string           `json:"summary"`
		ActionItems    []ImportanceItem `json:"action_items"`
		KeyInsights    []ImportanceItem `json:"key_insights"`
		InfoItems      []ImportanceItem `json:"info_items"`
		CalendarEvents []CalendarEvent  `json:"calendar_events"`
		Emotion        string           `json:"emotion"`
	}
	if err := json.Unmarshal([]byte(resp.Choices[0].Message.Content), &raw); err != nil {
		return nil, fmt.Errorf("failed to parse gpt JSON response: %w (raw response: %s)", err, resp.Choices[0].Message.Content)
	}

	// 兼容 AI 偶尔仍返回纯字符串数组的情况：尝试兜底解析
	if len(raw.ActionItems) == 0 {
		var legacy struct {
			ActionItems []string `json:"action_items"`
			KeyInsights []string `json:"key_insights"`
			InfoItems   []string `json:"info_items"`
		}
		if json.Unmarshal([]byte(resp.Choices[0].Message.Content), &legacy) == nil {
			for _, t := range legacy.ActionItems {
				raw.ActionItems = append(raw.ActionItems, ImportanceItem{Text: t, Importance: 0.5})
			}
			for _, t := range legacy.KeyInsights {
				raw.KeyInsights = append(raw.KeyInsights, ImportanceItem{Text: t, Importance: 0.3})
			}
			for _, t := range legacy.InfoItems {
				raw.InfoItems = append(raw.InfoItems, ImportanceItem{Text: t, Importance: 0.4})
			}
		}
	}

	// 夹重要性到 0~1
	for i := range raw.ActionItems {
		raw.ActionItems[i].Importance = normalizeImportance(raw.ActionItems[i].Importance)
	}
	for i := range raw.KeyInsights {
		raw.KeyInsights[i].Importance = normalizeImportance(raw.KeyInsights[i].Importance)
	}
	for i := range raw.InfoItems {
		raw.InfoItems[i].Importance = normalizeImportance(raw.InfoItems[i].Importance)
	}

	// 构造最终返回：v2 对象字段 + 旧字符串字段（向后兼容已上线客户端）
	processed := &ProcessedDump{
		Summary:        raw.Summary,
		ActionItems:    raw.ActionItems,
		KeyInsights:    raw.KeyInsights,
		InfoItems:      raw.InfoItems,
		CalendarEvents: raw.CalendarEvents,
		Emotion:        raw.Emotion,
	}
	for _, it := range raw.ActionItems {
		processed.LegacyActionItems = append(processed.LegacyActionItems, it.Text)
	}
	for _, it := range raw.KeyInsights {
		processed.LegacyKeyInsights = append(processed.LegacyKeyInsights, it.Text)
	}
	for _, it := range raw.InfoItems {
		processed.LegacyInfoItems = append(processed.LegacyInfoItems, it.Text)
	}

	return processed, nil
}
