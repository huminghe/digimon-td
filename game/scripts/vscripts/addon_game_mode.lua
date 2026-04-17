-- 数码守护者 — 游戏模式入口
-- addon_game_mode.lua

if CDigimonTD == nil then
    CDigimonTD = class({})
end

-- 游戏初始化入口（由 Dota 2 引擎调用）
function Activate()
    GameRules.DigimonTD = CDigimonTD()
    GameRules.DigimonTD:InitGameMode()
end

function CDigimonTD:InitGameMode()
    print("[DigimonTD] 游戏模式初始化")

    -- 基础规则设置
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 4)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)
    GameRules:SetHeroSelectionTime(0)
    GameRules:SetPreGameTime(10)
    GameRules:SetShowcaseTime(0)
    GameRules:SetStrategyTime(0)
    GameRules:SetUseUniversalShopMode(true)

    -- 加载子系统
    require("wave_manager")
    require("digimon_manager")
    require("economy")

    -- 初始化子系统（economy 先于其他，因为 digimon_manager 依赖它）
    self.economy        = Economy()
    self.waveManager    = WaveManager()
    self.digimonManager = DigimonManager()

    -- 挂载到 GameRules.DigimonTD，供子系统互相访问
    GameRules.DigimonTD.economy        = self.economy
    GameRules.DigimonTD.waveManager    = self.waveManager
    GameRules.DigimonTD.digimonManager = self.digimonManager

    -- 初始化子系统（顺序：economy → waveManager → digimonManager）
    self.economy:Init()
    self.waveManager:Init()
    self.digimonManager:Init()

    -- 注册游戏事件
    ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnGameRulesStateChange"), self)
    ListenToGameEvent("player_connect_full",     Dynamic_Wrap(self, "OnPlayerConnectFull"),    self)
    ListenToGameEvent("npc_spawned",             Dynamic_Wrap(self, "OnNPCSpawned"),           self)
    ListenToGameEvent("entity_killed",           Dynamic_Wrap(self, "OnEntityKilled"),         self)

    -- 注册玩家自定义指令（Panorama 通过 GameEvents.SendCustomGameEventToServer 触发）
    CustomGameEventManager:RegisterListener("digimon_place",      Dynamic_Wrap(self, "OnPlayerPlaceDigimon"))
    CustomGameEventManager:RegisterListener("digimon_remove",     Dynamic_Wrap(self, "OnPlayerRemoveDigimon"))
    CustomGameEventManager:RegisterListener("digimon_move",       Dynamic_Wrap(self, "OnPlayerMoveDigimon"))
    CustomGameEventManager:RegisterListener("digimon_levelup",    Dynamic_Wrap(self, "OnPlayerLevelUp"))
    CustomGameEventManager:RegisterListener("digimon_skill",      Dynamic_Wrap(self, "OnPlayerSpendSkillPoint"))
    CustomGameEventManager:RegisterListener("digimon_evolve",     Dynamic_Wrap(self, "OnPlayerEvolve"))

    print("[DigimonTD] 初始化完成")
end

-- 游戏状态变化
function CDigimonTD:OnGameRulesStateChange(event)
    local state = GameRules:State_Get()
    if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        print("[DigimonTD] 游戏开始，启动波次管理器")
        self.economy:OnGameStart()
        self.waveManager:StartFirstWave()
    elseif state == DOTA_GAMERULES_STATE_POST_GAME then
        print("[DigimonTD] 游戏结束")
    end
end

-- 玩家连接
function CDigimonTD:OnPlayerConnectFull(event)
    local playerID = event.PlayerID
    print("[DigimonTD] 玩家连接: " .. tostring(playerID))
end

-- 单位生成
function CDigimonTD:OnNPCSpawned(event)
    local unit = EntIndexToHScript(event.entindex)
    if unit == nil then return end
    -- 数码宝贝单位由 DigimonManager:PlaceDigimon 直接处理，此处无需额外操作
end

-- 单位死亡
function CDigimonTD:OnEntityKilled(event)
    local killed = EntIndexToHScript(event.entindex_killed)
    if killed == nil then return end

    if killed:GetTeamNumber() == DOTA_TEAM_BADGUYS then
        local killer = EntIndexToHScript(event.entindex_attacker)
        -- 金币分配走 economy
        self.economy:OnEnemyKilled(killer, killed)
        -- 通知波次管理器
        self.waveManager:OnEnemyKilled(killed)
    end
end

-- =========================================================
-- 玩家指令处理
-- =========================================================

-- 放置数码宝贝
-- event: { PlayerID, slot_index, digimon_key }
function CDigimonTD:OnPlayerPlaceDigimon(event)
    local playerID   = event.PlayerID
    local slotIndex  = tonumber(event.slot_index)
    local digimonKey = event.digimon_key
    self.digimonManager:PlaceDigimon(playerID, slotIndex, digimonKey)
end

-- 移除数码宝贝
-- event: { PlayerID, slot_index }
function CDigimonTD:OnPlayerRemoveDigimon(event)
    local playerID  = event.PlayerID
    local slotIndex = tonumber(event.slot_index)
    self.digimonManager:RemoveDigimon(playerID, slotIndex)
end

-- 移动数码宝贝
-- event: { PlayerID, from_slot, to_slot }
function CDigimonTD:OnPlayerMoveDigimon(event)
    local playerID = event.PlayerID
    local fromSlot = tonumber(event.from_slot)
    local toSlot   = tonumber(event.to_slot)
    self.digimonManager:MoveDigimon(playerID, fromSlot, toSlot)
end

-- 升级数码宝贝
-- event: { PlayerID, slot_index }
function CDigimonTD:OnPlayerLevelUp(event)
    local playerID  = event.PlayerID
    local slotIndex = tonumber(event.slot_index)
    self.digimonManager:LevelUp(playerID, slotIndex)
end

-- 投入技能点
-- event: { PlayerID, slot_index, skill_slot }  skill_slot: "skill1"|"skill2"|"skill3"|"ult"
function CDigimonTD:OnPlayerSpendSkillPoint(event)
    local playerID  = event.PlayerID
    local slotIndex = tonumber(event.slot_index)
    local skillSlot = event.skill_slot
    self.digimonManager:SpendSkillPoint(playerID, slotIndex, skillSlot)
end

-- 进化数码宝贝
-- event: { PlayerID, slot_index, branch_index }  branch_index: 1=A路线, 2=B路线
function CDigimonTD:OnPlayerEvolve(event)
    local playerID   = event.PlayerID
    local slotIndex  = tonumber(event.slot_index)
    local branchIndex = tonumber(event.branch_index) or 1
    self.digimonManager:Evolve(playerID, slotIndex, branchIndex)
end
