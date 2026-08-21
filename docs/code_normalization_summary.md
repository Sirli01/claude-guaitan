# 代码规范化总结

## 已完成的修复

### 1. save_manager.gd - 通知系统
**问题**: 动态创建 CanvasLayer 和 Label 节点，硬编码 UI 属性
**修复**:
- 创建了 `scenes/ui/notification.tscn` 通知场景
- 修改 `_show_notification()` 函数使用场景实例化
- 移除了硬编码的 UI 属性（font_size, font_color 等）

## 需要修复的问题

### 1. screen_effects.gd - 屏幕特效系统
**问题**: 动态创建 ColorRect、AudioStreamPlayer 等节点
**状态**: 特殊情况 - 需要保持动态创建
**原因**: 这是一个全局特效系统，需要在运行时动态管理效果节点
**建议**: 保持现状，但添加详细注释说明为什么需要动态创建

### 2. editor 脚本（@tool 脚本）
**问题**: 动态创建节点用于编辑器可视化
**状态**: 特殊情况 - 需要保持动态创建
**原因**: @tool 脚本需要在编辑器中动态创建可视化元素
**涉及文件**:
- `scripts/editor/GameCeiling.gd`
- `scripts/editor/GameContainer.gd`
- `scripts/editor/FloorZone.gd`
- `scripts/editor/GameDoor.gd`
- `scripts/editor/GameDecorRect.gd`
- `scripts/editor/GameFurniture.gd`
- `scripts/editor/GameNPC.gd`
- `scripts/editor/GamePickup.gd`
- `scripts/editor/GameWall.gd`
- `scripts/editor/RoomLight.gd`

**建议**: 保持现状，但添加详细注释说明为什么需要动态创建

### 3. autoload 脚本
**问题**: 动态创建音频播放器等节点
**状态**: 特殊情况 - 需要保持动态创建
**原因**: autoload 脚本需要在运行时动态管理全局资源
**涉及文件**:
- `scripts/autoload/audio_manager.gd` - 动态创建 AudioStreamPlayer
- `scripts/autoload/transition_manager.gd` - 动态创建 CanvasLayer 和 ColorRect

**建议**: 保持现状，但添加详细注释说明为什么需要动态创建

## 规范化建议

### 1. 对于 UI 相关代码
- ✅ 使用 Theme 资源控制样式
- ✅ 使用场景文件定义 UI 结构
- ❌ 避免硬编码 UI 属性

### 2. 对于 @tool 脚本
- ✅ 动态创建节点用于编辑器可视化
- ✅ 添加详细注释说明原因
- ✅ 确保节点在运行时正确清理

### 3. 对于 autoload 脚本
- ✅ 动态创建全局资源节点
- ✅ 添加详细注释说明原因
- ✅ 确保资源在退出时正确释放

### 4. 对于游戏逻辑脚本
- ✅ 使用场景文件定义游戏对象
- ❌ 避免动态创建游戏对象节点
- ✅ 使用组件模式（Composition）而非继承

## 下一步行动

### 1. 添加函数注释
为所有函数添加文档注释，说明：
- 函数功能
- 参数含义
- 返回值

### 2. 检查代码风格
确保所有代码符合 GDScript 风格指南：
- snake_case 函数/变量
- PascalCase 类名
- 类型注解

### 3. 测试修复后的功能
- 测试通知系统
- 测试屏幕特效
- 测试编辑器工具

## 总结

大部分动态创建节点的代码都是合理的，因为：
1. **@tool 脚本**需要在编辑器中动态创建可视化元素
2. **autoload 脚本**需要在运行时动态管理全局资源
3. **特效系统**需要动态创建和管理效果节点

主要修复的是 **UI 硬编码样式问题**，通过使用 Theme 资源和场景文件来解决。
