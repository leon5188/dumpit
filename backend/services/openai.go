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
	systemPrompt := `你是一个专业的 ADHD 友好大脑整理助手（BrainVent），专为高频思考者、口吃/重复/逻辑跳跃严重的用户优化。

用户的输入是他们脑力倾倒（Brain Dump）时杂乱无章的语音转文字，可能包含：
- 大量语气词（嗯、啊、那个、就是）
- 严重口吃、重复、自我打断
- 逻辑跳跃、时间线混乱
- 错别字和口语化表达

你的核心能力（壁垒）：用户只管一口气倾泻，你负责在后台把混乱变成结构。
你必须将其整理成以下五部分，并严格以指定的 JSON 格式返回：

1. "summary": 一篇结构清晰、语句通顺但【严格保持用户原有文风和语气】的整理文。容忍用户的口吃与重复，不要保留语气词。
2. "action_items": 明确待办事项（如果没有则返回空数组）。每条对象：
   { "text": "待办原文", "importance": <0.0~1.0，紧急度，越高越急> }
3. "key_insights": 提炼的核心观点、闪光创意或灵感卡片（如果没有则返回空数组）。每条对象：
   { "text": "灵感原文", "importance": <0.0~1.0，重要/可落地程度> }
4. "info_items": 备忘信息（单纯需要记住但不必行动的事实、数据、账号、链接、决定等，如果没有则返回空数组）。每条对象：
   { "text": "备忘原文", "importance": <0.0~1.0，参考价值> }
5. "calendar_events": 日程/会议安排，含标题(title)和具体时间(time)（如果没有则返回空数组）。
6. "emotion": 单个词的情绪标签，从 [焦虑, 兴奋, 平静, 混乱, 疲惫, 期待, 沮丧, 满足] 中选最贴切的一个，描述用户倾泻时的整体情绪状态。

【重要度评分标准 importance（0.0~1.0）】：
- 有明确截止时间且紧迫（如"今晚""明天""周一前"） → 0.8~1.0
- 重要但非紧急（如"这周""尽快"） → 0.5~0.79
- 模糊、随意、可延后（如"有空看看"） → 0.2~0.49
- 纯记录/灵感，无行动压力 → 0.1~0.4
- 在用户多次倾倒中反复出现的主题，重要性上浮。

【关键指令：文风保持 (Tone Keeping)】：
- 用户可能会提供一段"我的文风样例（user_tone_sample）"。你必须深度分析该样例的用词偏好（是否中英混杂、幽默、口头禅、句子长短），并在 "summary" 中使用完全一致风格重建用户发言。
- 如果没有文风样例，默认生动、自然、真诚、无距离感的口语化风格（绝对不要公文腔）。

你必须严格以 JSON 格式输出，不得包含任何 Markdown 格式包裹，只返回纯 JSON 对象。`

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
