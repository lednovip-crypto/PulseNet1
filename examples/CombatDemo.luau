--!strict
-- PulseNet Combat & Hitbox Replication Demo
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PulseNet = require(ReplicatedStorage:WaitForChild("PulseNet"))

if RunService:IsServer() then
    local WEAPON_DAMAGE = { IronSword = 25, HeavyHammer = 45 }

    PulseNet.Server:On("AttackRequest", function(player: Player, data: any)
        if type(data) ~= "table" then return end
        local damage = WEAPON_DAMAGE[data.weaponId] or 10

        if data.target and data.target:IsA("Model") then
            local humanoid = data.target:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid:TakeDamage(damage)
                -- Быстрая трансляция эффекта удара через ненадежный канал (без лагов)
                PulseNet.Server:FireAll("PlayHitFX", {
                    position = data.target:GetPivot().Position,
                    damageDealt = damage,
                }, true)
            end
        end
    end)
else
    local function attack(weaponName: string, targetModel: Model?)
        PulseNet.Client:Fire("AttackRequest", { weaponId = weaponName, target = targetModel })
    end

    PulseNet.Client:On("PlayHitFX", function(fxData: any)
        print("Hit particle at:", fxData.position, "Damage:", fxData.damageDealt)
    end)
end
