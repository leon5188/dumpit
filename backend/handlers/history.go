package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"

	"dumpit-backend/db"
)

// CreateHistoryRequest 客户端新建一条云端历史记录的请求体
type CreateHistoryRequest struct {
	Summary json.RawMessage `json:"summary"`
	RawText string          `json:"raw_text"`
}

// CreateHistoryHandler 为当前登录账号新建一条历史记录
func CreateHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	var req CreateHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if len(req.Summary) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "summary is required"})
	}

	id, err := db.CreateHistoryRecord(c.Request().Context(), uid, req.Summary, req.RawText)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save history record: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true, "id": id})
}

// ImportHistoryItem 是批量导入请求里的一条本地记录
type ImportHistoryItem struct {
	ClientID string          `json:"client_id"`
	Summary  json.RawMessage `json:"summary"`
	RawText  string          `json:"raw_text"`
}

// ImportHistoryRequest 首次登录批量导入本地历史的请求体
type ImportHistoryRequest struct {
	Records []ImportHistoryItem `json:"records"`
}

// ImportHistoryHandler 首次登录批量导入本地历史记录；单条失败不影响其余记录导入
func ImportHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	var req ImportHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}

	type importedRecord struct {
		ClientID string `json:"client_id"`
		ServerID string `json:"server_id"`
	}

	imported := make([]importedRecord, 0, len(req.Records))
	failed := make([]string, 0)

	for _, item := range req.Records {
		if len(item.Summary) == 0 {
			failed = append(failed, item.ClientID)
			continue
		}
		serverID, err := db.CreateHistoryRecord(c.Request().Context(), uid, item.Summary, item.RawText)
		if err != nil {
			failed = append(failed, item.ClientID)
			continue
		}
		imported = append(imported, importedRecord{ClientID: item.ClientID, ServerID: serverID})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":  true,
		"imported": imported,
		"failed":   failed,
	})
}

// ListHistoryHandler 增量拉取当前账号的历史记录；?since=<RFC3339> 不传则返回全部
func ListHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)

	since := time.Time{}
	if raw := c.QueryParam("since"); raw != "" {
		parsed, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			return c.JSON(http.StatusBadRequest, map[string]string{"error": "since must be RFC3339 formatted"})
		}
		since = parsed
	}

	records, err := db.ListHistoryRecords(c.Request().Context(), uid, since)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to list history records: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true, "records": records})
}

// PatchHistoryRequest 更新某条历史记录归档状态的请求体
type PatchHistoryRequest struct {
	Archived *bool `json:"archived"`
}

// PatchHistoryHandler 更新某条历史记录的归档状态
func PatchHistoryHandler(c echo.Context) error {
	uid := UIDFromContext(c)
	id := c.Param("id")

	var req PatchHistoryRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body"})
	}
	if req.Archived == nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "archived field is required"})
	}

	if err := db.SetArchived(c.Request().Context(), uid, id, *req.Archived); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update history record: " + err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{"success": true})
}
