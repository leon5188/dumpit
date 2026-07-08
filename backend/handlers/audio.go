package handlers

import (
	"context"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"dumpit-backend/services"
	"github.com/labstack/echo/v4"
)

type AudioHandler struct {
	openAIService *services.OpenAIService
}

func NewAudioHandler(openAIService *services.OpenAIService) *AudioHandler {
	return &AudioHandler{
		openAIService: openAIService,
	}
}

// UploadAndProcessAudio 处理音频文件上传并调用 AI 进行整理
func (h *AudioHandler) UploadAndProcessAudio(c echo.Context) error {
	ctx, cancel := context.WithTimeout(c.Request().Context(), 2*time.Minute) // 给予充足的 API 交互超时时间
	defer cancel()

	// 1. 获取上传的音频文件
	file, err := c.FormFile("audio")
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Failed to get audio file from form-data (key should be 'audio')",
		})
	}

	src, err := file.Open()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to open uploaded file",
		})
	}
	defer src.Close()

	// 2. 创建临时文件夹存储上传的音频（Whisper API 需要本地物理文件路径）
	tempDir := "./temp_uploads"
	if err := os.MkdirAll(tempDir, os.ModePerm); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create local temp directory",
		})
	}

	// 随机命名临时文件防止冲突，保留原始扩展名
	ext := filepath.Ext(file.Filename)
	if ext == "" {
		ext = ".wav" // 默认扩展名
	}
	tempFileName := filepath.Join(tempDir, filepath.Base(file.Filename))
	dst, err := os.Create(tempFileName)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create temp audio file on server",
		})
	}
	defer dst.Close()

	// 拷贝文件内容到临时文件
	if _, err = io.Copy(dst, src); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to save audio file to local storage",
		})
	}

	// 【安全措施】：在处理完毕（或中途出错退出）后，务必在后台删除该临时物理文件，防止服务器存储空间暴涨
	defer func() {
		dst.Close() // 显式关闭，确保文件锁释放后再删除
		os.Remove(tempFileName)
	}()

	// 3. 读取表单中的其他配置参数
	userToneSample := c.FormValue("user_tone_sample") // 用户风格文样例
	customPrompt := c.FormValue("custom_prompt")     // 额外大模型处理要求

	// 4. 调用 Whisper 翻译音频
	rawText, err := h.openAIService.TranscribeAudio(ctx, tempFileName)
	if err != nil {
		return c.JSON(http.StatusBadGateway, map[string]string{
			"error": err.Error(),
		})
	}

	// 如果 Whisper 转录出空文本，直接返回
	if rawText == "" {
		return c.JSON(http.StatusOK, services.ProcessedDump{
			Summary:     "未检测到明显的语音内容，请重新录音倾倒。",
			ActionItems: []string{},
			KeyInsights: []string{},
		})
	}

	// 5. 调用 GPT 重组并克隆语气
	result, err := h.openAIService.RestructureDump(ctx, rawText, userToneSample, customPrompt)
	if err != nil {
		return c.JSON(http.StatusBadGateway, map[string]string{
			"error": err.Error(),
		})
	}

	// 6. 返回最终的 JSON 数据
	return c.JSON(http.StatusOK, result)
}
