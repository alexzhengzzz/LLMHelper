# 配置文件说明

## 如何设置配置文件

1. 复制 `config.json.template` 为 `config.json`：
```bash
cp config.json.template config.json
```

2. 编辑 `config.json`，将 `YOUR_SERVER_IP` 替换为实际的服务器IP地址

3. 配置示例：
```json
{
  "server": {
    "baseUrl": "http://YOUR_SERVER_IP:8080/api",
    "wsUrl": "ws://YOUR_SERVER_IP:8080/api/ws", 
    "searchUrl": "http://YOUR_SERVER_IP:8080"
  }
}
```

## 注意事项
- `config.json` 文件已添加到 `.gitignore`，不会被提交到版本控制
- 请根据实际部署环境修改服务器地址
- 开发环境和生产环境请使用不同的配置文件