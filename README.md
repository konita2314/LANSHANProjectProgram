# LANSHANProject: An Unrecorded Story 

**火兰山中学** (c) FuncWork Studios

这是《火兰山中学》的程序部分。

使用Godot完成。Godot是一个新兴的游戏引擎，由C++开发，使用GDScript这种解释型语言。

游戏玩法以解密为主，玩家通过解密来推进故事的走向。

UI由 `@konita2314` 和 `@LZJFRRFJRL` 设计。但仍有许多不足之处。

故事来自 `@在下成才` 、 `@灰鱼` 、 `@星诚极光` ，由 `@因心慕芸`、 `@U+25A0*5` 校对和编辑。

程序来自 `@konita2314` 、 `@BAKVAC` 、 `@NCD(dec.)` 、 `@猫猫重度依赖。` 。

音乐来自 `@在下成才` 、 `@Team Tangent` 、 `@YuUkiiz.` 。

美术来自 `@雪夜冰` 、 `@超级无敌高冷大帅哥` 、 `@山楠` 、 `@白洲Azusa` 。

纪念已故的 `@Sakana.iku` 、 `@NCD` 。

## 主要介绍

这是一款解谜游戏，通过搜集证据推理线索。

## 文件结构

```
godot_project/
├── project.godot                 # 项目配置（autoload、输入映射、渲染设置）
├── locale/                       # .po 翻译文件
├── assets/
│   ├── backgrounds/scenes/       # 场景背景
│   ├── backgrounds/menu/         # 菜单背景
│   ├── characters/               # 角色立绘
│   ├── music/                    # BGM
│   ├── sfx/                      # 音效
│   ├── fonts/                    # 字体文件
│   ├── icons/                    # 图标
│   ├── map/                      # 校园地图图片
│   └── about/                    # 关于页素材
├── scenes/
│   ├── autoload/                 # 4 个全局单例
│   ├── ui/                       # BackBar、BackgroundLayer
│   ├── menu/                     # 主菜单、启动画面
│   ├── vn/                       # VN 核心（VNInterface、ChoicesMenu、SaveMenu、LogScreen）
│   ├── tab_menu/                 # 游戏内 Tab 菜单
│   ├── map/                      # 校园交互地图
│   ├── settings/                 # 设置页
│   ├── save_load/                # 存档/读档
│   ├── achievements/             # RewardsScene（Rewards 中心）、AchievementList、AchievementReached
│   ├── gallery/                  # 音乐/场景画廊 + PictureViewer
│   ├── about/                    # 关于页（滚动字幕）
│   ├── registration/             # 新游戏注册页（模拟网页表单）
│   └── modals/                   # QuitModal、OverwriteConfirm
├── scripts/
│   ├── story/                    # 主线剧本（按章节分目录）
│   │   ├── Intro/                # 序章
│   │   ├── Main/                  # M1–M4 主线章节
│   │   │   ├── M1/                  # 第一章（含 Locations/ 地点子剧本）
│   │   │   ├── M2/                  # 第二章
│   │   │   ├── M3/                  # 第三章
│   │   │   └── M4/                  # 第四章
│   │   ├── GL/                   # 角色路线（LinZixin/JiangShixuan/ShiQingwen/…）
│   │   ├── TL/                   # TL 路线
│   │   └── SideStory/            # 支线故事
│   ├── mini/                     # Story_Mini_*.gd（mini VN 专用剧本，由 MINI_STORIES 注册）
│   ├── gallery/                  # SceneGalleryData、MusicGalleryData
│   └── ScriptParser.gd 等       # 数据类和解析器（AchievementsData、AboutText、RegisteredNames…）
├── shaders/                      # blur、crt_effect、pixelate
└── themes/                       # lsp_theme.tres
```
