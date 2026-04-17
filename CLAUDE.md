# 数码守护者 (Digimon Tower Defense) — CLAUDE.md

## 项目概述

Dota 2 自定义地图，1-4 人合作塔防。玩家放置数码宝贝作为防御塔，阻止敌人沿 S 型路线到达终点。完整 GDD 见 `GDD.md`。

## 技术栈

- **引擎**：Dota 2 Workshop Tools（Valve Source 2）
- **脚本**：Lua（服务端逻辑）
- **UI**：Panorama（JavaScript + XML + CSS）
- **数据**：KeyValues（.txt 格式，类 JSON）
- **版本控制**：Git，远程仓库 `git@github.com:huminghe/digimon-td.git`

## 目录结构

```
digimon-td/
├── CLAUDE.md                          # 本文件
├── GDD.md                             # 游戏设计文档
├── custom_net_tables.txt              # 网络表定义
├── content/panorama/                  # UI 资源
│   ├── layout/custom_game/hud.xml
│   ├── scripts/custom_game/hud.js
│   └── styles/custom_game/hud.css
└── game/
    ├── gamemode/addon_game_mode.txt   # 游戏模式声明
    ├── resource/addon_english.txt     # 本地化文本
    └── scripts/
        ├── npc/
        │   ├── npc_units_custom.txt   # 单位 KV 定义
        │   └── npc_abilities_custom.txt # 技能 KV 定义
        └── vscripts/
            ├── addon_game_mode.lua    # 游戏入口，事件注册
            ├── wave_manager.lua       # 波次系统
            ├── digimon_manager.lua    # 数码宝贝放置/进化/升级
            ├── economy.lua            # 金币/碎片经济系统
            └── abilities/
                └── agumon.lua         # 亚古兽系全形态技能逻辑
```

## 核心系统

### 子系统初始化顺序
`economy` → `wave_manager` → `digimon_manager`

### 自定义事件（Panorama → Server）
| 事件名 | 参数 | 说明 |
|--------|------|------|
| `digimon_place` | slot_index, digimon_key | 放置数码宝贝 |
| `digimon_remove` | slot_index | 移除 |
| `digimon_move` | from_slot, to_slot | 移动 |
| `digimon_levelup` | slot_index | 升级（消耗金币） |
| `digimon_skill` | slot_index, skill_slot | 投入技能点 |
| `digimon_evolve` | slot_index, branch_index | 进化（消耗碎片） |

### 网络表
| 表名 | 用途 |
|------|------|
| `digimon_td_game_state` | 波次、生命值、碎片数量 |
| `digimon_td_player_data` | 玩家金币、槽位 |
| `digimon_td_digimon_data` | 数码宝贝等级、进化阶段、技能等级 |

## 命名规范

- **单位**：`npc_digimon_{key}`（如 `npc_digimon_agumon`）
- **技能**：`digimon_{key}_{slot}`（如 `digimon_agumon_skill1`、`digimon_agumon_ult`）
- **Modifier**：`modifier_{key}_{effect}`（如 `modifier_agumon_burn`）
- **技能 Lua 函数**：`{FormName}_{Slot}`（如 `Greymon_Skill1`、`WarGreymon_Ult`）
- **digimonKey**：小写英文（如 `agumon`、`greymon`、`metalgreymon`）

## 亚古兽系进化树（已实现）

```
agumon → greymon → metalgreymon → wargreymon（A1）
                               → metalseadramon（A2）
                 → skullgreymon（B，死路，数值+25%）
```

- 进化条件：15 级 + 碎片（成熟1、完全2、究极3）
- skill3 光环全形态共用 `digimon_agumon_skill3`，进化后等级保留

## 经济数值

| 项目 | 数值 |
|------|------|
| 初始金币 | 200 |
| 初始碎片 | 2 |
| 升级费用 | 50 × 当前等级 |
| 最高等级 | 15 |
| 波次奖励 | 50 + 波次×5 金币/人 |
| 移动费用 | 100 金币 |

## 开发约定

- 代码注释语言：中文
- 每个技能 KV 对应 `abilities/` 下的同名 Lua 函数
- 新增数码宝贝时：① 单位 KV → ② 技能 KV → ③ Lua 逻辑 → ④ 进化树注册 → ⑤ 本地化
- 死路进化（B路线）数值比同阶段 A 路线高 25%

## 当前进度

| 阶段 | 状态 |
|------|------|
| P0 项目骨架 | ✅ 完成 |
| P1 波次系统 | ✅ 完成 |
| P2 放置系统 | ✅ 完成 |
| P3 亚古兽技能 | ✅ 完成 |
| P4 亚古兽进化 | ✅ 完成 |
| P5 经济系统 | ✅ 完成 |
| Hammer 地图 | ⏳ 待搭建（Windows） |
| P6 其余7只数码宝贝 | ⏳ 待开发 |
| P7 HUD UI | ⏳ 待开发 |
