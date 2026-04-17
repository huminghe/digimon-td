# P1 波次系统 + 敌人生成

## 任务目标
实现完整的波次循环、敌人生成、路径跟随、生命值扣减、胜负判定。

## 文件清单
- game/scripts/vscripts/wave_manager.lua     ← 核心实现
- game/scripts/npc/npc_units_custom.txt      ← 补充敌人单位
- game/scripts/vscripts/addon_game_mode.lua  ← 接入波次管理器
- game/resource/addon_english.txt            ← 补充本地化

## 波次配置
- 40 波，每 5 波一个 Boss
- 失败：敌人到达终点累计 10 次（Boss 直接 10 次）
- 胜利：撑过第 40 波

## 状态
执行中
