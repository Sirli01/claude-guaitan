# MCP 快速开始指南

本指南帮助您快速设置和使用恐怖游戏的 MCP 工具。

## 前提条件

1. Godot 4.6 或更高版本
2. Node.js 和 npm（用于 mcp-remote）
3. Claude Desktop 或其他支持 MCP 的 AI 助手

## 步骤 1: 启用 MCP 插件

1. 打开 Godot 编辑器
2. 进入 **项目 > 项目设置 > 插件**
3. 找到 "Godot MCP Native"
4. 将状态设置为 **启用**

## 步骤 2: 配置 MCP 服务器

1. 在 Godot 编辑器中，点击顶部的 **MCP** 标签页
2. 在右侧面板中配置：
   - **传输模式**: HTTP（推荐）
   - **HTTP 端口**: 9080（默认）
   - **自动启动**: 勾选（可选）
3. 点击 **启动服务器** 按钮

## 步骤 3: 安装 mcp-remote

在终端中运行：

```bash
npm install -g mcp-remote
```

## 步骤 4: 配置 Claude Desktop

### 方法 1: 使用项目配置文件

将项目中的 `claude_desktop_config.json` 文件复制到 Claude Desktop 配置目录：

- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

### 方法 2: 手动配置

在 Claude Desktop 配置文件中添加：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:9080/mcp"
      ]
    }
  }
}
```

## 步骤 5: 测试连接

1. 启动 Godot 项目（或在编辑器中运行）
2. 打开 Claude Desktop
3. 在对话中输入：

```
请使用 MCP 工具获取当前游戏状态
```

Claude 应该会调用 `get_game_state` 工具并返回结果。

## 常见用法示例

### 1. 调试恐怖张力

```
请帮我调试恐怖张力系统。获取当前 Director 状态，然后设置张力到 0.8 并触发高峰事件。
```

### 2. 测试角色系统

```
查看所有角色的生死状态，然后测试角色死亡功能。
```

### 3. 管理物品

```
添加一个测试物品到背包，查看背包内容，然后移除该物品。
```

### 4. 触发恐怖效果

```
播放恐怖音效，同时触发屏幕震动效果。
```

### 5. 保存和加载

```
保存当前游戏到槽位 1，然后加载它。
```

## 故障排除

### 问题: MCP 服务器无法启动

**解决方案**:
1. 检查端口 9080 是否被占用
2. 尝试更改端口号
3. 查看 Godot 控制台的错误信息

### 问题: Claude 无法连接到 MCP 服务器

**解决方案**:
1. 确保 MCP 服务器正在运行
2. 检查 `mcp-remote` 是否正确安装
3. 验证配置文件路径是否正确
4. 重启 Claude Desktop

### 问题: 工具返回错误

**解决方案**:
1. 确保游戏正在运行（某些工具需要运行时环境）
2. 检查 autoload 单例是否正确初始化
3. 查看 Godot 控制台的错误日志

### 问题: 工具不可用

**解决方案**:
1. 确认插件已启用
2. 重新启动 Godot 编辑器
3. 检查工具脚本是否有语法错误

## 高级配置

### 启用身份验证

1. 在 MCP 面板中勾选 **启用认证**
2. 设置 **认证令牌**（至少 16 个字符）
3. 在 Claude Desktop 配置中添加令牌：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:9080/mcp",
        "--header",
        "Authorization: Bearer YOUR_TOKEN_HERE"
      ]
    }
  }
}
```

### 使用命令行参数

启动 Godot 时可以使用以下参数：

```bash
godot --mcp-server --mcp-port=9081 --mcp-transport=http
```

- `--mcp-server`: 自动启动 MCP 服务器
- `--mcp-port=N`: 指定端口号
- `--mcp-transport=TYPE`: 指定传输模式 (http 或 stdio)

### 日志级别

在 MCP 面板中可以设置日志级别：
- **ERROR**: 只显示错误
- **WARN**: 显示警告和错误
- **INFO**: 显示一般信息（推荐）
- **DEBUG**: 显示详细调试信息

## 性能提示

1. **限制工具调用频率**: 避免频繁调用工具，特别是在循环中
2. **使用批量操作**: 如果需要多个操作，考虑使用批量工具
3. **缓存结果**: 对于不常变化的数据，可以缓存工具返回结果
4. **关闭不用的工具**: 在 MCP 面板中禁用不需要的工具可以提高性能

## 安全建议

1. **生产环境**: 始终启用身份验证
2. **令牌管理**: 使用强令牌并定期更换
3. **网络安全**: 不要在公共网络上暴露 MCP 服务器
4. **权限控制**: 根据需要限制工具的访问权限

## 获取帮助

- 查看 [恐怖游戏 MCP 工具文档](horror_game_mcp_tools.md) 了解所有可用工具
- 运行 [测试脚本](../tools/test_mcp_tools.gd) 验证工具功能
- 查看 Godot 控制台的错误日志
- 检查 MCP 面板的状态信息

## 下一步

1. 尝试使用不同的工具组合
2. 探索 Claude 的自然语言能力
3. 创建自定义的工作流程
4. 分享您的使用经验

祝您使用愉快！
