local CUSTOM_ICON_PATH = "Interface\\AddOns\\SquishyFrames\\egg-icon"
local CUSTOM_ICON_HEAL_PATH = "Interface\\AddOns\\SquishyFrames\\egg-icon-heal"
local CUSTOM_ICON_DANGER_PATH = "Interface\\AddOns\\SquishyFrames\\egg-icon-danger"

UFL_CustomIcons = UFL_CustomIcons or {}
UFL_DeathOverlays = UFL_DeathOverlays or {}
local previousFrameHeights = {}  -- Store frame heights to detect changes

-- Function to update the icon size based on the frame's height
local function UpdateIconSize(frame)
    local frameHeight = frame:GetHeight()
    local iconSize = frameHeight * 0.5  -- Icon size is 50% of the frame's height

    -- If frame height has changed, update the icon size
    if previousFrameHeights[frame] ~= frameHeight then
        previousFrameHeights[frame] = frameHeight  -- Store the new frame height

        if frame.customIcon then
            frame.customIcon:SetSize(iconSize, iconSize)
        end
    end
end

-- Lazy-load utility function to create custom icon and overlay if they don't already exist
local function EnsureCustomIconAndOverlay(frame)
    -- First ensure that the icon size is updated based on the frame height
    UpdateIconSize(frame)

    if not frame.customIcon then
        -- Create custom icon when it's needed for the first time
        local icon = frame:CreateTexture(nil, "OVERLAY")

        -- Set the icon size dynamically based on 50% of the frame height
        local frameHeight = frame:GetHeight()
        icon:SetSize(frameHeight * 0.5, frameHeight * 0.5)  -- Icon size is 50% of frame height

        -- Align icon to the bottom-left with 5% padding for both left and bottom
        local frameWidth = frame:GetWidth()
        local padding = frameWidth * 0.05  -- Calculate 5% padding
        icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", padding, padding)  -- Bottom-left alignment

        icon:SetTexture(CUSTOM_ICON_PATH)
        icon:Hide()  -- Hide by default, shown as needed
        frame.customIcon = icon
        table.insert(UFL_CustomIcons, icon)
    end

    if not frame.deathOverlay then
        -- Create death overlay only when needed for the first time
        local overlay = frame:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints(frame)  -- Static position set once
        overlay:SetColorTexture(0, 0, 0, 0.9)  -- Static color set once
        overlay:Hide()  -- Hide by default, shown as needed
        frame.deathOverlay = overlay
        table.insert(UFL_DeathOverlays, overlay)
    end
end

-- Function to set up the black death overlay and custom icons on a unit frame lazily
function SetCustomIconAndOverlay(frame)
    -- Only load the icon and overlay when needed
    EnsureCustomIconAndOverlay(frame)
end

-- Function to update the icon on unit frames based on health and absorb status
function UpdateUnitFrameIconAndOverlay(frame)
    if not frame or not frame.customIcon or not frame.deathOverlay then return end

    local unit = frame.unit
    if unit and UnitExists(unit) then
        local currentHealth = UnitHealth(unit)
        local maxHealth = UnitHealthMax(unit)
        local absorb = UnitGetTotalAbsorbs(unit)
        local effectiveHealth = currentHealth + absorb
        local isDead = UnitIsDeadOrGhost(unit)

        -- Update icon size in case frame size has changed
        UpdateIconSize(frame)

        -- If the player is dead, show the death overlay
        if isDead then
            frame.deathOverlay:Show()
            frame.customIcon:Hide()
        else
            frame.deathOverlay:Hide()

            -- Calculate effective health percentage
            local effectiveHealthPercent = effectiveHealth / maxHealth
            local isSquishy = _G["unitHealthStatuses"][unit] == "Squishy"

            -- Priority 1: Show the Heal icon if effective health < 50%
            if effectiveHealthPercent < 0.5 then
                frame.customIcon:SetTexture(CUSTOM_ICON_HEAL_PATH)
                frame.customIcon:Show()

            -- Priority 2: Show the Danger icon if non-squishy players < 60% or squishy players < 75%
            elseif (not isSquishy and effectiveHealthPercent < 0.6) or (isSquishy and effectiveHealthPercent < 0.75) then
                frame.customIcon:SetTexture(CUSTOM_ICON_DANGER_PATH)
                frame.customIcon:Show()

            -- Priority 3: Show the Squishy icon if health is in the squishy range
            elseif isSquishy then
                frame.customIcon:SetTexture(CUSTOM_ICON_PATH)
                frame.customIcon:Show()

            -- Hide icon if no conditions are met
            else
                frame.customIcon:Hide()
            end
        end
    else
        -- Hide both the icon and overlay if the unit doesn't exist
        frame.customIcon:Hide()
        frame.deathOverlay:Hide()
    end
end

-- Function to process party frames dynamically
function ProcessPartyFrames()
    local i = 1
    while true do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            SetCustomIconAndOverlay(frame)
            UpdateUnitFrameIconAndOverlay(frame)
            i = i + 1
        else
            break
        end
    end
end

-- Function to process raid frames dynamically
function ProcessRaidFrames()
    local i = 1
    while true do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            SetCustomIconAndOverlay(frame)
            UpdateUnitFrameIconAndOverlay(frame)
            i = i + 1
        else
            break
        end
    end
end

-- Function to remove all custom icons and overlays
function RemoveAllCustomIconsAndOverlays()
    for _, icon in ipairs(UFL_CustomIcons) do
        if icon then icon:Hide() end
    end
    for _, overlay in ipairs(UFL_DeathOverlays) do
        if overlay then overlay:Hide() end
    end
end