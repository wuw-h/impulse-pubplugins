
-- credits to Chessnut

impulse.Config.StaminaDrain = 1 -- Drain per tick
impulse.Config.StaminaCrouchRegeneration = 2
impulse.Config.StaminaRegeneration = 1.75
impulse.Config.MaxStamina = 100


-- hooks
function AdjustStaminaOffset(ply, baseOffset) -- baseOffset is the amount the stamina is changing by
end -- shared
--[[
function PLUGIN:AdjustStaminaOffset(client, baseOffset)
	return baseOffset * 2 -- Drain/Regain stamina twice as fast.
end
]]
function PlayerStaminaLost(ply) -- server only
end

function PlayerStaminaGained(client) -- server only
end


SYNC_BRTH = impulse.Sync.RegisterVar(SYNC_BOOL)

local meta = FindMetaTable("Player")

local function CalcStaminaChange(ply)
	local teamData = impulse.Teams.Data[ply:Team()]
	local runSpeed = teamData.runSpeed or impulse.Config.JogSpeed
	local walkSpeed = impulse.Config.WalkSpeed
	local offset

	if ply:GetMoveType() == MOVETYPE_NOCLIP then
		return 0
	end

	if ply:KeyDown(IN_SPEED) and ply:GetVelocity():LengthSqr() >= (walkSpeed * walkSpeed) then
		offset = -impulse.Config.StaminaDrain
	else
		offset = ply:Crouching() and impulse.Config.StaminaCrouchRegeneration or impulse.Config.StaminaRegeneration
	end

	offset = hook.Run("AdjustStaminaOffset", ply, offset) or offset

	if CLIENT then
		return offset
	else
		local current = ply:GetNW2Int("stm", 0)
		local value = math.Clamp(current + offset, 0, impulse.Config.MaxStamina)

		if current != value then
			ply:SetNW2Int("stm", value)

			if value == 0 and not ply:GetSyncVar(SYNC_BRTH, false) then
				ply:SetSyncVar(SYNC_BRTH, true)
				ply:SetRunSpeed(walkSpeed)

				hook.Run("PlayerStaminaLost", ply)

			elseif value >= 50 and ply:GetSyncVar(SYNC_BRTH, false) then
				ply:SetSyncVar(SYNC_BRTH, nil)
				ply:SetRunSpeed(runSpeed)

				hook.Run("PlayerStaminaGained", ply)
			end
		end
	end
end

if SERVER then
	function PLUGIN:PostSetupPlayer(ply)
		local uniqueID = "impulseStamina" .. ply:SteamID()

		timer.Create(uniqueID, 0.25, 0, function()
			if not IsValid(ply) then
				timer.Remove(uniqueID)
				return
			end

			CalcStaminaChange(ply)
		end)

		timer.Simple(0.25, function()
			ply:SetNW2Int("stm", ply.impulseData.stamina or impulse.Config.MaxStamina)
		end)
	end

	function PLUGIN:PlayerDisconnected(ply)
		if not ply.impulseData then return end
		ply.impulseData.stamina = ply:GetNW2Int("stm", 0)
	end

	function meta:RestoreStamina(amount)
		local current = self:GetNW2Int("stm", 0)
		local value = math.Clamp(current + amount, 0, impulse.Config.MaxStamina)

		self:SetNW2Int("stm", value)
	end
	
	function meta:ConsumeStamina(amount)
		local current = self:GetNW2Int("stm", 0)
		local value = math.Clamp(current - amount, 0, impulse.Config.MaxStamina)

		self:SetNW2Int("stm", value)
	end
else
	local predictedStamina = 100

	function PLUGIN:Think()
		local offset = CalcStaminaChange(LocalPlayer())
		-- the server check it every 0.25 sec, here we check it every [FrameTime()] seconds
		offset = math.Remap(FrameTime(), 0, 0.25, 0, offset)

		if offset != 0 then
			predictedStamina = math.Clamp(predictedStamina + offset, 0, impulse.Config.MaxStamina)
		end
	end

	function PLUGIN:EntityNetworkedVarChanged(ply, key, _, new)
		if key != "stm" then return end
		if math.abs(predictedStamina - new) > 5 then
			predictedStamina = new
		end
	end
end

function meta:GetStamina()
	return self:GetNW2Int("stm", 0)
end

-- Due to impulses' lack of uniformity, there's no real way to display stamina universally.
-- So, there's two ways you can go about this.
-- 1. Add stamina to the HUD in this file, using the predictedStamina variable.
-- 2. Edit your own HUD file to display stamina, using the GetStamina meta function.
-- I would personally use the second option.
