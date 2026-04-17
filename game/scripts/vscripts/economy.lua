-- 经济系统
-- economy.lua

if Economy == nil then
    Economy = class({})
end

-- =========================================================
-- 常量
-- =========================================================

-- Boss 掉落碎片数量（波次 -> 数量）
Economy.BOSS_SHARD_DROP = {
    [5]  = 1, [10] = 1,
    [15] = 2, [20] = 2,
    [25] = 3, [30] = 3,
    [35] = 4, [40] = 4,
}

-- 初始金币
Economy.STARTING_GOLD   = 200
-- 初始碎片（给玩家开局就能放 2 只数码宝贝）
Economy.STARTING_SHARDS = 2
-- 每波结束奖励金币（全队每人）
Economy.WAVE_CLEAR_GOLD = 50

-- 敌人击杀金币（单位 KV 里的 WaveGoldReward 字段，此处作为兜底）
Economy.KILL_GOLD_FALLBACK = 10

-- =========================================================
-- 初始化
-- =========================================================

function Economy:Init()
    self.sharedShards = Economy.STARTING_SHARDS
    -- 初始金币在游戏正式开始时发放（OnGameRulesStateChange → GAME_IN_PROGRESS）
    self:SyncNetTable()
    print("[Economy] 初始化完成，初始碎片: " .. self.sharedShards)
end

-- 游戏开始时给所有玩家发放初始金币（由 addon_game_mode 在 GAME_IN_PROGRESS 时调用）
function Economy:OnGameStart()
    for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(i) and
           PlayerResource:GetTeam(i) == DOTA_TEAM_GOODGUYS then
            PlayerResource:SetGold(i, Economy.STARTING_GOLD, false)
        end
    end
    print("[Economy] 初始金币已发放: " .. Economy.STARTING_GOLD .. "/人")
end

-- =========================================================
-- 碎片操作
-- =========================================================

-- 消耗碎片，返回 true=成功 / false=不足
function Economy:SpendShards(amount)
    if self.sharedShards < amount then return false end
    self.sharedShards = self.sharedShards - amount
    self:SyncNetTable()
    return true
end

-- 增加碎片（退还 / Boss 奖励）
function Economy:AddShards(amount)
    self.sharedShards = self.sharedShards + amount
    self:SyncNetTable()
    print("[Economy] +碎片 " .. amount .. "，当前: " .. self.sharedShards)
end

-- Boss 被击杀时掉落碎片
function Economy:OnBossKilled(waveNum)
    local amount = Economy.BOSS_SHARD_DROP[waveNum] or 0
    if amount > 0 then
        self:AddShards(amount)
        print("[Economy] 第" .. waveNum .. "波 Boss 掉落 " .. amount .. " 碎片")
    end
end

-- =========================================================
-- 金币操作
-- =========================================================

-- 给单个玩家发金币
function Economy:GiveGold(playerID, amount, reason)
    if not PlayerResource:IsValidPlayerID(playerID) then return end
    PlayerResource:ModifyGold(playerID, amount, false, reason or 0)
end

-- 给全队所有玩家发金币
function Economy:GiveGoldToAll(amount, reason)
    for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(i) and
           PlayerResource:GetTeam(i) == DOTA_TEAM_GOODGUYS then
            self:GiveGold(i, amount, reason)
        end
    end
end

-- 敌人被击杀时分配金币
-- killer: 击杀单位的 handle（可为 nil，如毒伤死亡）
-- killed: 被击杀的敌人 handle
function Economy:OnEnemyKilled(killer, killed)
    -- 读取单位 KV 里的 WaveGoldReward（通过 KeyValues 获取）
    local reward = Economy.KILL_GOLD_FALLBACK
    local kv = killed:GetUnitName() and
               GameRules:GetCustomGameSettingsTable() -- 兜底，实际从 KV 读
    -- 简化：直接用单位名查预设奖励表
    local UNIT_GOLD = {
        npc_enemy_basic   = 10,
        npc_enemy_fast    = 8,
        npc_enemy_armored = 15,
        npc_enemy_magic   = 12,
    }
    reward = UNIT_GOLD[killed:GetUnitName()] or Economy.KILL_GOLD_FALLBACK

    -- Boss 不给金币（碎片已在 OnBossKilled 处理）
    if killed:HasModifier("modifier_boss_marker") then return end

    -- 优先给击杀者，若无击杀者则全队平分
    if killer and killer:IsRealHero() then
        self:GiveGold(killer:GetPlayerID(), reward, 0)
    else
        -- 全队平分（向下取整）
        local playerCount = 0
        for i = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(i) and
               PlayerResource:GetTeam(i) == DOTA_TEAM_GOODGUYS then
                playerCount = playerCount + 1
            end
        end
        if playerCount > 0 then
            local share = math.floor(reward / playerCount)
            self:GiveGoldToAll(share, 0)
        end
    end
end

-- 波次清除奖励（全队）
function Economy:OnWaveCleared(waveNum)
    local bonus = Economy.WAVE_CLEAR_GOLD + waveNum * 5
    self:GiveGoldToAll(bonus, 0)
    print("[Economy] 第" .. waveNum .. "波清除奖励: +" .. bonus .. " 金币/人")
end

-- =========================================================
-- 网络表同步（让 HUD 读到最新数据）
-- =========================================================

function Economy:SyncNetTable()
    CustomNetTables:SetTableValue("digimon_td_game_state", "economy", {
        shards = self.sharedShards,
    })
end
