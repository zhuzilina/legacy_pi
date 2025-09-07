# 配置文件说明

## 概述

本项目使用配置文件来管理API地址和其他配置信息，避免在代码中硬编码敏感信息。

## 配置文件

### app_config.json
这是实际的配置文件，包含以下内容：
- API基础地址
- 各个服务的端点路径
- 环境配置信息

### app_config.example.json
这是示例配置文件，用于指导开发者如何创建自己的配置文件。

## 使用方法

1. 复制 `app_config.example.json` 为 `app_config.json`
2. 修改 `app_config.json` 中的配置信息，特别是API地址
3. 配置文件会被自动加载，无需重启应用

## 配置项说明

```json
{
  "api": {
    "baseUrl": "http://your-server-ip",  // API服务器地址
    "port": "",                          // 端口号（可选）
    "endpoints": {
      "aiChat": "/api/ai-chat",          // AI对话服务端点
      "aiInterpretation": "/api/ai",     // AI解读服务端点
      "mdDocs": "/api/md-docs",          // MD文档服务端点
      "knowledgeQuiz": "/api/knowledge-quiz", // 知识问答服务端点
      "tts": "/api/tts",                 // 语音合成服务端点
      "crawler": "/api/crawler"          // 爬虫服务端点
    }
  },
  "environment": {
    "isProduction": false,               // 是否为生产环境
    "debugMode": true                    // 是否开启调试模式
  }
}
```

## 注意事项

- `app_config.json` 文件已被添加到 `.gitignore` 中，不会被提交到版本控制系统
- 如果配置文件加载失败，系统会使用默认配置
- 修改配置文件后需要重新构建应用才能生效

## 开发环境配置

对于开发环境，建议使用以下配置：
```json
{
  "api": {
    "baseUrl": "http://localhost:8000",
    "port": "",
    "endpoints": {
      "aiChat": "/api/ai",
      "mdDocs": "/api/md-docs",
      "knowledgeQuiz": "/api/knowledge-quiz",
      "tts": "/api/tts",
      "crawler": "/api/crawler"
    }
  },
  "environment": {
    "isProduction": false,
    "debugMode": true
  }
}
```

## 生产环境配置

对于生产环境，建议使用以下配置：
```json
{
  "api": {
    "baseUrl": "http://your-production-server.com",
    "port": "",
    "endpoints": {
      "aiChat": "/api/ai",
      "mdDocs": "/api/md-docs",
      "knowledgeQuiz": "/api/knowledge-quiz",
      "tts": "/api/tts",
      "crawler": "/api/crawler"
    }
  },
  "environment": {
    "isProduction": true,
    "debugMode": false
  }
}
```
