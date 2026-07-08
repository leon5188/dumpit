package handlers

import (
	"net/http"

	"dumpit-backend/services"
	"github.com/labstack/echo/v4"
)

type NotionHandler struct {
	notionService *services.NotionService
}

func NewNotionHandler(notionService *services.NotionService) *NotionHandler {
	return &NotionHandler{
		notionService: notionService,
	}
}

// Sync 接口接收整理结果，并向用户的 Notion 发起同步
func (h *NotionHandler) Sync(c echo.Context) error {
	var req services.NotionSyncRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid request body",
		})
	}

	if req.Token == "" || req.ParentPageID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "notion_token and parent_page_id are required",
		})
	}

	if err := h.notionService.SyncToNotion(req); err != nil {
		return c.JSON(http.StatusBadGateway, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"status":  "ok",
		"message": "Successfully synced restructured data to Notion",
	})
}
