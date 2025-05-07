local BetterVehicleFirstPerson = { version = "1.5.0" }
local Config = require("Modules/Config")
local GameSession = require("Modules/GameSession")
local Cron = require("Modules/Cron")
local GameSettings = require("Modules/GameSettings")

local initialFOV = 51
local initialSensitivity = 50

local enabled = true
local maintainFOVEnabled = true
local disabledByApi = false
local isInGame = false

local isInVehicle = false
local isWeaponDrawn = false
local wasWeaponDrawn = false
local curVehicle = nil
local isYFlipped = false

local API = {}

local ui = {
	tooltip = function(text, alwaysShow)
		if alwaysShow and ImGui.IsItemHovered() and text ~= "" then
			ImGui.BeginTooltip()
			ImGui.SetTooltip(text)
			ImGui.EndTooltip()
		end
	end
}

function InvisibleButton(text, active)
    
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.ButtonTextAlign, 0.5, 0.5)

    ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(1, 0, 0, 0))
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(0, 0, 0, 0))
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(0, 0, 0, 0))

    if active then
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 1, 0.7, 1))
    end

    ImGui.Button(text)


    if active then
        ImGui.PopStyleColor(1)
    end

    ImGui.PopStyleColor(3)

    ImGui.PopStyleVar(4)
end

function API.Enable()
  enabled = true
  RefreshCameraIfNeeded()
end

function API.Disable()
  enabled = false
  RefreshCameraIfNeeded()
end

function API.IsEnabled()
  return enabled
end

function IsEnteringVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).entering
end
function IsExitingVehicle()
    return IsInVehicle() and Game.GetWorkspotSystem():GetExtendedInfo(Game.GetPlayer()).exiting
end

function HasWeapon()
    local player = Game.GetPlayer()
    if player then
      local ts = Game.GetTransactionSystem()
      return ts and ts:GetItemInSlot(player, TweakDBID.new("AttachmentSlots.WeaponRight")) ~= nil
    end
    return false
end

function IsInVehicle()
    local player = Game.GetPlayer()
    return player and Game.GetWorkspotSystem():IsActorInWorkspot(player)
            and Game.GetWorkspotSystem():GetExtendedInfo(player).isActive
            and HasMountedVehicle()
            and IsPlayerDriver()
end

function SetFOV(fov)
    if fov ~= nil then
        Config.data.fov = fov
    end

    Game.GetPlayer():GetFPPCameraComponent():SetFOV(Config.data.fov)
end
function GetFOV()
    return Game.GetPlayer():GetFPPCameraComponent():GetFOV()
end
function ResetFOV()
    Game.GetPlayer():GetFPPCameraComponent():SetFOV(initialFOV)
end

function ChangeSensitivity(sensitivity)
	if sensitivity ~= nil then
		Config.data.sensitivity = sensitivity
	end

	GameSettings.Set('/controls/SteeringSensitivity', Config.data.sensitivity)
end
function ResetSensitivity()
	return ChangeSensitivity(initialSensitivity)
end


function TiltCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new((-0.06 * Config.data.tiltMult), 0.0, 0.0, 1.0))
end

function ResetTilt()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.00, 0.0, 0.0, 1.0))
end

function RaiseCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new((0.02 * Config.data.xMult), -(0.02 * Config.data.zMult), (0.09 * Config.data.yMult), 1.0))
end

function ResetCamera()
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new((0.02 * Config.data.xMult), 0, 0, 1.0))
end

function FlipY()
	GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
	GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
    isYFlipped = not isYFlipped
end
function DoubleCheckY()
	if isYFlipped then
		GameSettings.Toggle('/controls/fppcameramouse/FPP_MouseInvertY')
		GameSettings.Toggle('/controls/fppcamerapad/FPP_PadInvertY')
		isYFlipped = false
    end
end

function StartPeek()
    local player = Game.GetPlayer()
    local vehicle = Game['GetMountedVehicle;GameObject'](player)
    if vehicle then
        if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
			player:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
		end
    end

    Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 100, 1.0))
    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(-0.6, 0.0, 0.01, 1.0))
    FlipY()
end
function StopPeek()
    local player = Game.GetPlayer()
    local vehicle = Game['GetMountedVehicle;GameObject'](player)
    if vehicle then
        if not Game.GetPlayer():FindVehicleCameraManager():IsTPPActive() then
            player:QueueEvent(NewObject('handle:vehicleCameraResetEvent'))
        end
    end

    FlipY()
    DoubleCheckY()
    if enabled then
        TiltCamera()
        RaiseCamera()
    else
        Game.GetPlayer():GetFPPCameraComponent():SetLocalOrientation(Quaternion.new(0.0, 0.0, 0, 1.0))
        Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0.0, 0.0, 0.0, 1.0))
    end
end

function SaveConfig()
    Config.SaveConfig()
    DoubleCheckY()
end

function HasMountedVehicle()
    return not not Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
end
function IsPlayerDriver()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:IsPlayerDriver()
    end
end
function GetMountedVehicleRecord()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:GetRecord()
    end
end

function IsPlayerDriver()
    local veh = Game['GetMountedVehicle;GameObject'](Game.GetPlayer())
    if veh then
        return veh:IsPlayerDriver()
    end
end

function GetCurrentPreset()
    return { Config.data.tiltMult, Config.data.yMult, Config.data.zMult, Config.data.fov, Config.data.sensitivity, Config.data.xMult }
end

function GetVehicleMan(vehicle)
    if vehicle:Manufacturer():Type().value == "Invalid" then
        return vehicle:GetID().value
    else
        return vehicle:Manufacturer():Type().value
    end
end

function GetVehicleModel(vehicle)
    return vehicle:Model():Type().value
end

function SetGlobalPreset()
    local gKey = ("global_preset")
    local gPreset = {
        ["man"] = "global",
        ["model"] = "n/a",
        ["preset"] = GetCurrentPreset()
    }

    Config.data.perCarPresets[gKey] = gPreset

    SaveConfig()
end

function AddVehiclePreset()
    local vehicle = curVehicle or GetMountedVehicleRecord()

    local vehMan = GetVehicleMan(vehicle)
    local vehModel = GetVehicleModel(vehicle)
    local vehKey = (vehMan .. vehModel)
    local vehPreset = {
        ["man"] = vehMan,
        ["model"] = vehModel,
        ["preset"] = GetCurrentPreset()
    }

    Config.data.perCarPresets[vehKey] = vehPreset

    SaveConfig()
end

function GetGlobalPreset()
    local gKey = "global_preset"
    local gPreset = Config.data.perCarPresets[gKey]

    if gPreset then
        -- Ensure xMult is present in the global preset
        if not gPreset.preset[6] then
            gPreset.preset[6] = 0 -- Default to 0 if missing
        end
        return gPreset.preset
    end

    return nil
end

function GetVehiclePreset(vehicle)
    if not vehicle then
        return nil
    end

    local vehMan = GetVehicleMan(vehicle)
    local vehModel = GetVehicleModel(vehicle)
    local vehKey = (vehMan .. vehModel)
    local vehPreset = Config.data.perCarPresets[vehKey]
    if vehPreset then
        -- Ensure xMult is present in the preset
        if not vehPreset.preset[6] then
            vehPreset.preset[6] = 0 -- Default to 0 if missing
        end
        return vehPreset.preset
    end

    return nil
end

function ApplyAutoPreset()
    local vehicle = GetMountedVehicleRecord()
    curVehicle = vehicle

    if Config.data.autoSetPerCar then
        local preset = GetVehiclePreset(vehicle)
        local gPreset = GetGlobalPreset()

        if preset then
            ApplyPreset(preset)
            RefreshCameraIfNeeded()
        elseif gPreset then
            ApplyPreset(gPreset)
            RefreshCameraIfNeeded()
        end
    else
        local gPreset = GetGlobalPreset()
        if gPreset then
            ApplyPreset(gPreset)
            RefreshCameraIfNeeded()
        end
    end
end

function OnVehicleEntered()
    initialSensitivity = GameSettings.Get('/controls/SteeringSensitivity')

    ApplyAutoPreset()

    -- TODO: is this ever changing for different players?
    -- initialFOV = GetFOV()
    if not enabled then
        return
    end

    TiltCamera()
    RaiseCamera()

    SetFOV()

    ChangeSensitivity()
end

function OnVehicleEntering()
    if not enabled then
        ResetCamera()
        ResetTilt()
        return
    end

    TiltCamera()
    RaiseCamera()
end

function OnVehicleExiting()
    ResetCamera()
    ResetTilt()
    ResetFOV()
    ResetSensitivity()
    curVehicle = nil
end

function OnVehicleExited()
    if enabled then
        ResetCamera()
        ResetTilt()
        ResetSensitivity()
    end
end

function RefreshCameraIfNeeded()
    SaveConfig()
    if isInVehicle and enabled then
        TiltCamera()
        RaiseCamera()
        SetFOV()
        ChangeSensitivity()
    elseif isInVehicle and not enabled then
        ResetCamera()
        ResetTilt()
        ResetFOV()
        ResetSensitivity()
    end
end

function RefreshWeaponFOVIfNeeded()
    if isInVehicle and HasWeapon() and maintainFOVEnabled then
        SetFOV()
    elseif isInVehicle and HasWeapon() and not maintainFOVEnabled then
        ResetFOV()
    end
end

local presets = {
    -- default
    { 1.150, 0.9, -0.2, 56, 50 },
    { 1.050, 0.8, -3.810, 58, 50 },
    { 1.170, 0.810, 7, 49, 50 },
    { 0.950, 0.610, -10, 70, 50 },
    { 0.950, 0.500, -13, 87, 50 },
    -- car-specific
    -- ...
}

function IsSamePreset(pr)
    return math.abs(Config.data.tiltMult - pr[1]) < 0.01 and
            math.abs(Config.data.yMult - pr[2]) < 0.01 and
            math.abs(Config.data.zMult - pr[3]) < 0.01 and
            math.abs(Config.data.fov - pr[4]) < 0.01 and
            math.abs(Config.data.sensitivity - pr[5]) < 0.01 and
            math.abs(Config.data.xMult - pr[6]) < 0.01
end

function DeletePreset(key)
    Config.data.perCarPresets[key] = nil
    SaveConfig()
end
function ApplyPreset(pr)
    Config.data.tiltMult = pr[1]
    Config.data.yMult = pr[2]
    Config.data.zMult = pr[3]
    Config.data.fov = pr[4]
    Config.data.sensitivity = pr[5]
    Config.data.xMult = pr[6] or 0 -- Default to 0 if missing
end


function BetterVehicleFirstPerson:New()
    registerForEvent("onInit", function()
        initialSensitivity = GameSettings.Get('/controls/SteeringSensitivity')
        Config.InitConfig()

        Cron.Every(0.2, function()

            --Disabled during GUI dev


--[[             if not enabled then
              return
            end

            if not Config or not Config.isReady then
                return
            end

            if not isInGame then
              return
            end ]]

            local isInVehicleNext = IsInVehicle() and not IsEnteringVehicle() and not IsExitingVehicle()
            local isWeaponDrawnNext = HasWeapon()

            if IsEnteringVehicle() then
                OnVehicleEntering()
            elseif IsExitingVehicle() then
                OnVehicleExiting()
            elseif isInVehicleNext == true and isInVehicle == false then
                OnVehicleEntered()
            elseif isInVehicleNext == false and isInVehicle == true then
                OnVehicleExited()
            end

            -- Override FOV reset when weapon is drawn in vehicle
            if isInVehicle then
                if isWeaponDrawnNext and not wasWeaponDrawn and maintainFOVEnabled then
                    SetFOV() -- Weapon drawn: maintain FOV when setting is enabled
                elseif not isWeaponDrawnNext and wasWeaponDrawn then
                    SetFOV() -- Weapon holstered: set FOV back to vehicle preset (also applies when choosing not to maintain FOV with weapon use)
                end
            end

            if isInVehicle then
                if isWeaponDrawnNext and not wasWeaponDrawn then
                    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new(0, -(0.02 * Config.data.zMult), (0.09 * Config.data.yMult), 1.0))
                elseif not isWeaponDrawnNext and wasWeaponDrawn then
                    Game.GetPlayer():GetFPPCameraComponent():SetLocalPosition(Vector4.new((0.02 * Config.data.xMult), -(0.02 * Config.data.zMult), (0.09 * Config.data.yMult), 1.0))
                end
            end
            
            isInVehicle = isInVehicleNext
            wasWeaponDrawn = isWeaponDrawn -- Track last weapon state explicitly
            isWeaponDrawn = isWeaponDrawnNext
        end, {})

        Observe('hudCarController', 'RegisterToVehicle', function(_, registered)
            if not registered then
                OnVehicleExited()
            end
        end)

        -- Fires with loaded save file too
        Observe('hudCarController', 'OnPlayerAttach', function()
            if isInVehicle and enabled then
                RefreshCameraIfNeeded()
            end
        end)

        -- Fires when execting
        Observe('hudCarController', 'OnUnmountingEvent', function()
            OnVehicleExited()
        end)

        GameSession.OnStart(function()
          isInGame = true
        end)

        GameSession.OnEnd(function()
          isInGame = false
        end)

        GameSession.OnPause(function()
          isInGame = false
        end)

        GameSession.OnResume(function()
          isInGame = true
        end)
    end)

    registerForEvent("onOverlayOpen", function() isOverlayOpen = true end)
    registerForEvent("onOverlayClose", function() isOverlayOpen = false end)

    registerForEvent("onUpdate", function(delta)
        Cron.Update(delta)
    end)

    registerInput("peek", "Peek Through Window", function(keydown)
        if not IsInVehicle() then
            DoubleCheckY()
            return
        end

        if keydown then
            StartPeek()
        else
            StopPeek()
        end
    end)
    registerHotkey("VehicleFPPCameraEnabled", "Toggle Enabled", function()
        if isInVehicle then
            enabled = not enabled
            RefreshCameraIfNeeded()
        end
    end)

    registerForEvent("onDraw", function()

        if not isOverlayOpen or not Config or not Config.isReady then
            return
        end

        ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 3)
        ImGui.PushStyleColor(ImGuiCol.ScrollbarBg, ImGui.GetColorU32(0, 0, 0, 0))
        ImGui.PushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.GetColorU32(0.8, 0.8, 1, 0.4))

        local screenWidth, screenHeight = GetDisplayResolution()

        -- Set window size constraints
        ImGui.SetNextWindowSizeConstraints(screenWidth * 0.15, screenWidth * 0.15, screenWidth / 100 * 50, screenHeight / 100 * 90)

        -- Set initial window position and size
        ImGui.SetNextWindowPos(200, 200, ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSize(250, 260, ImGuiCond.FirstUseEver)

        ImGui.Begin("Better Vehicle First Person")
        ImGui.SetWindowFontScale(1)

        -- toggle enabled / maintain FOV when using weapons
        enabled, toggleEnabled = ImGui.Checkbox("Enabled", enabled)
        maintainFOVEnabled, toggleMaintainFOVEnabled = ImGui.Checkbox("Maintain FOV when using weapons", maintainFOVEnabled)
        if toggleEnabled then
            RefreshCameraIfNeeded()
        end
        if toggleMaintainFOVEnabled then
            RefreshWeaponFOVIfNeeded()
        end

        if enabled and isInVehicle then
			local globalVehiclePreset = GetGlobalPreset()
            local curVehiclePreset = GetVehiclePreset(GetMountedVehicleRecord())
            if not curVehiclePreset or not IsSamePreset(curVehiclePreset) then
                --ImGui.PushStyleColor(ImGuiCol.Text, 0.60, 0.40, 0.20, 1.0)
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.53, 0.14, 1.0)

				if not globalVehiclePreset then
					ImGui.Text(" THESE VALUES HAVEN'T YET BEEN SAVED ")
				else
					if not IsSamePreset(globalVehiclePreset) then
						ImGui.Text(" THESE VALUES HAVEN'T YET BEEN SAVED ")
					else
						ImGui.Text("")
					end
				end

                ImGui.PopStyleColor(1)
            else
                ImGui.Text("")
            end

            ImGui.Dummy(0, 4)
            ImGui.Text("Adjustments")
            ImGui.Separator()

            -- Tilt control
            InvisibleButton(IconGlyphs.PanVertical, false)
            ui.tooltip("Adjust the tilt angle of the player viewport.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
            Config.data.tiltMult, isTiltChanged = ImGui.SliderFloat("##tiltAngle", Config.data.tiltMult, -1, 5)
            if isTiltChanged then
                RefreshCameraIfNeeded()
            end

            -- Horizontal Offset control
            InvisibleButton(IconGlyphs.AlphaXBox, false)
            ui.tooltip("Adjust the horizontal offset.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
            Config.data.xMult, isXChanged = ImGui.SliderFloat("##xMult", Config.data.xMult, -2, 5)
            if isXChanged then
                RefreshCameraIfNeeded()
            end

            -- Y control
            InvisibleButton(IconGlyphs.AlphaYBox, false)
            ui.tooltip("Adjust the vertical offset.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
            Config.data.yMult, isYChanged = ImGui.SliderFloat("##yMult", Config.data.yMult, -2, 3)
            if isYChanged then
                RefreshCameraIfNeeded()
            end

            -- Z control
            InvisibleButton(IconGlyphs.AlphaZBox, false)
            ui.tooltip("Adjust the depth offset.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
            Config.data.zMult, isZChanged = ImGui.SliderFloat("##zMult", Config.data.zMult, -70, 15)
            if isZChanged then
                RefreshCameraIfNeeded()
            end

            -- FOV control
            InvisibleButton(IconGlyphs.AngleAcute, false)
            ui.tooltip("Set the first person FOV while driving.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
            Config.data.fov, isFovChanged = ImGui.SliderFloat("##fov", Config.data.fov, 30, 95)
            if isFovChanged then
                RefreshCameraIfNeeded()
            end

			-- Sensitivity control
			InvisibleButton(IconGlyphs.Steering, false)
            ui.tooltip("Set the steering sensitivity.", true)
            ImGui.SameLine()
            ImGui.SetNextItemWidth(ImGui.GetWindowContentRegionWidth() - ImGui.GetCursorPosX())
			Config.data.sensitivity, isSensitivityChanged = ImGui.SliderFloat("##steeringSensitivity", Config.data.sensitivity, 0, 100)
			if isSensitivityChanged then
                RefreshCameraIfNeeded()
			end

            ImGui.Dummy(0, 4)
            ImGui.Text("Presets ")
            ImGui.Separator()

            local presetButtonCount = 5
            local padding = 18 -- Add padding to the left and right of buttons
            local presetButtonWidth = (ImGui.GetWindowContentRegionWidth() - (presetButtonCount - 1) * ImGui.GetStyle().ItemSpacing.x - 2 * padding) / presetButtonCount

            ImGui.Dummy(0, 4)
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + padding) -- Add left padding

            -- Predefined presets
            for i = 1, #presets do
                if ImGui.Button(tostring(i), presetButtonWidth, 0) then
                    ApplyPreset(presets[i])
                    RefreshCameraIfNeeded()
                end
                if ImGui.IsItemHovered() then
                    local pr = presets[i]
                    ImGui.BeginTooltip()
                    ImGui.Text(("Tilt Mult: %.2f"):format(pr[1]))
                    ImGui.Text(("Y Mult: %.2f"):format(pr[2]))
                    ImGui.Text(("Z Mult: %.2f"):format(pr[3]))
                    ImGui.Text(("FOV: %.2f"):format(pr[4]))
                    ImGui.Text(("Sensitivity: %.2f"):format(pr[5]))
                    ImGui.Text(("X Mult: %.2f"):format(pr[6] or 0)) -- Default to 0 if missing
                    ImGui.EndTooltip()
                end
                if i < #presets then
                    ImGui.SameLine()
                end
            end

            ImGui.Dummy(0, 4)
            ImGui.Text("Global Preset ")
            ImGui.Separator()

            -- Save global preset
            if not globalVehiclePreset then
                ImGui.Text(" The global preset ")
                ImGui.Text(" hasn't been established yet. ")

                if ImGui.Button(("Save as new global preset"), ImGui.GetContentRegionAvail(), 0) then
                    SetGlobalPreset()
                end

                ImGui.Separator()
            else
                if not IsSamePreset(globalVehiclePreset) then
                    local function CurSetupIsDiffMsg()
                        ImGui.Text(" Current setup is different from the global preset. ")
                    end
                    if curVehiclePreset then
                        if IsSamePreset(curVehiclePreset) then
                            ImGui.Text(" Vehicle preset overrides the global preset. ")
                        else
                            CurSetupIsDiffMsg()
                        end
                    else
                        CurSetupIsDiffMsg()
                    end

                    -- Save global preset
                    if ImGui.Button(("Save global preset")) then
                        SetGlobalPreset()
                    end

                    -- Reset global preset
                    if ImGui.Button(("Load global preset")) then
                        ApplyPreset(globalVehiclePreset)
                        RefreshCameraIfNeeded()
                    end
                else
                    local function globPresetHasBeenLoadedMsg()
                        ImGui.Text("")
                        ImGui.Text(" The global preset has been loaded! ")
                    end
                    if curVehiclePreset then
                        if IsSamePreset(curVehiclePreset) then
                            ImGui.Text("")
                            ImGui.Text(" The global and vehicle presets are the same")
                        else
                            globPresetHasBeenLoadedMsg()
                        end
                    else
                        globPresetHasBeenLoadedMsg()
                    end

                end
                ImGui.Separator()
            end
            -- Presets manager
            if curVehicle then
                local item = curVehicle and curVehicle:GetRecordID().value -- Ensure `item` is defined
                local carName = GetVehicleMan(curVehicle) .. " " .. GetVehicleModel(curVehicle) -- Fallback name
                if item then
                    local displayName = TweakDB:GetFlat(item .. '.displayName')
                    if displayName then
                        local lockey = Game.GetLocalizedText(displayName)
                        local withoutPrefix = string.gsub(lockey, "LocKey%(", "")
                        local displayNums = string.match(withoutPrefix, "(%d+)")
                        local nameStr = 'LocKey#' .. tostring(displayNums)
                        ImGui.Text("Currently driving: ")
                        ImGui.SameLine()
                        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.86, 0.47, 1.0)
                        ImGui.Text(Game.GetLocalizedText(nameStr))
                        ImGui.PopStyleColor(1)
                    else
                        ImGui.Text("Currently driving: ")
                        ImGui.SameLine()
                        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.86, 0.47, 1.0)
                        ImGui.Text(carName) -- Fallback to carName
                        ImGui.PopStyleColor(1)
                    end
                else
                    ImGui.Text("No vehicle selected.")
                end

                -- Save preset for a vehicle
                if item then
                    local displayName = TweakDB:GetFlat(item .. '.displayName')
                    if curVehiclePreset then
                        local lockey = Game.GetLocalizedText(displayName)
                        local withoutPrefix = string.gsub(lockey, "LocKey%(", "")
                        local displayNums = string.match(withoutPrefix, "(%d+)")
                        local nameStr = 'LocKey#' .. tostring(displayNums)
                        if not IsSamePreset(curVehiclePreset) then
                            if ImGui.Button("Update '" .. Game.GetLocalizedText(nameStr) .. "' preset") then
                                AddVehiclePreset()
                            end
                        else
                            ImGui.BeginDisabled()
                            if ImGui.Button(("Current vehicle preset has been loaded"), ImGui.GetContentRegionAvail(), 0) then
                            end
                            ImGui.EndDisabled()
                        end
                    else
                        local lockey = Game.GetLocalizedText(displayName)
                        local withoutPrefix = string.gsub(lockey, "LocKey%(", "")
                        local displayNums = string.match(withoutPrefix, "(%d+)")
                        local nameStr = 'LocKey#' .. tostring(displayNums)
                        if ImGui.Button("Save new '" .. Game.GetLocalizedText(nameStr) .. "' preset", ImGui.GetContentRegionAvail(), 0) then
                            AddVehiclePreset()
                        end
                    end
                else
                    ImGui.Text("No vehicle selected.")
                end

                -- Reset preset
                if curVehiclePreset and not IsSamePreset(curVehiclePreset) then
                    ImGui.SameLine()
                    if ImGui.Button(IconGlyphs.Restore, ImGui.GetContentRegionAvail(), 0) then
                        ApplyPreset(curVehiclePreset)
                        RefreshCameraIfNeeded()
                    end
                    ui.tooltip("Reset to the current vehicle preset.", true)
                end

                ImGui.Dummy(0, 4)
                ImGui.Separator()
                ImGui.Text("Individual Presets")

                ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetColorU32(0.65, 0.7, 1, 0.045))
                ImGui.BeginChild("percarpresets", ImGui.GetContentRegionAvail(), 400)

                local childPadding = 20 -- Define padding for left and right
                ImGui.Dummy(0, 10) -- Add vertical padding at the top
                -- Preset list
                for i, pr in pairs(Config.data.perCarPresets) do
                    if pr.man ~= "global" then
                        local isSamePreset = IsSamePreset(pr.preset)

                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + childPadding)

                        -- Load Preset Button
                        ImGui.PushID(tostring(i))
                        if isSamePreset then
                            ImGui.BeginDisabled(true)
                            ImGui.Button(IconGlyphs.CheckBold, 120, 0) -- Show checkmark for loaded preset
                            ImGui.EndDisabled()
                        else
                            if ImGui.Button("Load", 120, 0) then -- Show upload glyph for other presets
                                ApplyPreset(pr.preset)
                                RefreshCameraIfNeeded()
                            end
                        end
                        ImGui.PopID()
                        ImGui.SameLine()

                        -- Delete Preset Button
                        ImGui.PushID("del" .. tostring(i))
                        ImGui.PushStyleColor(ImGuiCol.Button, ImGui.GetColorU32(1, 0.3, 0.3, 1))
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImGui.GetColorU32(1, 0.45, 0.45, 1))
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImGui.GetColorU32(1, 0.45, 0.45, 1))
                        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0, 0, 0, 1))
                        if ImGui.Button(IconGlyphs.TrashCanOutline, 0, 0) then -- Make button square
                            DeletePreset((pr.man .. pr.model))
                        end
                        ImGui.PopStyleColor(4)
                        ImGui.PopID()
                        ImGui.SameLine()

                        -- Preset Name
                        if isSamePreset then
                            ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(0.0, 0.8, 0.5, 1))
                        end
                        ImGui.Text(pr.man .. " " .. pr.model)
                        if isSamePreset then
                            ImGui.PopStyleColor()
                        end
                    end
                end
                ImGui.Dummy(0, 10) -- Add vertical padding at the bottom
                ImGui.EndChild()
                ImGui.PopStyleColor(1)
            end
        end

        ImGui.PopStyleColor(2)
        ImGui.PopStyleVar(1)

        ImGui.End()
    end)

    return {
      version = BetterVehicleFirstPerson.version,
      api = API
    }
end

return BetterVehicleFirstPerson:New()
