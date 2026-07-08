package main

import (
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"dumpit-backend/handlers"
	"dumpit-backend/services"
)

func main() {
	// 加载环境变量，如果在本地运行没有 .env，将跳过并使用系统默认环境变量
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// 初始化服务层与处理器
	openAIService := services.NewOpenAIService()
	notionService := services.NewNotionService()

	audioHandler := handlers.NewAudioHandler(openAIService)
	notionHandler := handlers.NewNotionHandler(notionService)

	// 初始化 Echo 实例
	e := echo.New()

	// 注册全局中间件
	e.Use(middleware.Logger())  // 日志记录
	e.Use(middleware.Recover()) // 异常恢复防止程序崩溃

	// 配置 CORS，允许开发环境下本地以及局域网跨域
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAuthorization},
	}))

	// 基础路由：健康检查
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]string{
			"status":  "ok",
			"message": "DumpIt & KeepIt API is running",
		})
	})

	// 核心业务路由
	e.POST("/api/process-audio", audioHandler.UploadAndProcessAudio)
	e.POST("/api/notion/sync", notionHandler.Sync)
	e.POST("/api/license/verify", handlers.VerifyLicenseHandler)

	// 获取端口配置，默认使用 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 启动服务器
	e.Logger.Fatal(e.Start(":" + port))
}
