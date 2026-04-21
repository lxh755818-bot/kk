# image-understanding

> 当用户发送图片、或提到「图片识别」「图片理解」「看图」「分析这张图」时激活。

## 触发条件

收到以下任意一种输入时，无条件激活：
- 图片格式文件（.jpg/.jpeg/.png/.gif/.webp/.bmp 等）
- 用户明确要求「看图」「识别图片」「图片识别」「图片理解」
- 用户说「这是什么」「描述一下」「帮我看看这张图」

## 执行流程

### Step 1：判断图片来源

| 来源 | 路径 |
|------|------|
| 飞书消息中的图片 | 从消息的 `media` 字段或 `image_key` 获取，用 `feishu_im_bot_image` 下载到 `/tmp/openclaw/` |
| 本地已存在的图片 | 直接使用绝对路径 |
| URL 图片 | 先下载到本地 |

### Step 2：调用 image 工具

```typescript
image({
  image: "<绝对路径>",
  prompt: "<描述性分析要求>"
})
```

**prompt 模板：**
- 通用描述：`"详细描述这张图片的所有内容，包括文字、图表、界面元素等"`
- 截图类：`"这是什么页面/界面？列出所有可见元素及其含义"`
- 照片类：`"描述这张照片的内容、场景、氛围"`

### Step 3：返回结果

- 置信度标注（高/中/低）
- 有文字/代码/配置等实质内容时，完整转录
- 不确定的内容明确标注「无法确定」

## 注意事项

- 图片文件建议先复制到 `/tmp/openclaw/` 再处理
- 超大图片（>20MB）建议先压缩
- 若 image 工具超时，等待 30 秒后重试一次（Gateway 重启后模型加载需要时间）
- 飞书私聊图片直接用 media path；群聊图片需先从消息中提取 file_key

## 底层依赖

- OpenClaw 内置 `image` 工具（MiniMax-VL-01 模型驱动）
- 配置文件：`openclaw.json` → `agents.defaults.imageModel`
- 若 image 工具报错 `image model not available`，检查 openclaw.json 中：
  1. `models.providers.minimax.models` 是否包含 `MiniMax-VL-01`（input 含 "image"）
  2. `agents.defaults.imageModel.primary` 是否指向该模型

---

*创建时间：2026-04-21 | 刘大虾*
