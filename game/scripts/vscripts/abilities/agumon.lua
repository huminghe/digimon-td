-- 亚古兽技能逻辑
-- abilities/agumon.lua

-- ---------------------------------------------------------
-- 技能1：小火焰 — 单体魔法伤害
-- ---------------------------------------------------------
function Agumon_Skill1(event)
    local caster = event.caster
    local target = event.target
    local ability = event.ability
    local damage  = ability:GetSpecialValueFor("damage")

    ApplyDamage({
        victim      = target,
        attacker    = caster,
        damage      = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability     = ability,
    })

    -- 粒子效果
    local pfx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:SetParticleControl(pfx, 0, target:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(pfx)
end

-- ---------------------------------------------------------
-- 技能2：灼烧爪 — 普攻附带燃烧（被动 OnAttackLanded）
-- ---------------------------------------------------------
function Agumon_Skill2_OnAttack(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability

    -- 只对敌方单位生效
    if target:GetTeamNumber() == caster:GetTeamNumber() then return end
    -- 已有燃烧则刷新持续时间
    target:RemoveModifierByName("modifier_agumon_burn")

    target:AddNewModifier(caster, ability, "modifier_agumon_burn", {
        burn_damage   = ability:GetSpecialValueFor("burn_damage"),
        burn_duration = ability:GetSpecialValueFor("burn_duration"),
        tick_interval = ability:GetSpecialValueFor("tick_interval"),
    })
end

-- ---------------------------------------------------------
-- 技能4（大招）：胡椒火焰 — 锥形范围魔法伤害
-- ---------------------------------------------------------
function Agumon_Ult(event)
    local caster  = event.caster
    local ability = event.ability
    local damage  = ability:GetSpecialValueFor("damage")
    local range   = ability:GetSpecialValueFor("cone_range")
    local width   = ability:GetSpecialValueFor("cone_width")

    -- 朝向：面向最近敌人，若无则用单位朝向
    local forward = caster:GetForwardVector()
    local nearest = _FindNearestEnemy(caster, range + 200)
    if nearest then
        local dir = nearest:GetAbsOrigin() - caster:GetAbsOrigin()
        dir.z = 0
        if dir:Length2D() > 0 then
            forward = dir:Normalized()
        end
    end

    -- 锥形检测：在 range 内，与朝向夹角 < arctan(width/2 / range) 的单位
    local origin  = caster:GetAbsOrigin()
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        origin,
        nil,
        range,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    local halfWidth = width * 0.5
    for _, enemy in ipairs(enemies) do
        local toEnemy = enemy:GetAbsOrigin() - origin
        toEnemy.z = 0
        local dist = toEnemy:Length2D()
        if dist > 0 then
            -- 投影到朝向轴，计算侧向偏移
            local dot     = toEnemy:Dot(forward)
            local lateral = math.sqrt(math.max(0, dist * dist - dot * dot))
            if dot > 0 and lateral <= halfWidth then
                ApplyDamage({
                    victim      = enemy,
                    attacker    = caster,
                    damage      = damage,
                    damage_type = DAMAGE_TYPE_MAGICAL,
                    ability     = ability,
                })
                -- 附带短暂燃烧
                enemy:RemoveModifierByName("modifier_agumon_burn")
                enemy:AddNewModifier(caster, ability, "modifier_agumon_burn", {
                    burn_damage   = math.floor(damage * 0.1),
                    burn_duration = 3.0,
                    tick_interval = 1.0,
                })
            end
        end
    end

    -- 锥形粒子
    local pfx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:SetParticleControl(pfx, 0, origin)
    ParticleManager:SetParticleControl(pfx, 1, origin + forward * range)
    ParticleManager:ReleaseParticleIndex(pfx)
end

-- ---------------------------------------------------------
-- 内部工具：找最近敌人
-- ---------------------------------------------------------
function _FindNearestEnemy(unit, radius)
    local enemies = FindUnitsInRadius(
        unit:GetTeamNumber(),
        unit:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_CLOSEST,
        false
    )
    return enemies[1]
end

-- ---------------------------------------------------------
-- 内部工具：直线穿透检测（从 origin 沿 forward 方向，宽度 width，长度 range）
-- ---------------------------------------------------------
function _FindUnitsInLine(teamNumber, origin, forward, range, width)
    local all = FindUnitsInRadius(
        teamNumber, origin, nil, range,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER, false
    )
    local result = {}
    local halfW = width * 0.5
    for _, unit in ipairs(all) do
        local toUnit = unit:GetAbsOrigin() - origin
        toUnit.z = 0
        local dist = toUnit:Length2D()
        if dist > 0 then
            local dot     = toUnit:Dot(forward)
            local lateral = math.sqrt(math.max(0, dist * dist - dot * dot))
            if dot > 0 and lateral <= halfW then
                result[#result + 1] = unit
            end
        end
    end
    return result
end

-- =========================================================
-- 暴龙兽（成熟期）技能
-- =========================================================

-- 技能1：大火焰 — 单体高额魔法伤害
function Greymon_Skill1(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    ApplyDamage({
        victim = target, attacker = caster,
        damage = ability:GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
    })
    local pfx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_dragon_knight/dragon_knight_breathe_fire.vpcf",
        PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:ReleaseParticleIndex(pfx)
end

-- 技能2：恐吓咆哮 — 范围减速 + 降护甲
function Greymon_Skill2(event)
    local caster  = event.caster
    local ability = event.ability
    local point   = event.target_points[1]
    local radius  = ability:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), point, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, enemy in ipairs(enemies) do
        enemy:AddNewModifier(caster, ability, "modifier_greymon_roar", {
            slow_pct     = ability:GetSpecialValueFor("slow_pct"),
            armor_reduce = ability:GetSpecialValueFor("armor_reduce"),
            duration     = ability:GetSpecialValueFor("duration"),
        })
    end
end

-- 大招：暴龙火焰 — 范围火焰 + 燃烧
function Greymon_Ult(event)
    local caster  = event.caster
    local ability = event.ability
    local point   = event.target_points[1]
    local radius  = ability:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), point, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, enemy in ipairs(enemies) do
        ApplyDamage({
            victim = enemy, attacker = caster,
            damage = ability:GetSpecialValueFor("damage"),
            damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
        })
        enemy:RemoveModifierByName("modifier_agumon_burn")
        enemy:AddNewModifier(caster, ability, "modifier_agumon_burn", {
            burn_damage   = ability:GetSpecialValueFor("burn_damage"),
            burn_duration = ability:GetSpecialValueFor("burn_duration"),
            tick_interval = 1.0,
        })
    end
end

-- =========================================================
-- 机械暴龙兽（完全体A）技能
-- =========================================================

-- 技能1：超级进化火焰 — 物理+魔法混合伤害
function MetalGreymon_Skill1(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    ApplyDamage({
        victim = target, attacker = caster,
        damage = ability:GetSpecialValueFor("phys_damage"),
        damage_type = DAMAGE_TYPE_PHYSICAL, ability = ability,
    })
    ApplyDamage({
        victim = target, attacker = caster,
        damage = ability:GetSpecialValueFor("magic_damage"),
        damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
    })
end

-- 技能2：机械爪击 — 普攻附带可叠加减甲
function MetalGreymon_Skill2_OnAttack(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    if target:GetTeamNumber() == caster:GetTeamNumber() then return end

    -- 叠加层数（最多 max_stacks 层）
    local stacks = target:GetModifierStackCount("modifier_metalgreymon_armor_reduce", caster)
    local maxStacks = ability:GetSpecialValueFor("max_stacks")
    if stacks < maxStacks then
        target:AddNewModifier(caster, ability, "modifier_metalgreymon_armor_reduce", {
            armor_reduce = ability:GetSpecialValueFor("armor_reduce"),
            duration     = ability:GetSpecialValueFor("duration"),
        })
    end
end

-- 大招：吉格拉火焰 — 直线穿透巨额伤害
function MetalGreymon_Ult(event)
    local caster  = event.caster
    local ability = event.ability
    local point   = event.target_points[1]
    local origin  = caster:GetAbsOrigin()
    local dir     = point - origin
    dir.z = 0
    if dir:Length2D() == 0 then return end
    local forward = dir:Normalized()

    local targets = _FindUnitsInLine(
        caster:GetTeamNumber(), origin, forward,
        ability:GetSpecialValueFor("width") * 5,  -- range = width*5 近似直线
        ability:GetSpecialValueFor("width"))
    -- 实际用 cast range 作为长度
    targets = _FindUnitsInLine(
        caster:GetTeamNumber(), origin, forward, 1000, ability:GetSpecialValueFor("width"))
    for _, enemy in ipairs(targets) do
        ApplyDamage({
            victim = enemy, attacker = caster,
            damage = ability:GetSpecialValueFor("damage"),
            damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
        })
    end
end

-- =========================================================
-- 丧尸暴龙兽（完全体B，死路）技能
-- =========================================================

-- 技能1：机械鲨鱼弹 — 直线穿透
function SkullGreymon_Skill1(event)
    local caster  = event.caster
    local ability = event.ability
    local point   = event.target_points[1]
    local origin  = caster:GetAbsOrigin()
    local dir     = point - origin
    dir.z = 0
    if dir:Length2D() == 0 then return end
    local forward = dir:Normalized()
    local targets = _FindUnitsInLine(
        caster:GetTeamNumber(), origin, forward, 800, ability:GetSpecialValueFor("width"))
    for _, enemy in ipairs(targets) do
        ApplyDamage({
            victim = enemy, attacker = caster,
            damage = ability:GetSpecialValueFor("damage"),
            damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
        })
    end
end

-- 技能2：腐蚀毒液 — 普攻附带中毒（减速+减甲）
function SkullGreymon_Skill2_OnAttack(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    if target:GetTeamNumber() == caster:GetTeamNumber() then return end
    target:RemoveModifierByName("modifier_skullgreymon_poison")
    target:AddNewModifier(caster, ability, "modifier_skullgreymon_poison", {
        poison_damage = ability:GetSpecialValueFor("poison_damage"),
        slow_pct      = ability:GetSpecialValueFor("slow_pct"),
        armor_reduce  = ability:GetSpecialValueFor("armor_reduce"),
        duration      = ability:GetSpecialValueFor("duration"),
    })
end

-- 大招：死亡爆破 — 大范围极高伤害 + 自身短暂无敌
function SkullGreymon_Ult(event)
    local caster  = event.caster
    local ability = event.ability
    local origin  = caster:GetAbsOrigin()
    local radius  = ability:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), origin, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, enemy in ipairs(enemies) do
        ApplyDamage({
            victim = enemy, attacker = caster,
            damage = ability:GetSpecialValueFor("damage"),
            damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
        })
    end
    -- 自身短暂无敌
    caster:AddNewModifier(caster, ability, "modifier_invulnerable", {
        duration = ability:GetSpecialValueFor("invuln_duration")
    })
end

-- =========================================================
-- 战斗暴龙兽（究极体A1）技能
-- =========================================================

-- 技能1：德拉蒙破坏者 — 单体极高魔法伤害 + 燃烧
function WarGreymon_Skill1(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    ApplyDamage({
        victim = target, attacker = caster,
        damage = ability:GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
    })
    target:RemoveModifierByName("modifier_agumon_burn")
    target:AddNewModifier(caster, ability, "modifier_agumon_burn", {
        burn_damage   = ability:GetSpecialValueFor("burn_damage"),
        burn_duration = ability:GetSpecialValueFor("burn_duration"),
        tick_interval = 1.0,
    })
end

-- 技能2：战斗之盾 — 自身护盾 + 周围敌人反弹伤害
function WarGreymon_Skill2(event)
    local caster  = event.caster
    local ability = event.ability
    caster:AddNewModifier(caster, ability, "modifier_wargreymon_shield", {
        shield_hp       = ability:GetSpecialValueFor("shield_hp"),
        reflect_damage  = ability:GetSpecialValueFor("reflect_damage"),
        reflect_radius  = ability:GetSpecialValueFor("reflect_radius"),
        duration        = ability:GetSpecialValueFor("duration"),
    })
end

-- 大招：终极火焰 — 锥形毁灭性伤害
function WarGreymon_Ult(event)
    local caster  = event.caster
    local ability = event.ability
    local forward = caster:GetForwardVector()
    local nearest = _FindNearestEnemy(caster, ability:GetSpecialValueFor("cone_range") + 200)
    if nearest then
        local dir = nearest:GetAbsOrigin() - caster:GetAbsOrigin()
        dir.z = 0
        if dir:Length2D() > 0 then forward = dir:Normalized() end
    end
    local origin   = caster:GetAbsOrigin()
    local range    = ability:GetSpecialValueFor("cone_range")
    local halfW    = ability:GetSpecialValueFor("cone_width") * 0.5
    local enemies  = FindUnitsInRadius(
        caster:GetTeamNumber(), origin, nil, range,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, enemy in ipairs(enemies) do
        local toEnemy = enemy:GetAbsOrigin() - origin
        toEnemy.z = 0
        local dist = toEnemy:Length2D()
        if dist > 0 then
            local dot     = toEnemy:Dot(forward)
            local lateral = math.sqrt(math.max(0, dist * dist - dot * dot))
            if dot > 0 and lateral <= halfW then
                ApplyDamage({
                    victim = enemy, attacker = caster,
                    damage = ability:GetSpecialValueFor("damage"),
                    damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
                })
            end
        end
    end
end

-- =========================================================
-- 电光暴龙兽（究极体A2）技能
-- =========================================================

-- 技能1：电光冲击 — 单体高额魔法伤害 + 概率麻痹
function MetalSeadramon_Skill1(event)
    local caster  = event.caster
    local target  = event.target
    local ability = event.ability
    ApplyDamage({
        victim = target, attacker = caster,
        damage = ability:GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
    })
    if RollPercentage(ability:GetSpecialValueFor("stun_chance") * 100) then
        target:AddNewModifier(caster, ability, "modifier_stunned", {
            duration = ability:GetSpecialValueFor("stun_duration")
        })
    end
end

-- 技能2：电磁风暴 — 范围持续电击 + 减速
function MetalSeadramon_Skill2(event)
    local caster  = event.caster
    local ability = event.ability
    local point   = event.target_points[1]
    local radius  = ability:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), point, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
    for _, enemy in ipairs(enemies) do
        enemy:AddNewModifier(caster, ability, "modifier_metalseadramon_storm", {
            damage_per_sec = ability:GetSpecialValueFor("damage_per_sec"),
            slow_pct       = ability:GetSpecialValueFor("slow_pct"),
            duration       = ability:GetSpecialValueFor("duration"),
        })
    end
end

-- 大招：闪电暴龙炮 — 连锁电击（每次跳跃伤害衰减）
function MetalSeadramon_Ult(event)
    local caster      = event.caster
    local ability     = event.ability
    local damage      = ability:GetSpecialValueFor("damage")
    local chainCount  = ability:GetSpecialValueFor("chain_count")
    local chainRange  = ability:GetSpecialValueFor("chain_range")
    local falloff     = ability:GetSpecialValueFor("chain_damage_falloff")

    -- 找最近敌人作为第一个目标
    local firstTarget = _FindNearestEnemy(caster, 900)
    if firstTarget == nil then return end

    local hit     = { [firstTarget] = true }
    local current = firstTarget
    local curDmg  = damage

    for i = 1, chainCount do
        ApplyDamage({
            victim = current, attacker = caster,
            damage = curDmg,
            damage_type = DAMAGE_TYPE_MAGICAL, ability = ability,
        })
        -- 找下一个未被命中的最近敌人
        local candidates = FindUnitsInRadius(
            caster:GetTeamNumber(), current:GetAbsOrigin(), nil, chainRange,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_BASIC | DOTA_UNIT_TARGET_HERO,
            DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
        local next = nil
        for _, c in ipairs(candidates) do
            if not hit[c] then next = c; break end
        end
        if next == nil then break end
        hit[next] = true
        current   = next
        curDmg    = curDmg * falloff
    end
end
