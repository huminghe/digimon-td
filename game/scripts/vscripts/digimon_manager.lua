-- 数码宝贝管理器
-- digimon_manager.lua

if DigimonManager == nil then
    DigimonManager = class({})
end

-- =========================================================
-- 常量
-- =========================================================

-- 进化阶段
DigimonManager.STAGE_BABY    = 0  -- 成长期
DigimonManager.STAGE_CHILD   = 1  -- 成熟期
DigimonManager.STAGE_ADULT   = 2  -- 完全体
DigimonManager.STAGE_PERFECT = 3  -- 究极体

-- 进化材料消耗
DigimonManager.EVOLVE_COST = {
    [0] = 1,  -- 建造（成长期）
    [1] = 1,  -- 成长 → 成熟
    [2] = 2,  -- 成熟 → 完全
    [3] = 3,  -- 完全 → 究极
}

-- 移动消耗金币
DigimonManager.MOVE_GOLD_COST = 100

-- 最大槽位数
DigimonManager.MAX_SLOTS = 30

-- =========================================================
-- 进化路线表
-- 格式：[当前单位key] = { { key, unitName, branch_label }, ... }
-- 成长期→成熟期只有一条路，成熟期起有分支
-- =========================================================
DigimonManager.EVOLVE_TREE = {
    -- 亚古兽系
    agumon = {
        { key = "greymon",      unit = "npc_digimon_greymon",      label = "暴龙兽" }
    },
    greymon = {
        { key = "metalgreymon", unit = "npc_digimon_metalgreymon",  label = "机械暴龙兽（A）" },
        { key = "skullgreymon", unit = "npc_digimon_skullgreymon",  label = "丧尸暴龙兽（B·死路）" },
    },
    metalgreymon = {
        { key = "wargreymon",      unit = "npc_digimon_wargreymon",      label = "战斗暴龙兽（A1）" },
        { key = "metalseadramon",  unit = "npc_digimon_metalseadramon",  label = "电光暴龙兽（A2）" },
    },
    -- 死路：无后续进化
    skullgreymon    = {},
    wargreymon      = {},
    metalseadramon  = {},
}

-- 进化碎片消耗（按进化后阶段）
DigimonManager.EVOLVE_SHARD_COST = {
    [DigimonManager.STAGE_CHILD]   = 1,  -- 成长→成熟
    [DigimonManager.STAGE_ADULT]   = 2,  -- 成熟→完全
    [DigimonManager.STAGE_PERFECT] = 3,  -- 完全→究极
}

-- 8 只数码宝贝的成长期单位名
DigimonManager.BABY_UNIT = {
    agumon  = "npc_digimon_agumon",
    gabumon = "npc_digimon_gabumon",
    biyomon = "npc_digimon_biyomon",
    tentomon= "npc_digimon_tentomon",
    palmon  = "npc_digimon_palmon",
    gomamon  = "npc_digimon_gomamon",
    patamon = "npc_digimon_patamon",
    gatomon  = "npc_digimon_gatomon",
}

-- =========================================================
-- 初始化
-- =========================================================

function DigimonManager:Init()
    -- 槽位表：{ [slotIndex] = { pos=Vector, occupied=bool } }
    self.slots = {}
    -- 数码宝贝数据表：{ [slotIndex] = DigimonData }
    self.digimonData = {}

    self:CollectSlots()
    print("[DigimonManager] 初始化完成，槽位数量: " .. #self.slots)
end

-- 收集地图槽位实体（命名约定：digimon_slot_1 ~ digimon_slot_N）
function DigimonManager:CollectSlots()
    local i = 1
    while i <= DigimonManager.MAX_SLOTS do
        local ent = Entities:FindByName(nil, "digimon_slot_" .. i)
        if ent == nil then break end
        self.slots[i] = { pos = ent:GetAbsOrigin(), occupied = false }
        i = i + 1
    end
    -- 兜底：地图未放置槽位时生成占位格（Hammer 阶段替换）
    if #self.slots == 0 then
        print("[DigimonManager] 警告：未找到槽位实体，使用占位坐标")
        local placeholderPositions = {
            Vector(-1800, 1800, 128), Vector(-1400, 1800, 128), Vector(-1000, 1800, 128),
            Vector(-600,  1800, 128), Vector(-200,  1800, 128), Vector( 200,  1800, 128),
            Vector(-1800, 1200, 128), Vector(-1400, 1200, 128), Vector(-1000, 1200, 128),
            Vector(-600,  1200, 128), Vector(-200,  1200, 128), Vector( 200,  1200, 128),
            Vector(-1800,  600, 128), Vector(-1400,  600, 128), Vector(-1000,  600, 128),
            Vector(-600,   600, 128), Vector(-200,   600, 128), Vector( 200,   600, 128),
            Vector(-1800,    0, 128), Vector(-1400,    0, 128), Vector(-1000,    0, 128),
            Vector(-600,     0, 128), Vector(-200,     0, 128), Vector( 200,     0, 128),
            Vector(-1800, -600, 128), Vector(-1400, -600, 128), Vector(-1000, -600, 128),
            Vector(-600,  -600, 128), Vector(-200,  -600, 128), Vector( 200,  -600, 128),
        }
        for idx, pos in ipairs(placeholderPositions) do
            self.slots[idx] = { pos = pos, occupied = false }
        end
    end
end

-- =========================================================
-- 放置数码宝贝
-- =========================================================

-- playerID: 操作玩家
-- slotIndex: 目标槽位（1-30）
-- digimonKey: 数码宝贝种类键名（如 "agumon"）
-- 返回：true=成功, false=失败
function DigimonManager:PlaceDigimon(playerID, slotIndex, digimonKey)
    -- 校验槽位
    local slot = self.slots[slotIndex]
    if slot == nil then
        print("[DigimonManager] 错误：无效槽位 " .. tostring(slotIndex))
        return false
    end
    if slot.occupied then
        print("[DigimonManager] 错误：槽位 " .. slotIndex .. " 已被占用")
        return false
    end

    -- 校验数码宝贝种类
    local unitType = DigimonManager.BABY_UNIT[digimonKey]
    if unitType == nil then
        print("[DigimonManager] 错误：未知数码宝贝 " .. tostring(digimonKey))
        return false
    end

    -- 消耗数据碎片（通过 economy 模块）
    local economy = GameRules.DigimonTD and GameRules.DigimonTD.economy
    if economy then
        local cost = DigimonManager.EVOLVE_COST[DigimonManager.STAGE_BABY]
        if not economy:SpendShards(cost) then
            print("[DigimonManager] 错误：数据碎片不足")
            return false
        end
    end

    -- 生成单位
    local unit = CreateUnitByName(unitType, slot.pos, true, nil, nil, DOTA_TEAM_GOODGUYS)
    if unit == nil then
        print("[DigimonManager] 错误：无法生成单位 " .. unitType)
        return false
    end

    -- 固定位置（塔防单位不移动）
    unit:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
    unit:SetAbsOrigin(slot.pos)

    -- 记录数据
    slot.occupied = true
    self.digimonData[slotIndex] = {
        owner       = playerID,
        digimonKey  = digimonKey,
        stage       = DigimonManager.STAGE_BABY,
        level       = 1,
        skillPoints = 0,
        unitHandle  = unit,
        slotIndex   = slotIndex,
    }

    -- 挂载技能（根据种类加载对应技能组）
    self:AttachAbilities(unit, digimonKey)

    -- 设置自动攻击行为
    self:SetupAutoAttack(unit)

    print(string.format("[DigimonManager] 玩家%d 在槽位%d 放置了 %s", playerID, slotIndex, digimonKey))
    return true
end

-- 根据数码宝贝种类挂载技能
-- 技能名约定：digimon_{key}_skill1/2/3/ult
function DigimonManager:AttachAbilities(unit, digimonKey)
    local abilities = {
        "digimon_" .. digimonKey .. "_skill1",
        "digimon_" .. digimonKey .. "_skill2",
        "digimon_" .. digimonKey .. "_skill3",
        "digimon_" .. digimonKey .. "_ult",
    }
    for _, abilityName in ipairs(abilities) do
        -- 检查技能是否已存在（避免重复添加）
        if unit:FindAbilityByName(abilityName) == nil then
            unit:AddAbility(abilityName)
        end
    end
end

-- =========================================================
-- 移除数码宝贝
-- =========================================================

function DigimonManager:RemoveDigimon(playerID, slotIndex)
    local data = self.digimonData[slotIndex]
    if data == nil then
        print("[DigimonManager] 错误：槽位 " .. slotIndex .. " 没有数码宝贝")
        return false
    end
    if data.owner ~= playerID then
        print("[DigimonManager] 错误：玩家" .. playerID .. " 无权移除此数码宝贝")
        return false
    end

    -- 退还 50% 碎片（向下取整）
    local economy = GameRules.DigimonTD and GameRules.DigimonTD.economy
    if economy then
        local refund = math.floor(DigimonManager.EVOLVE_COST[DigimonManager.STAGE_BABY] * 0.5)
        economy:AddShards(refund)
    end

    data.unitHandle:RemoveSelf()
    self.slots[slotIndex].occupied = false
    self.digimonData[slotIndex] = nil

    print(string.format("[DigimonManager] 玩家%d 移除了槽位%d 的数码宝贝", playerID, slotIndex))
    return true
end

-- =========================================================
-- 移动数码宝贝（换槽）
-- =========================================================

function DigimonManager:MoveDigimon(playerID, fromSlot, toSlot)
    local data = self.digimonData[fromSlot]
    if data == nil then
        print("[DigimonManager] 错误：源槽位 " .. fromSlot .. " 没有数码宝贝")
        return false
    end
    if data.owner ~= playerID then
        print("[DigimonManager] 错误：玩家" .. playerID .. " 无权移动此数码宝贝")
        return false
    end

    local targetSlot = self.slots[toSlot]
    if targetSlot == nil or targetSlot.occupied then
        print("[DigimonManager] 错误：目标槽位无效或已占用")
        return false
    end

    -- 消耗金币
    local gold = PlayerResource:GetGold(playerID)
    if gold < DigimonManager.MOVE_GOLD_COST then
        print("[DigimonManager] 错误：金币不足，需要 " .. DigimonManager.MOVE_GOLD_COST)
        return false
    end
    PlayerResource:ModifyGold(playerID, -DigimonManager.MOVE_GOLD_COST, false, 0)

    -- 移动单位到新槽位
    local unit = data.unitHandle
    unit:SetAbsOrigin(targetSlot.pos)

    -- 更新槽位状态
    self.slots[fromSlot].occupied = false
    targetSlot.occupied = true
    data.slotIndex = toSlot
    self.digimonData[toSlot]   = data
    self.digimonData[fromSlot] = nil

    print(string.format("[DigimonManager] 玩家%d 将数码宝贝从槽位%d 移到槽位%d", playerID, fromSlot, toSlot))
    return true
end

-- =========================================================
-- 自动攻击行为
-- =========================================================

-- 设置数码宝贝自动攻击最近的敌人
function DigimonManager:SetupAutoAttack(unit)
    -- Dota 2 creature 默认会自动攻击范围内敌人，
    -- 通过 SetInitialGoalEntity 让单位保持原地
    unit:SetInitialGoalEntity(unit)

    -- 额外 think：确保单位始终攻击最近敌人（防止 idle）
    unit:SetContextThink("auto_attack", function()
        if not unit:IsAlive() then return nil end

        -- 若当前没有攻击目标，寻找最近敌人
        if not unit:IsAttacking() then
            local attackRange = unit:GetAttackRange() + 50
            local enemies = FindUnitsInRadius(
                DOTA_TEAM_GOODGUYS,
                unit:GetAbsOrigin(),
                nil,
                attackRange,
                DOTA_UNIT_TARGET_TEAM_ENEMY,
                DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
                DOTA_UNIT_TARGET_FLAG_NONE,
                FIND_CLOSEST,
                false
            )
            if #enemies > 0 then
                unit:MoveToTargetToAttack(enemies[1])
            end
        end
        return 0.5  -- 每 0.5 秒检查一次
    end, 0.5)
end

-- =========================================================
-- 查询接口
-- =========================================================

-- 获取槽位的数码宝贝数据
function DigimonManager:GetDigimonData(slotIndex)
    return self.digimonData[slotIndex]
end

-- 获取玩家拥有的所有数码宝贝槽位列表
function DigimonManager:GetPlayerDigimonSlots(playerID)
    local result = {}
    for slotIndex, data in pairs(self.digimonData) do
        if data.owner == playerID then
            result[#result + 1] = slotIndex
        end
    end
    return result
end

-- 获取空闲槽位列表
function DigimonManager:GetFreeSlots()
    local result = {}
    for i, slot in ipairs(self.slots) do
        if not slot.occupied then
            result[#result + 1] = i
        end
    end
    return result
end

-- =========================================================
-- 升级系统
-- =========================================================

-- 升级费用：50 × 当前等级
function DigimonManager:GetLevelUpCost(currentLevel)
    return 50 * currentLevel
end

-- 升级数码宝贝（消耗金币，获得技能点）
-- 返回：true=成功, false=失败
function DigimonManager:LevelUp(playerID, slotIndex)
    local data = self.digimonData[slotIndex]
    if data == nil then
        print("[DigimonManager] 错误：槽位 " .. slotIndex .. " 没有数码宝贝")
        return false
    end
    if data.owner ~= playerID then
        print("[DigimonManager] 错误：玩家" .. playerID .. " 无权操作此数码宝贝")
        return false
    end

    local MAX_LEVEL = 15
    if data.level >= MAX_LEVEL then
        print("[DigimonManager] 已达最高等级 " .. MAX_LEVEL)
        return false
    end

    local cost = self:GetLevelUpCost(data.level)
    local gold = PlayerResource:GetGold(playerID)
    if gold < cost then
        print(string.format("[DigimonManager] 金币不足，需要 %d，当前 %d", cost, gold))
        return false
    end

    PlayerResource:ModifyGold(playerID, -cost, false, 0)
    data.level       = data.level + 1
    data.skillPoints = data.skillPoints + 1

    print(string.format("[DigimonManager] 槽位%d 升至 %d 级，技能点: %d",
        slotIndex, data.level, data.skillPoints))
    return true
end

-- =========================================================
-- 技能点投入
-- =========================================================

-- 技能解锁等级表（skill1/2/3 在 1/3/5/7 级，大招在 6/11/15 级）
local SKILL_UNLOCK_LEVELS = {
    skill1 = {1, 3, 5, 7},
    skill2 = {1, 3, 5, 7},
    skill3 = {1, 3, 5, 7},
    ult    = {6, 11, 15},
}

-- 投入技能点升级技能
-- skillSlot: "skill1" | "skill2" | "skill3" | "ult"
-- 返回：true=成功, false=失败
function DigimonManager:SpendSkillPoint(playerID, slotIndex, skillSlot)
    local data = self.digimonData[slotIndex]
    if data == nil then
        print("[DigimonManager] 错误：槽位 " .. slotIndex .. " 没有数码宝贝")
        return false
    end
    if data.owner ~= playerID then
        print("[DigimonManager] 错误：无权操作")
        return false
    end
    if data.skillPoints <= 0 then
        print("[DigimonManager] 错误：没有可用技能点")
        return false
    end

    local unit        = data.unitHandle
    local abilityName = "digimon_" .. data.digimonKey .. "_" .. skillSlot
    local ability     = unit:FindAbilityByName(abilityName)
    if ability == nil then
        print("[DigimonManager] 错误：找不到技能 " .. abilityName)
        return false
    end

    local currentLevel = ability:GetLevel()
    local maxLevel     = ability:GetMaxLevel()
    if currentLevel >= maxLevel then
        print("[DigimonManager] 技能已满级")
        return false
    end

    -- 检查解锁等级
    local unlockLevels = SKILL_UNLOCK_LEVELS[skillSlot]
    local requiredLevel = unlockLevels and unlockLevels[currentLevel + 1]
    if requiredLevel and data.level < requiredLevel then
        print(string.format("[DigimonManager] 需要 %d 级才能升级此技能，当前 %d 级",
            requiredLevel, data.level))
        return false
    end

    ability:SetLevel(currentLevel + 1)
    data.skillPoints = data.skillPoints - 1

    print(string.format("[DigimonManager] 槽位%d %s 升至 %d 级，剩余技能点: %d",
        slotIndex, skillSlot, currentLevel + 1, data.skillPoints))
    return true
end

-- =========================================================
-- 进化系统
-- =========================================================

-- 查询可进化分支列表（供 UI 展示）
-- 返回：{ { key, unit, label }, ... } 或 nil（不可进化）
function DigimonManager:GetEvolveOptions(slotIndex)
    local data = self.digimonData[slotIndex]
    if data == nil then return nil end
    return DigimonManager.EVOLVE_TREE[data.digimonKey]
end

-- 执行进化
-- branchIndex: 分支序号（1 开始），单路进化传 1
-- 返回：true=成功, false=失败
function DigimonManager:Evolve(playerID, slotIndex, branchIndex)
    local data = self.digimonData[slotIndex]
    if data == nil then
        print("[DigimonManager] 错误：槽位 " .. slotIndex .. " 没有数码宝贝")
        return false
    end
    if data.owner ~= playerID then
        print("[DigimonManager] 错误：无权操作")
        return false
    end

    -- 必须 15 级才能进化
    if data.level < 15 then
        print(string.format("[DigimonManager] 进化需要 15 级，当前 %d 级", data.level))
        return false
    end

    -- 查分支
    local options = DigimonManager.EVOLVE_TREE[data.digimonKey]
    if options == nil or #options == 0 then
        print("[DigimonManager] 该数码宝贝已无法继续进化")
        return false
    end
    local branch = options[branchIndex]
    if branch == nil then
        print("[DigimonManager] 错误：无效分支序号 " .. tostring(branchIndex))
        return false
    end

    -- 消耗碎片
    local nextStage = data.stage + 1
    local cost = DigimonManager.EVOLVE_SHARD_COST[nextStage] or 1
    local economy = GameRules.DigimonTD and GameRules.DigimonTD.economy
    if economy and not economy:SpendShards(cost) then
        print("[DigimonManager] 碎片不足，需要 " .. cost)
        return false
    end

    -- 记录当前技能等级（skill3 光环保留等级）
    local oldUnit   = data.unitHandle
    local oldPos    = oldUnit:GetAbsOrigin()
    local skill3Key = "digimon_" .. data.digimonKey .. "_skill3"
    local skill3Lvl = 0
    local skill3Ability = oldUnit:FindAbilityByName(skill3Key)
    if skill3Ability then skill3Lvl = skill3Ability:GetLevel() end

    -- 移除旧单位
    oldUnit:RemoveSelf()

    -- 生成新单位
    local newUnit = CreateUnitByName(branch.unit, oldPos, true, nil, nil, DOTA_TEAM_GOODGUYS)
    if newUnit == nil then
        print("[DigimonManager] 错误：无法生成进化单位 " .. branch.unit)
        return false
    end
    newUnit:SetMoveCapability(DOTA_UNIT_CAP_MOVE_NONE)
    newUnit:SetAbsOrigin(oldPos)

    -- 更新数据（等级/技能点保留，digimonKey 更新）
    data.digimonKey = branch.key
    data.stage      = nextStage
    data.unitHandle = newUnit

    -- 挂载新技能
    self:AttachAbilities(newUnit, branch.key)

    -- 恢复 skill3 光环等级（光环全形态通用，数值随等级提升）
    local newSkill3Key = "digimon_" .. branch.key .. "_skill3"
    -- 进化后 skill3 仍用 agumon_skill3（光环共用），直接找
    local newSkill3 = newUnit:FindAbilityByName(newSkill3Key)
    if newSkill3 == nil then
        -- 尝试找父系光环（agumon_skill3 被所有亚古兽系共用）
        newSkill3 = newUnit:FindAbilityByName("digimon_agumon_skill3")
    end
    if newSkill3 and skill3Lvl > 0 then
        newSkill3:SetLevel(skill3Lvl)
    end

    -- 重新设置自动攻击
    self:SetupAutoAttack(newUnit)

    print(string.format("[DigimonManager] 槽位%d 进化为 %s（%s）",
        slotIndex, branch.key, branch.label))
    return true
end
