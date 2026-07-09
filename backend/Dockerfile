# ---------------------------------------------------
# Stage 1: Build the Go binary
# ---------------------------------------------------
FROM golang:alpine AS builder

# 设置 Go 全球代理加速，并支持 direct 回退，防范网络堵塞超时
ENV GOPROXY=https://goproxy.io,direct

# 安装构建依赖以支持部分 cgo（如需要）
RUN apk add --no-cache git ca-certificates

# 设置工作目录
WORKDIR /app

# 拷贝 go.mod 和 go.sum 并下载依赖 (缓存层)
COPY go.mod go.sum ./
RUN go mod download

# 拷贝全部 Go 源代码
COPY . .

# 编译生成高度优化、无外部依赖的静态 Linux 二进制可执行文件
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

# ---------------------------------------------------
# Stage 2: Final minimal running container
# ---------------------------------------------------
FROM alpine:latest

# 安装 ca-certificates 证书，这对于向 OpenAI / Notion API 发起 HTTPS 外部请求至关重要！
RUN apk --no-cache add ca-certificates tzdata

# 设置工作目录
WORKDIR /root/

# 从构建器中只拷贝编译好的二进制可执行文件
COPY --from=builder /app/main .

# 暴露 Go 后端运行端口
EXPOSE 8080

# 运行二进制程序
CMD ["./main"]
