-- 波次管理器
-- wave_manager.lua

if WaveManager == nil then
    WaveManager = class({})
end

-- =========================================================
-- 常量
-- =========================================================
WaveManager.TOTAL_WAVES   = 40
WaveManager.BOSS_INTERVAL = 5
WaveManager.MAX_LIVES     = 10

-- 波次间隔（秒）
WaveManager.WAVE_INTERVAL      = 30
-- 同波内每个敌人生成间隔（秒）
WaveManager.SPAWN_INTERVAL     = 0.8

-- Boss 掉落材料（波次 -> 数量），与 economy.lua 保持一致
WaveManager.BOSS_SHARD_DROP = {
    [5]=1, [10]=1, [15]=2, [20]=2,
    [25]=3, [30]=3, [35]=4, [40]=4,
}

-- =========================================================
-- 波次配置表
-- 每波：{ count=数量, type=单位名, gold=击杀金币, scale=血量倍率 }
-- Boss 波额外字段：isBoss=true
-- =========================================================
WaveManager.WAVE_CONFIG = {}

-- 辅助：填充普通波次
local function MakeNormalWave(wave)
    local types = { "npc_enemy_basic", "npc_enemy_fast", "npc_enemy_armored", "npc_enemy_magic" }
    -- 波次越高，数量越多，血量倍率越高
    local count = 8 + math.floor(wave * 0.5)
    local scale = 1.0 + (wave - 1) * 0.15
    -- 根据波次解锁敌人种类
    local availableTypes
    if wave <= 5 then
        availableTypes = { types[1] }
    elseif wave <= 10 then
        availableTypes = { types[1], types[2] }
    elseif wave <= 20 then
        availableTypes = { types[1], types[2], types[3] }
    else
        availableTypes = types
    end
    local chosen = availableTypes[RandomInt(1, #availableTypes)]
    return { count = count, unitType = chosen, scale = scale, isBoss = false }
end

-- Boss 单位表（波次 -> 单位名）
local BOSS_UNITS = {
    [5]  = "npc_boss_darktyranomon",
    [10] = "npc_boss_skullgarurumon",
    [15] = "npc_boss_myotismon",
    [20] = "npc_boss_devimon",
    [25] = "npc_boss_myotismon2",
    [30] = "npc_boss_metalseadramon",
    [35] = "npc_boss_darkwargreymon",
    [40] = "npc_boss_apocalymon",
}

-- 预生成 40 波配置
for i = 1, WaveManager.TOTAL_WAVES do
    if i % WaveManager.BOSS_INTERVAL == 0 then
        WaveManager.WAVE_CONFIG[i] = {
            count    = 1,
            unitType = BOSS_UNITS[i],
            scale    = 1.0,
            isBoss   = true,
        }
    else
        WaveManager.WAVE_CONFIG[i] = MakeNormalWave(i)
    end
end

-- =========================================================
-- 初始化
-- =========================================================
function WaveManager:Init()
    self.currentWave    = 0
    self.lives          = WaveManager.MAX_LIVES
    self.isRunning      = false
    self.activeEnemies  = 0   -- 当前波次存活敌人数
    self.spawnQueue     = {}  -- 待生成队列
    self.spawnHandle    = nil -- 生成计时器句柄

    -- 路径点列表（由地图实体 info_target 提供，名称约定 "path_wp_1" ~ "path_wp_N"）
    self.waypoints = self:CollectWaypoints()

    print("[WaveManager] 初始化完成，路径点数量: " .. #self.waypoints)
end

-- 收集地图路径点（实体名 path_wp_1, path_wp_2, ...）
function WaveManager:CollectWaypoints()
    local wps = {}
    local i = 1
    while true do
        local ent = Entities:FindByName(nil, "path_wp_" .. i)
        if ent == nil then break end
        wps[i] = ent:GetAbsOrigin()
        i = i + 1
    end
    -- 兜底：若地图尚未放置路径点，使用占位坐标（Hammer 阶段替换）
    if #wps == 0 then
        print("[WaveManager] 警告：未找到路径点，使用占位坐标")
        wps = {
            Vector(-2000,  2000, 128),
            Vector(-1000,  2000, 128),
            Vector(-1000,  1000, 128),
            Vector( 1000,  1000, 128),
            Vector( 1000, -1000, 128),
            Vector(-1000, -1000, 128),
            Vector(-1000, -2000, 128),
            Vector( 2000, -2000, 128),
        }
    end
    return wps
end

-- =========================================================
-- 波次流程
-- =========================================================

-- 启动第一波（由 addon_game_mode.lua 在游戏开始时调用）
function WaveManager:StartFirstWave()
    if self.isRunning then return end
    self.isRunning = true
    -- 延迟 5 秒后开始第一波，给玩家准备时间
    Timers:CreateTimer(5.0, function()
        self:StartWave(1)
    end)
end

-- 开始指定波次
function WaveManager:StartWave(waveNum)
    if waveNum > WaveManager.TOTAL_WAVES then
        self:OnVictory()
        return
    end

    self.currentWave   = waveNum
    self.activeEnemies = 0

    local cfg = WaveManager.WAVE_CONFIG[waveNum]
    print(string.format("[WaveManager] 第 %d 波开始 — %s x%d", waveNum, cfg.unitType, cfg.count))

    -- 通知 HUD（P7 接入网络表）
    self:BroadcastWaveState()

    -- 构建生成队列
    self.spawnQueue = {}
    for i = 1, cfg.count do
        self.spawnQueue[i] = { unitType = cfg.unitType, scale = cfg.scale, isBoss = cfg.isBoss }
    end

    -- 开始逐个生成
    self:ScheduleNextSpawn()
end

-- 调度下一个敌人生成
function WaveManager:ScheduleNextSpawn()
    if #self.spawnQueue == 0 then return end

    local entry = table.remove(self.spawnQueue, 1)
    self:SpawnEnemy(entry.unitType, entry.scale, entry.isBoss)

    if #self.spawnQueue > 0 then
        Timers:CreateTimer(WaveManager.SPAWN_INTERVAL, function()
            self:ScheduleNextSpawn()
        end)
    end
end

-- =========================================================
-- 敌人生成与路径跟随
-- =========================================================

function WaveManager:SpawnEnemy(unitType, hpScale, isBoss)
    local spawnPos = self.waypoints[1]
    local unit = CreateUnitByName(unitType, spawnPos, true, nil, nil, DOTA_TEAM_BADGUYS)

    if unit == nil then
        print("[WaveManager] 错误：无法生成单位 " .. unitType)
        return
    end

    -- 按波次缩放血量
    if hpScale and hpScale ~= 1.0 then
        local maxHP = unit:GetMaxHealth()
        unit:SetMaxHealth(math.floor(maxHP * hpScale))
        unit:SetHealth(math.floor(maxHP * hpScale))
    end

    -- 标记 Boss
    unit:SetContextThink("digimon_td_is_boss", nil, 0)
    if isBoss then
        unit:AddNewModifier(unit, nil, "modifier_boss_marker", {})
    end

    self.activeEnemies = self.activeEnemies + 1

    -- 启动路径跟随逻辑
    self:StartPathFollow(unit, 2)  -- 从第 2 个路径点开始移动
end

-- 路径跟随：让单位依次移动到每个路径点
function WaveManager:StartPathFollow(unit, nextWpIndex)
    if not unit:IsAlive() then return end

    if nextWpIndex > #self.waypoints then
        -- 到达终点
        self:OnEnemyReachedGoal(unit)
        return
    end

    local target = self.waypoints[nextWpIndex]
    unit:MoveToPosition(target)

    -- 轮询检测是否到达当前路径点（距离 < 100 视为到达）
    -- 固定 key，新 think 会覆盖旧的，避免多个 think 同时运行
    unit:SetContextThink("path_follow", function()
        if not unit:IsAlive() then return nil end
        local dist = (unit:GetAbsOrigin() - target):Length2D()
        if dist < 100 then
            self:StartPathFollow(unit, nextWpIndex + 1)
            return nil  -- 停止此 think
        end
        return 0.1  -- 每 0.1 秒检测一次
    end, 0.1)
end

-- =========================================================
-- 事件处理
-- =========================================================

-- 敌人被击杀（由 addon_game_mode.lua 的 OnEntityKilled 调用）
function WaveManager:OnEnemyKilled(unit)
    self.activeEnemies = self.activeEnemies - 1
    self:CheckWaveComplete()
end

-- 敌人到达终点
function WaveManager:OnEnemyReachedGoal(unit)
    local isBoss = unit:HasModifier("modifier_boss_marker")
    local damage = isBoss and WaveManager.MAX_LIVES or 1

    unit:RemoveSelf()
    self.activeEnemies = self.activeEnemies - 1

    self.lives = self.lives - damage
    print(string.format("[WaveManager] 敌人到达终点！剩余生命: %d", self.lives))

    self:BroadcastWaveState()

    if self.lives <= 0 then
        self:OnDefeat()
        return
    end

    self:CheckWaveComplete()
end

-- 检查当前波次是否全部清除
function WaveManager:CheckWaveComplete()
    if self.activeEnemies > 0 then return end
    if #self.spawnQueue > 0 then return end

    print(string.format("[WaveManager] 第 %d 波清除！", self.currentWave))

    -- Boss 波：通知 economy 掉落材料
    if self:IsBossWave(self.currentWave) then
        if GameRules.DigimonTD and GameRules.DigimonTD.economy then
            GameRules.DigimonTD.economy:OnBossKilled(self.currentWave)
        end
    end

    -- 波次清除金币奖励
    if GameRules.DigimonTD and GameRules.DigimonTD.economy then
        GameRules.DigimonTD.economy:OnWaveCleared(self.currentWave)
    end

    -- 等待间隔后开始下一波
    local nextWave = self.currentWave + 1
    Timers:CreateTimer(WaveManager.WAVE_INTERVAL, function()
        self:StartWave(nextWave)
    end)
end

-- 胜利
function WaveManager:OnVictory()
    self.isRunning = false
    print("[WaveManager] 胜利！所有 40 波已清除！")
    GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
end

-- 失败
function WaveManager:OnDefeat()
    self.isRunning = false
    print("[WaveManager] 失败！生命值耗尽！")
    GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
end

-- =========================================================
-- 工具函数
-- =========================================================

function WaveManager:IsBossWave(waveNum)
    return waveNum % WaveManager.BOSS_INTERVAL == 0
end

-- 广播游戏状态到网络表
function WaveManager:BroadcastWaveState()
    CustomNetTables:SetTableValue("digimon_td_game_state", "wave", {
        current = self.currentWave,
        total   = WaveManager.TOTAL_WAVES,
        lives   = self.lives,
    })
end
