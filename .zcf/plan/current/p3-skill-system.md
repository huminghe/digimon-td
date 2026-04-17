# P3 技能系统 + 升级

## 任务目标
实现8只成长期完整技能（32个）、技能Lua逻辑、升级/技能点系统。

## 文件清单
- game/scripts/npc/npc_abilities_custom.txt          ← 32个技能KV定义
- game/scripts/vscripts/abilities/agumon.lua         ← 亚古兽技能逻辑
- game/scripts/vscripts/abilities/gabumon.lua        ← 加布兽技能逻辑
- game/scripts/vscripts/abilities/biyomon.lua        ← 比丘兽技能逻辑
- game/scripts/vscripts/abilities/tentomon.lua       ← 甲虫兽技能逻辑
- game/scripts/vscripts/abilities/palmon.lua         ← 巴鲁兽技能逻辑
- game/scripts/vscripts/abilities/gomamon.lua        ← 哥玛兽技能逻辑
- game/scripts/vscripts/abilities/patamon.lua        ← 巴达兽技能逻辑
- game/scripts/vscripts/abilities/gatomon.lua        ← 迪路兽技能逻辑
- game/scripts/vscripts/digimon_manager.lua          ← 补充LevelUp/SpendSkillPoint
- game/scripts/vscripts/addon_game_mode.lua          ← 注册升级/技能事件
- game/resource/addon_english.txt                    ← 技能名称本地化

## 状态
执行中
