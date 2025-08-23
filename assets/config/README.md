# Journey页面配置说明

## 配置文件结构

`journey_config.json` 文件用于配置Journey页面的按钮和图片关联关系。

### 配置项说明

#### 全局配置
- `containerHeight`: 容器总高度（像素）
- `buttonSpacing`: 按钮之间的间距（像素）
- `buttonMargin`: 按钮边距（像素）
- `marginRatio`: 左右边距比例（相对于屏幕宽度）

#### 按钮配置数组
每个按钮包含以下属性：
- `id`: 按钮唯一标识
- `yPosition`: Y轴坐标位置
- `imageGroupPath`: 图片组目录路径
- `activeImageName`: 激活时显示的图片名称
- `imageGroupId`: 图片组编号
- `description`: 按钮描述

### 配置示例

```json
{
  "containerHeight": 11500,
  "buttonSpacing": 115,
  "buttonMargin": 50,
  "marginRatio": 0.25,
  "buttons": [
    {
      "id": 1,
      "yPosition": 11675,
      "imageGroupPath": "assets/images/journey/img1",
      "activeImageName": "D.png",
      "imageGroupId": 1,
      "description": "第一个里程碑"
    }
  ]
}
```

### 工作原理

1. **按钮激活**: 当用户积分达到某个阈值时，对应的按钮会被激活
2. **图片组管理**: 激活的按钮会将图片添加到对应的图片组中
3. **共享组号**: 多个按钮可以共享同一个图片组号，指向同一个图片组
4. **持续堆叠**: 图片会持续堆叠，不会移除旧的图片
5. **层级显示**: 最新激活的图片显示在最上层
6. **动态布局**: 图片按照原始比例自动调整高度和位置

### 添加新图片

1. 创建图片组目录：`assets/images/journey/imgX/`
2. 将图片文件放入对应的图片组目录，命名为 `A.png`、`B.png`、`C.png`、`D.png`
3. 在配置文件中添加对应的按钮配置
4. 确保图片组路径和图片名称正确
5. 重启应用或重新加载配置

### 图片组结构示例

```
assets/images/journey/
├── img1/
│   ├── A.png
│   ├── B.png
│   ├── C.png
│   └── D.png
├── img2/
│   ├── A.png
│   ├── B.png
│   ├── C.png
│   └── D.png
└── ...
```

### 注意事项

- 图片组路径必须以 `assets/images/journey/` 开头
- 图片将按照原始比例显示，无需设置高度
- 多个按钮可以共享同一个图片组号
- 图片会持续堆叠，不会移除旧的图片
- 图片按激活顺序叠放，最新激活的在最上层
- 按钮ID必须唯一
- Y轴坐标应该按照从大到小的顺序排列
