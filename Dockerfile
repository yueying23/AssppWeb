# ==========================================
# ASSPP Web - Dockerfile
# 多阶段构建，优化镜像大小和构建速度
# ==========================================

# Stage 1: 构建前端
FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend

# 复制依赖文件并安装（利用Docker缓存层）
COPY src/frontend/package*.json ./
RUN npm ci --frozen-lockfile

# 复制源代码并构建
COPY src/frontend/ ./
RUN npm run build

# Stage 2: 构建后端
FROM node:20-alpine AS backend-build

# 安装编译原生模块所需的依赖
RUN apk add --no-cache python3 make g++

WORKDIR /app/backend

# 复制依赖文件并安装
COPY src/backend/package*.json ./
RUN npm ci --frozen-lockfile

# 复制源代码并构建
COPY src/backend/ ./
RUN npm run build

# Stage 3: 生产运行环境
FROM node:20-alpine AS production

# 安装运行时依赖（zip用于IPA处理）
RUN apk add --no-cache zip

# 设置工作目录
WORKDIR /app

# 从构建阶段复制产物
COPY --from=backend-build /app/backend/dist ./dist
COPY --from=backend-build /app/backend/node_modules ./node_modules
COPY --from=backend-build /app/backend/package.json ./
COPY --from=frontend-build /app/frontend/dist ./public

# 创建数据目录并设置权限
RUN mkdir -p /data/packages && \
    chmod -R 755 /data

# 暴露端口
EXPOSE 8080

# 构建信息（通过构建参数传入）
ARG BUILD_COMMIT=unknown
ARG BUILD_DATE=unknown

# 环境变量配置
ENV NODE_ENV=production \
    DATA_DIR=/data \
    PORT=8080 \
    BUILD_COMMIT=$BUILD_COMMIT \
    BUILD_DATE=$BUILD_DATE

# Note: JWT_SECRET and ACCESS_PASSWORD should be set at runtime via docker-compose or -e flag
# Do NOT set default values here for security reasons

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1

# 启动应用
CMD ["node", "dist/index.js"]