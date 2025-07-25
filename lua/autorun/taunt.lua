local GESTURE_SLOT = 3
local TAUNT_MOVETYPE = MOVETYPE_NONE
local NORMAL_MOVETYPE = MOVETYPE_WALK

-- Model and weapon configuration
local MOBSTER_MODEL = "models/vip_mobster/player/mobster.mdl"

-- Taunt configurations
local TAUNT_CONFIGS = { -- these are were the taunts are at it will look for a weapon and press g BAM taunting
    [1] = {
        weapon = "mobster_typewriter",
        gesture = "taunt01",
        speed = 0.79,
        hasFaceFlex = true,
        hasVoiceLines = true,
        flexName = "happybig"
    },
    [2] = {
        weapon = "mobster_moneybag",
        gesture = "taunt02",
        speed = 1.00,
        hasFaceFlex = false,
        hasVoiceLines = false,
        flexName = nil
    },
    [3] = {
        weapon = "mobster_metalpipe",
        gesture = "taunt05",
        speed = 1.00,
        hasFaceFlex = false,
        hasVoiceLines = false,
        flexName = nil
	}
}


local taunt_laugh_config = {
    weapon = nil,
    gesture = "taunt_laugh",
    speed = 1.0,
    hasFaceFlex = true,
    hasVoiceLines = true,
    flexName = "happybig",
    isConsoleCommand = true,
    hideWorldModel = true
}

-- dosido partner taunt
local taunt_dosido_config = {
    gesture = "taunt_dosido_intro",
    speed = 1.0,
    hasFaceFlex = false,
    hasVoiceLines = false,
    flexName = nil,
    isLooping = true,
    isConsoleCommand = true,
    hideWorldModel = true,
    loopSound = true
}

local taunt_rps_config = {
    gesture = "taunt_rps_start",
    speed = 1.0,
    hasFaceFlex = true,
    hasVoiceLines = false,
    flexName = "happybig",
    isLooping = true,
    isConsoleCommand = true,
    hideWorldModel = true,
    rpsSounds = {
        "mvm/mobster_emergent_r1b/mobster_rps_init01.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init02.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init03.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init04.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init05.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init06.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init07.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init08.mp3",
        "mvm/mobster_emergent_r1b/mobster_rps_init09.mp3"
    }
}

-- Voice lines for taunt01 only
local TAUNT_VOICE_LINES = {
    "mvm/mobster_emergent_r1b/mobster_cheers01.mp3",
    "mvm/mobster_emergent_r1b/mobster_cheers02.mp3",
    "mvm/mobster_emergent_r1b/mobster_cheers03.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization01.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization02.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization03.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization04.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization05.mp3",
    "mvm/mobster_emergent_r1b/mobster_positivevocalization06.mp3"
}

-- Visual effects configuration
local VISUAL_EFFECTS = {
    saxton = "vsh_body_aura",
    horseless = "utaunt_cremation_purple_parent",
    dragonfly = "utaunt_dragonfly_purple_parent",
    space_red = "utaunt_astralbodies_teamcolor_red",
    space_blue = "utaunt_astralbodies_teamcolor_blue",
    blizzard_red = "utaunt_innerblizzard_teamcolor_red",
    blizzard_blue = "utaunt_innerblizzard_teamcolor_blue"
}

local taunt_russian_config = {
    gesture = "taunt_russian",
    speed = 1.0,
    hasFaceFlex = true,
    hasVoiceLines = false,
    flexName = "happybig",
    isLooping = true,
    isConsoleCommand = true,
    loopSound = true,
    moveSpeed = 49.8,
    allowMovement = true,
    hideWorldModel = true
}


if SERVER then
    local tauntingPlayers = {}
	local dosidoLooping = {} -- store loop sound handles
	local tauntCooldowns = {}

	
    util.AddNetworkString("TF2_StartTaunt")
    util.AddNetworkString("TF2_EndTaunt")
    util.AddNetworkString("TF2_TauntRequest")
    util.AddNetworkString("TF2_TauntError")
    util.AddNetworkString("TF2_FaceFlex")
    util.AddNetworkString("TF2_TauntDosido_Request")
    util.AddNetworkString("TF2_TauntDosido_Dance")


    local function SetWorldModelHidden(ply, hide)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        if wep.SetNoDraw then
            wep:SetNoDraw(hide)
        end
    end
	
    local function StartFaceFlex(ply, flexName, duration)
        if not IsValid(ply) or not flexName then return end
        local flexID = ply:GetFlexIDByName(flexName)
        if not flexID or flexID < 0 then return end
        local flexStartTime = CurTime()
        local flexUpDuration = 0.5
        local flexDownStart = duration - 0.5
        local flexDownDuration = 0.5

        timer.Create("TF2_FaceFlex_" .. ply:SteamID64(), 0.05, 0, function()
            if not IsValid(ply) or not tauntingPlayers[ply] then
                timer.Remove("TF2_FaceFlex_" .. ply:SteamID64())
                return
            end
            local elapsed = CurTime() - flexStartTime
            local flexValue = 0
            if elapsed <= flexUpDuration then
                flexValue = math.ease.InOutQuad(elapsed / flexUpDuration)
            elseif elapsed >= flexDownStart then
                local downElapsed = elapsed - flexDownStart
                flexValue = 1.0 - math.ease.InOutQuad(math.min(downElapsed / flexDownDuration, 1))
            else
                flexValue = 1.0
            end
            ply:SetFlexWeight(flexID, flexValue)
            net.Start("TF2_FaceFlex")
            net.WriteEntity(ply)
            net.WriteString(flexName)
            net.WriteFloat(flexValue)
            net.Broadcast()
            if elapsed >= duration then
                ply:SetFlexWeight(flexID, 0)
                net.Start("TF2_FaceFlex")
                net.WriteEntity(ply)
                net.WriteString(flexName)
                net.WriteFloat(0)
                net.Broadcast()
                timer.Remove("TF2_FaceFlex_" .. ply:SteamID64())
            end
        end)
    end

    hook.Add("PlayerButtonDown", "TF2_TauntCancelAndStart", function(ply, key)
        -- Handle RPS taunt cancellation (existing code)
        if key == KEY_E and tauntingPlayers[ply] and tauntingPlayers[ply].config == taunt_rps_config then
            ply:ChatPrint("://ERROR//: FAILED TO MAKE DEAL WITH PARTNER FOLLOWING ERROR CODE: i simply cant do this.")
            EndTaunt(ply)
            return
        end
        
        -- Handle G key press
        if key == KEY_G then
            -- Handle other taunt cancellations
            if tauntingPlayers[ply] and tauntingPlayers[ply].config == taunt_rps_config then
                EndTaunt(ply)
                return
            end
            
            if tauntingPlayers[ply] and tauntingPlayers[ply].config == taunt_dosido_config then
                ply:StopSound(dosidoLooping[ply] or "")
                dosidoLooping[ply] = nil
                EndTaunt(ply)
                tauntCooldowns[ply] = CurTime() + 1
                return
            end
            
            -- If not taunting, try to start a new taunt
            if not tauntingPlayers[ply] then
                -- Check cooldown
                if tauntCooldowns[ply] and CurTime() < tauntCooldowns[ply] then return end
                
                -- Check if valid for taunting
                if not ply:Alive() then return end
                if string.lower(ply:GetModel()) ~= string.lower(MOBSTER_MODEL) then return end
                if not ply:OnGround() then return end
                
                local weapon = ply:GetActiveWeapon()
                if not IsValid(weapon) then return end
                local weaponClass = weapon:GetClass()
                
                for _, config in ipairs(TAUNT_CONFIGS) do
                    if config.weapon == weaponClass then
                        StartTaunt(ply, config)
                        return
                    end
                end
            end
        end
    end)
	

    concommand.Add("play_taunt_rps", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if tauntingPlayers[ply] then
            ply:ChatPrint("You are already taunting")
            return
        end
        if string.lower(ply:GetModel()) ~= string.lower(MOBSTER_MODEL) then return end
        if not ply:OnGround() then return end
        StartTaunt(ply, taunt_rps_config)
        local rpsSound = taunt_rps_config.rpsSounds[math.random(#taunt_rps_config.rpsSounds)]
        ply:EmitSound(rpsSound)
    end)

    hook.Add("Think", "TF2_TauntLoopMonitor", function()
        for ply, data in pairs(tauntingPlayers) do
            if not IsValid(ply) or not ply:Alive() then
                EndTaunt(ply)
            elseif data and data.config and data.config.isLooping and CurTime() >= data.startTime + data.duration then
                -- For Russian taunt, restart the gesture but keep movement
                if data.config == taunt_russian_config then
                    local gestureID = ply:LookupSequence(data.config.gesture)
                    if gestureID and gestureID >= 0 then
                        local originalDuration = ply:SequenceDuration(gestureID)
                        local adjustedDuration = originalDuration / data.config.speed
                        
                        -- Update the taunt data
                        data.startTime = CurTime()
                        data.duration = adjustedDuration
                        
                        -- Restart the gesture on client
                        net.Start("TF2_StartTaunt")
                        net.WriteEntity(ply)
                        net.WriteInt(gestureID, 16)
                        net.WriteFloat(adjustedDuration)
                        net.WriteFloat(data.config.speed)
                        net.WriteString(data.config.gesture)
                        net.WriteBool(data.config.hasFaceFlex)
                        if data.config.hasFaceFlex then
                            net.WriteString(data.config.flexName or "")
                        end
                        net.Broadcast()
                    end
                else
                    StartTaunt(ply, data.config)
                end
                
                if data.config.rpsSounds then
                    local rpsSound = data.config.rpsSounds[math.random(#data.config.rpsSounds)]
                    ply:EmitSound(rpsSound)
				end
            end
        end
    end)
	
    hook.Add("PlayerDeath", "TF2_TauntOnDeath", function(ply)
        if tauntingPlayers[ply] then
            EndTaunt(ply)
        end
    end)

    hook.Add("PlayerButtonDown", "TF2_TauntDosidoEnd", function(ply, button)
        if button == KEY_G and tauntingPlayers[ply] and tauntingPlayers[ply].config == taunt_dosido_config then
            ply:StopSound(dosidoLooping[ply] or "")
            dosidoLooping[ply] = nil
            EndTaunt(ply)
            tauntCooldowns[ply] = CurTime() + 1
        end
    end)

    net.Receive("TF2_TauntRequest", function(_, ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if tauntCooldowns[ply] and CurTime() < tauntCooldowns[ply] then return end
        if tauntingPlayers[ply] then return end
        if string.lower(ply:GetModel()) ~= string.lower(MOBSTER_MODEL) then return end
        if not ply:OnGround() then
            net.Start("TF2_TauntError")
            net.WriteString("You cannot taunt while in the air!")
            net.Send(ply)
            return
        end
        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return end
        local weaponClass = weapon:GetClass()
        for _, config in ipairs(TAUNT_CONFIGS) do
            if config.weapon == weaponClass then
                StartTaunt(ply, config)
                return
            end
        end
    end)

    concommand.Add("play_taunt_laugh", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if tauntingPlayers[ply] then
            ply:ChatPrint("You are already taunting")
            return
        end
        if string.lower(ply:GetModel()) ~= string.lower(MOBSTER_MODEL) then return end
        if not ply:OnGround() then return end
        StartTaunt(ply, taunt_laugh_config)
    end)

    concommand.Add("play_taunt_dosido", function(ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if tauntingPlayers[ply] then
            ply:ChatPrint("You are already taunting")
            return
        end
        if string.lower(ply:GetModel()) ~= string.lower(MOBSTER_MODEL) then return end
        if not ply:OnGround() then return end
        StartTaunt(ply, taunt_dosido_config)
        local loopSound = math.random(1, 2) == 1 and "music/fortress_reel_loop.wav" or "music/fortress_reel_loop2.wav"
        ply:EmitSound(loopSound)
        dosidoLooping[ply] = loopSound
    end)

    hook.Add("PlayerButtonDown", "TF2_TauntDosidoEnd", function(ply, button)
        if button == KEY_G and tauntingPlayers[ply] and tauntingPlayers[ply].config == taunt_dosido_config then
            ply:StopSound(dosidoLooping[ply] or "")
            dosidoLooping[ply] = nil
            EndTaunt(ply)
        end
    end)

    hook.Add("Think", "TF2_TauntGroundCheck", function()
        for ply, _ in pairs(tauntingPlayers) do
            if IsValid(ply) and not ply:OnGround() and ply:GetVelocity():Length() > 100 then
                EndTaunt(ply)
            end
        end
    end)

    function StartTaunt(ply, config)
        if not IsValid(ply) or not config then return end
        local gestureID = ply:LookupSequence(config.gesture)
        if not gestureID or gestureID < 0 then return end
        
        local originalDuration = ply:SequenceDuration(gestureID)
        local adjustedDuration = originalDuration / config.speed
        
        tauntingPlayers[ply] = {
            gestureID = gestureID,
            startTime = CurTime(),
            duration = adjustedDuration,
            originalDuration = originalDuration,
            speed = config.speed,
            config = config
        }
        
        -- Handle movement type based on config
        if config.allowMovement then
            SetRussianTauntMovement(ply, true)
        else
            ply:SetMoveType(TAUNT_MOVETYPE)
        end
        
        if config.hideWorldModel then
            SetWorldModelHidden(ply, true)
        end
        
        -- Handle sounds
        if config == taunt_laugh_config then
            ply:EmitSound("mvm/mobster_emergent_r1b/mobster_laugh01.mp3", 75, 100, 1, CHAN_VOICE)
        elseif config.hasVoiceLines then
            local randomVoiceLine = TAUNT_VOICE_LINES[math.random(1, #TAUNT_VOICE_LINES)]
            ply:EmitSound(randomVoiceLine, 75, 100, 1, CHAN_VOICE)
        end
        
        if config.hasFaceFlex and config.flexName then
            StartFaceFlex(ply, config.flexName, adjustedDuration)
        end
        
        net.Start("TF2_StartTaunt")
        net.WriteEntity(ply)
        net.WriteInt(gestureID, 16)
        net.WriteFloat(adjustedDuration)
        net.WriteFloat(config.speed)
        net.WriteString(config.gesture)
        net.WriteBool(config.hasFaceFlex)
        if config.hasFaceFlex then
            net.WriteString(config.flexName or "")
        end
        net.Broadcast()
        
        if not config.isLooping then
            timer.Create("TF2_Taunt_Backup_" .. ply:SteamID64(), adjustedDuration + 0.1, 1, function()
                if IsValid(ply) and tauntingPlayers[ply] then
                    EndTaunt(ply)
                end
            end)
        end
    end
    
    -- Update the EndTaunt function
    function EndTaunt(ply)
        if not IsValid(ply) then return end
        local tauntData = tauntingPlayers[ply]
        
        if tauntData and tauntData.config and tauntData.config.hasFaceFlex then
            timer.Remove("TF2_FaceFlex_" .. ply:SteamID64())
            if tauntData.config.flexName then
                local flexID = ply:GetFlexIDByName(tauntData.config.flexName)
                if flexID and flexID >= 0 then
                    ply:SetFlexWeight(flexID, 0)
                    net.Start("TF2_FaceFlex")
                    net.WriteEntity(ply)
                    net.WriteString(tauntData.config.flexName)
                    net.WriteFloat(0)
                    net.Broadcast()
                end
            end
        end
        
        tauntingPlayers[ply] = nil
        
		ply:SetMoveType(MOVETYPE_WALK)

        
        if tauntData and tauntData.config and tauntData.config.hideWorldModel then
            SetWorldModelHidden(ply, false)
        end
        
        timer.Remove("TF2_Taunt_" .. ply:SteamID64())
        timer.Remove("TF2_Taunt_Backup_" .. ply:SteamID64())
        
        net.Start("TF2_EndTaunt")
        net.WriteEntity(ply)
        net.Broadcast()
    end
end

if CLIENT then
    hook.Add("Initialize", "TF2_Precache_Laugh", function()
        sound.Add({
            name = "mobster_taunt_laugh",
            channel = CHAN_VOICE,
            volume = 1.0,
            level = 75,
            pitch = 100,
            sound = "mvm/mobster_emergent_r1b/mobster_laugh01.mp3"
        })
    end)
end

if CLIENT then
    local tauntingPlayers = {}
    local freelookEnabled = false
    local tauntEntity = nil
    local cameraAngles = Angle(0, 0, 0)
    local cameraDistance = 100
    local originalThirdPerson = false
    local gestureEndTime = 0
    local activeParticles = {}
    
    -- Console variable for client
    CreateClientConVar("taunt_visual_effect", "none", true, false, "Visual effect for taunts: saxton, horseless, dragonfly, space, blizzard, none")
    
    -- Key detection for G key
    hook.Add("Think", "TF2_TauntKeyCheck", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

		local focusedPanel = vgui.GetKeyboardFocus()
		if IsValid(focusedPanel) then
			-- Check for common text input types
			local panelType = focusedPanel:GetClassName()
			if panelType == "TextEntry" or 
			panelType == "DTextEntry" or
			panelType == "RichText" or
			string.find(panelType:lower(), "text") or
			string.find(panelType:lower(), "edit") then
				return -- Don't taunt while typing in text fields
			end
		end    

        -- Check if G key is pressed
        if input.IsKeyDown(KEY_G) then
            -- Prevent spam by checking if we already sent request recently
            if not ply.lastTauntRequest or CurTime() - ply.lastTauntRequest > 0.5 then
                ply.lastTauntRequest = CurTime()
                
                -- Send taunt request to server
                net.Start("TF2_TauntRequest")
                net.SendToServer()
            end
        end
        
        -- Monitor gesture end time for local player
        if freelookEnabled and IsValid(tauntEntity) and tauntEntity == ply then
            if CurTime() >= gestureEndTime then
                print("Client detected gesture end, restoring camera")
                RestoreCamera()
            end
        end
    end)
    
    -- Receive taunt error messages
    net.Receive("TF2_TauntError", function()
        local errorMsg = net.ReadString()
        chat.AddText(Color(255, 100, 100), errorMsg)
    end)
    
    -- Receive face flex updates
    net.Receive("TF2_FaceFlex", function()
        local ply = net.ReadEntity()
        local flexName = net.ReadString()
        local flexValue = net.ReadFloat()
        
        if not IsValid(ply) then return end
        
        local flexID = ply:GetFlexIDByName(flexName)
        if flexID and flexID >= 0 then
            ply:SetFlexWeight(flexID, flexValue)
        end
    end)
    
    -- Receive taunt start
    net.Receive("TF2_StartTaunt", function()
        local ply = net.ReadEntity()
        local gestureID = net.ReadInt(16)
        local duration = net.ReadFloat()
        local speed = net.ReadFloat()
        local gestureName = net.ReadString()
        local hasFaceFlex = net.ReadBool()
        local flexName = hasFaceFlex and net.ReadString() or nil
        
        if not IsValid(ply) then return end
        
        -- Store taunting state
        tauntingPlayers[ply] = {
            startTime = CurTime(),
            duration = duration,
            gestureID = gestureID,
            speed = speed,
            gestureName = gestureName,
            endTime = CurTime() + duration,
            hasFaceFlex = hasFaceFlex,
            flexName = flexName
        }
        
        -- Play gesture with custom speed using gesture slot rate
        ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT, gestureID, 0, true)
        
        -- Set gesture playback rate for custom speed
        if speed ~= 1.0 then
            ply:SetLayerPlaybackRate(GESTURE_SLOT, speed)
            print("Set gesture playback rate to: " .. speed .. " for " .. gestureName)
        end
        
        -- Start visual effects
        StartVisualEffects(ply, duration)
        
        -- If it's the local player, setup freelook camera
        if ply == LocalPlayer() then
            gestureEndTime = CurTime() + duration
            SetupFreelookCamera(ply, duration)
        end
        
        print("Started " .. gestureName .. " on " .. ply:Name() .. " (Speed: " .. speed .. ", Duration: " .. duration .. "s)")
    end)
    
    -- Receive taunt end
    net.Receive("TF2_EndTaunt", function()
        local ply = net.ReadEntity()
        
        if not IsValid(ply) then return end
        
        -- Reset gesture playback rate
        if IsValid(ply) then
            ply:SetLayerPlaybackRate(GESTURE_SLOT, 1.0)
        end
        
        -- Reset any face flexes
        local tauntData = tauntingPlayers[ply]
        if tauntData and tauntData.hasFaceFlex and tauntData.flexName then
            local flexID = ply:GetFlexIDByName(tauntData.flexName)
            if flexID and flexID >= 0 then
                ply:SetFlexWeight(flexID, 0)
            end
        end
        
        -- Stop visual effects
        StopVisualEffects(ply)
        
        -- Remove from taunting players
        tauntingPlayers[ply] = nil
        
        -- If it's the local player, restore camera
        if ply == LocalPlayer() then
            RestoreCamera()
        end
    end)
    
    function StartVisualEffects(ply, duration)
        if not IsValid(ply) then return end
        
        local effectType = GetConVar("taunt_visual_effect"):GetString():lower()
        if effectType == "none" then return end
        
        local particleName = nil
        
        if effectType == "saxton" then
            particleName = VISUAL_EFFECTS.saxton
        elseif effectType == "horseless" then
            particleName = VISUAL_EFFECTS.horseless
        elseif effectType == "dragonfly" then
            particleName = VISUAL_EFFECTS.dragonfly
        elseif effectType == "space" then
            -- Check player skin (0 = red, 1 = blue)
            local skin = ply:GetSkin()
            if skin == 0 then
                particleName = VISUAL_EFFECTS.space_red
            else
                particleName = VISUAL_EFFECTS.space_blue
            end
        elseif effectType == "blizzard" then
            -- Check player skin (0 = red, 1 = blue)
            local skin = ply:GetSkin()
            if skin == 0 then
                particleName = VISUAL_EFFECTS.blizzard_red
            else
                particleName = VISUAL_EFFECTS.blizzard_blue
            end
        end
        
        if not particleName then return end
        
        -- Create particle effect attached to player
        local particle = CreateParticleSystem(ply, particleName, PATTACH_ABSORIGIN_FOLLOW)
        if particle then
            activeParticles[ply] = particle
            
            -- Timer to stop particle when taunt ends
            timer.Create("TF2_VisualEffect_" .. ply:EntIndex(), duration, 1, function()
                StopVisualEffects(ply)
            end)
            
            print("Started visual effect: " .. particleName .. " on " .. ply:Name())
        end
    end
    
    function StopVisualEffects(ply)
        if not IsValid(ply) then return end
        
        local particle = activeParticles[ply]
        if particle then
            particle:StopEmission()
            activeParticles[ply] = nil
            timer.Remove("TF2_VisualEffect_" .. ply:EntIndex())
            print("Stopped visual effects on " .. ply:Name())
        end
    end
    
    function SetupFreelookCamera(ply, duration)
        if not IsValid(ply) then return end
        
        freelookEnabled = true
        tauntEntity = ply
        
        -- Store original third person state
        originalThirdPerson = ply:ShouldDrawLocalPlayer()
        
        -- Force third person
        ply.m_bDrawPlayerInThirdPerson = true
        
        -- Initialize camera angles to current view
        cameraAngles = ply:EyeAngles()
        cameraDistance = 100
        
        -- Set gesture end time for monitoring
        gestureEndTime = CurTime() + duration
        
        -- Multiple timers for safety
        timer.Create("TF2_FreelookCamera_Primary", duration, 1, function()
            RestoreCamera()
        end)
        
        timer.Create("TF2_FreelookCamera_Backup", duration + 0.5, 1, function()
            if freelookEnabled then
                print("Backup camera timer triggered")
                RestoreCamera()
            end
        end)
        
        print("Freelook camera enabled for " .. duration .. " seconds")
    end
    
    function RestoreCamera()
        if not freelookEnabled then return end
        
        local ply = LocalPlayer()
        
        freelookEnabled = false
        tauntEntity = nil
        gestureEndTime = 0
        
        -- Restore original third person state
        if IsValid(ply) then
            ply.m_bDrawPlayerInThirdPerson = originalThirdPerson
            -- Reset any gesture rates
            ply:SetLayerPlaybackRate(GESTURE_SLOT, 1.0)
        end
        
        -- Clean up all timers
        timer.Remove("TF2_FreelookCamera_Primary")
        timer.Remove("TF2_FreelookCamera_Backup")
        
        print("Freelook camera disabled and controls restored")
    end
    
    -- Handle mouse input for freelook
    hook.Add("InputMouseApply", "TF2_TauntMouseLook", function(cmd, x, y, angle)
        if not freelookEnabled or not IsValid(tauntEntity) or tauntEntity ~= LocalPlayer() then
            return
        end
        
        -- Get mouse sensitivity
        local sensitivity = GetConVar("sensitivity"):GetFloat()
        
        -- Apply mouse movement to camera angles
        cameraAngles.p = math.Clamp(cameraAngles.p - (y * sensitivity * 0.022), -89, 89)
        cameraAngles.y = cameraAngles.y - (x * sensitivity * 0.022)
        
        -- Normalize yaw
        cameraAngles.y = cameraAngles.y % 360
        
        -- Prevent default mouse look
        return true
    end)
    
    -- Handle freelook camera movement
    hook.Add("CreateMove", "TF2_TauntFreelook", function(cmd)
        if not freelookEnabled or not IsValid(tauntEntity) or tauntEntity ~= LocalPlayer() then
            return
        end
        
        -- Disable all movement during taunt
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
        cmd:SetUpMove(0)
        cmd:SetButtons(0)
        
        -- Don't let the player change view angles normally
        cmd:SetViewAngles(tauntEntity:EyeAngles())
    end)
    
    -- Override camera view for third person freelook
    hook.Add("CalcView", "TF2_TauntCamera", function(ply, pos, angles, fov)
        if not freelookEnabled or not IsValid(tauntEntity) or tauntEntity ~= ply then
            return
        end
        
        -- Get player position
        local playerEyePos = ply:EyePos()
        
        -- Calculate camera position based on angles and distance
        local forward = cameraAngles:Forward()
        local cameraPos = playerEyePos - (forward * cameraDistance)
        
        -- Trace to prevent camera going through walls
        local trace = util.TraceLine({
            start = playerEyePos,
            endpos = cameraPos,
            filter = ply,
            mask = MASK_SOLID_BRUSHONLY
        })
        
        if trace.Hit then
            cameraPos = trace.HitPos + (trace.HitNormal * 5)
        end
        
        -- Return custom view
        local view = {}
        view.origin = cameraPos
        view.angles = cameraAngles
        view.fov = fov
        view.drawviewer = true
        
        return view
    end)
    
    -- Handle mouse wheel for camera distance
    hook.Add("PlayerBindPress", "TF2_TauntCameraZoom", function(ply, bind, pressed)
        if not freelookEnabled or not IsValid(tauntEntity) or tauntEntity ~= ply then
            return
        end
        
        if pressed then
            if bind == "invprev" then
                cameraDistance = math.Clamp(cameraDistance - 20, 50, 300)
                return true
            elseif bind == "invnext" then
                cameraDistance = math.Clamp(cameraDistance + 20, 50, 300)
                return true
            end
        end
    end)
    
    -- Monitor taunting players and force end if needed
    hook.Add("Think", "TF2_ClientTauntMonitor", function()
        for ply, tauntData in pairs(tauntingPlayers) do
            if not IsValid(ply) then
                -- Clean up visual effects before removing
                StopVisualEffects(ply)
                tauntingPlayers[ply] = nil
                continue
            end
            
            -- Check if taunt should have ended
            if CurTime() >= tauntData.endTime then
                print("Client forcing taunt end for " .. ply:Name())
                
                -- Reset face flex if needed
                if tauntData.hasFaceFlex and tauntData.flexName then
                    local flexID = ply:GetFlexIDByName(tauntData.flexName)
                    if flexID and flexID >= 0 then
                        ply:SetFlexWeight(flexID, 0)
                    end
                end
                
                -- Stop visual effects
                StopVisualEffects(ply)
                
                tauntingPlayers[ply] = nil
                
                -- If it's local player, restore camera
                if ply == LocalPlayer() and freelookEnabled then
                    RestoreCamera()
                end
            end
        end
    end)
    
    -- Visual feedback for taunting players
    hook.Add("PostPlayerDraw", "TF2_TauntEffects", function(ply)
        if not tauntingPlayers[ply] then return end
        
        -- Optional: Add additional visual effects here
    end)
    
    -- Emergency cleanup on various events
    hook.Add("OnEntityRemoved", "TF2_TauntClientCleanup", function(ent)
        if ent == tauntEntity then
            print("Taunt entity removed, restoring camera")
            RestoreCamera()
        end
        
        if tauntingPlayers[ent] then
            -- Reset face flex before cleanup
            local tauntData = tauntingPlayers[ent]
            if tauntData.hasFaceFlex and tauntData.flexName then
                local flexID = ent:GetFlexIDByName(tauntData.flexName)
                if flexID and flexID >= 0 then
                    ent:SetFlexWeight(flexID, 0)
                end
            end
            
            -- Stop visual effects
            StopVisualEffects(ent)
            tauntingPlayers[ent] = nil
        end
    end)
    
    -- Cleanup on player death
    hook.Add("PostPlayerDeath", "TF2_TauntDeathCleanup", function(ply)
        if ply == LocalPlayer() and freelookEnabled then
            print("Player died during taunt, restoring camera")
            RestoreCamera()
        end
        
        if tauntingPlayers[ply] then
            -- Reset face flex before cleanup
            local tauntData = tauntingPlayers[ply]
            if tauntData.hasFaceFlex and tauntData.flexName then
                local flexID = ply:GetFlexIDByName(tauntData.flexName)
                if flexID and flexID >= 0 then
                    ply:SetFlexWeight(flexID, 0)
                end
            end
            
            -- Stop visual effects
            StopVisualEffects(ply)
            tauntingPlayers[ply] = nil
        end
    end)
    
    -- Cleanup on spawn
    hook.Add("PlayerSpawn", "TF2_TauntSpawnCleanup", function(ply)
        if ply == LocalPlayer() and freelookEnabled then
            print("Player spawned during taunt, restoring camera")
            RestoreCamera()
        end
        
        -- Clean up any lingering effects
        if tauntingPlayers[ply] then
            StopVisualEffects(ply)
        end
    end)
    
    -- Force cleanup if something goes wrong
    hook.Add("HUDPaint", "TF2_TauntEmergencyCleanup", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        -- If freelook is enabled but player is not taunting, force cleanup
        if freelookEnabled and not tauntingPlayers[ply] then
            print("Emergency cleanup: freelook enabled but not taunting")
            RestoreCamera()
        end
        
        -- If gesture end time has passed, force cleanup
        if freelookEnabled and gestureEndTime > 0 and CurTime() > gestureEndTime + 2 then
            print("Emergency cleanup: gesture end time exceeded")
            RestoreCamera()
        end
    end)
    
    -- Clean up visual effects when map changes
    hook.Add("InitPostEntity", "TF2_TauntMapCleanup", function()
        activeParticles = {}
        tauntingPlayers = {}
        RestoreCamera()
    end)
end

-- Utility function to check if player is taunting (can be called from other scripts)
function IsTaunting(ply)
    if SERVER then
        return tauntingPlayers and tauntingPlayers[ply] or false
    else
        return tauntingPlayers and tauntingPlayers[ply] ~= nil
    end
end

-- Console command for emergency cleanup (client-side)
if CLIENT then
    concommand.Add("tf2_taunt_cleanup", function()
        if freelookEnabled then
            print("Manual taunt cleanup executed")
            RestoreCamera()
        else
            print("No active taunt to cleanup")
        end
        
        -- Clean up any lingering visual effects
        for ply, particle in pairs(activeParticles) do
            StopVisualEffects(ply)
        end
        
        -- Reset all face flexes
        for ply, tauntData in pairs(tauntingPlayers) do
            if IsValid(ply) then
                if tauntData.hasFaceFlex and tauntData.flexName then
                    local flexID = ply:GetFlexIDByName(tauntData.flexName)
                    if flexID and flexID >= 0 then
                        ply:SetFlexWeight(flexID, 0)
                    end
                end
            end
        end
        
        tauntingPlayers = {}
        print("Full taunt system cleanup completed")
    end)
    
    -- Console command to test visual effects
    concommand.Add("tf2_test_visual_effect", function(ply, cmd, args)
        local effectType = args[1] or "none"
        RunConsoleCommand("taunt_visual_effect", effectType)
        print("Set visual effect to: " .. effectType)
        
        -- Show available effects
        if effectType == "help" or effectType == "list" then
            print("Available visual effects:")
            print("- saxton (vsh_body_aura)")
            print("- horseless (utaunt_cremation_purple_parent)")
            print("- dragonfly (utaunt_dragonfly_purple_parent)")
            print("- space (utaunt_astralbodies_teamcolor - team based)")
            print("- blizzard (utaunt_innerblizzard_teamcolor - team based)")
            print("- none (no effects)")
        end
    end)
    
    -- Console command to show current taunt status
    concommand.Add("tf2_taunt_status", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then
            print("Player not valid")
            return
        end
        
        print("=== TF2 Taunt System Status ===")
        print("Model: " .. (ply:GetModel() or "unknown"))
        print("Freelook enabled: " .. tostring(freelookEnabled))
        print("Visual effect: " .. GetConVar("taunt_visual_effect"):GetString())
        
        local weapon = ply:GetActiveWeapon()
        if IsValid(weapon) then
            print("Active weapon: " .. weapon:GetClass())
        else
            print("Active weapon: none")
        end
        
        if tauntingPlayers[ply] then
            local tauntData = tauntingPlayers[ply]
            print("Currently taunting: " .. (tauntData.gestureName or "unknown"))
            print("Time remaining: " .. math.max(0, tauntData.endTime - CurTime()) .. "s")
        else
            print("Currently taunting: no")
        end
        
        print("Active particles: " .. table.Count(activeParticles))
        print("Tracked taunting players: " .. table.Count(tauntingPlayers))
    end)
end

-- Server-side console commands
if SERVER then
    concommand.Add("tf2_force_end_taunt", function(ply, cmd, args)
        if not IsValid(ply) then return end
        
        local targetName = args[1]
        if not targetName then
            -- End taunt for the player who ran the command
            if tauntingPlayers[ply] then
                EndTaunt(ply)
                print("Ended taunt for " .. ply:Name())
            else
                print("You are not currently taunting")
            end
            return
        end
        
        -- Find target player by name (admin only)
        if not ply:IsAdmin() then
            print("You must be an admin to end other players' taunts")
            return
        end
        
        local targetPly = nil
        for _, p in pairs(player.GetAll()) do
            if string.find(string.lower(p:Name()), string.lower(targetName)) then
                targetPly = p
                break
            end
        end
        
        if IsValid(targetPly) then
            if tauntingPlayers[targetPly] then
                EndTaunt(targetPly)
                print("Ended taunt for " .. targetPly:Name())
            else
                print(targetPly:Name() .. " is not currently taunting")
            end
        else
            print("Player not found: " .. targetName)
        end
    end)
    
    concommand.Add("tf2_taunt_server_status", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then
            print("Admin only command")
            return
        end
        
        print("=== TF2 Taunt Server Status ===")
        print("Currently taunting players: " .. table.Count(tauntingPlayers))
        
        for taunter, data in pairs(tauntingPlayers) do
            if IsValid(taunter) then
                local remaining = math.max(0, data.startTime + data.duration - CurTime())
                print("- " .. taunter:Name() .. ": " .. (data.config and data.config.gesture or "unknown") .. " (" .. math.Round(remaining, 1) .. "s remaining)")
            end
        end
        
        print("Visual effect setting: " .. GetConVar("taunt_visual_effect"):GetString())
    end)
    
    concommand.Add("tf2_set_server_visual_effect", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then
            print("Admin only command")
            return
        end
        
        local effectType = args[1] or "none"
        RunConsoleCommand("taunt_visual_effect", effectType)
        
        print("Set server visual effect to: " .. effectType)
        
        -- Notify all players
        for _, p in pairs(player.GetAll()) do
            if IsValid(p) then
                p:ChatPrint("Server taunt visual effect changed to: " .. effectType)
            end
        end
    end)
end


