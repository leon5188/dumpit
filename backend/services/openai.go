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

// ProcessedDump 定义了 AI 整理脑力倾倒后的结构化输出格式
type ProcessedDump struct {
	Summary        string          `json:"summary"`         // 语气克隆后的重组整理文
	ActionItems    []string        `json:"action_items"`    // 自动提取的待办事项清单
	KeyInsights    []string        `json:"key_insights"`    // 提炼的闪光灵感卡片
	CalendarEvents []CalendarEvent `json:"calendar_events"` // 自动识别并提取的日程安排
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
	systemPrompt := `你是一个专业的 ADHD 友好大脑整理助手（BrainVent）。
用户的输入是他们脑力倾倒（Brain Dump）时杂乱无章的语音转文字，包含大量语气词、错别字、重复和逻辑跳跃的话。

你的任务是将其整理成以下四部分，并严格以指定的 JSON 格式返回：
1. "summary": 一篇结构清晰、语句通顺但【严格保持用户原有文风和语气】的整理文。
2. "action_items": 从倾倒内容中提取出来的明确待办事项（如果没有则返回空数组）。
3. "key_insights": 提炼的核心观点、闪光创意或灵感卡片（如果没有则返回空数组）。
4. "calendar_events": 从倾倒内容中识别并提取出的日程/会议安排，包含标题(title)和具体时间(time)（如果没有则返回空数组）。

【关键指令：文风保持 (Tone Keeping)】：
- 用户可能会提供一段“我的文风样例（user_tone_sample）”。你必须深度分析该样例的用词偏好（例如：是否喜欢中英混杂、是否幽默风趣、是否有特定口头禅、句子是短促还是冗长等），并在重组整理文 "summary" 中使用完全一致的风格重建用户的发言。
- 如果用户没有提供文风样例，默认使用生动、自然、真诚且无距离感的口语化风格（绝对不要生成千篇一律的正式商业公文腔）。

你必须严格以 JSON 格式输出，不得包含任何 Markdown 格式包裹（如 ` + "```json" + `），只返回纯 JSON 对象。`

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

	// 解析 JSON 结果
	var processed ProcessedDump
	if err := json.Unmarshal([]byte(resp.Choices[0].Message.Content), &processed); err != nil {
		return nil, fmt.Errorf("failed to parse gpt JSON response: %w (raw response: %s)", err, resp.Choices[0].Message.Content)
	}

	return &processed, nil
}
