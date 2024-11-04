-- Function to disable Blizzard's default sorting in CompactRaidFrameContainer
local function DisableBlizzardSorting()
    if CompactRaidFrameContainer and CompactRaidFrameContainer.flowSortFunc then
        CompactRaidFrameContainer.flowSortFunc = nil
    end
end

-- Declare 'Out of Range' check
local outOfRangeUnits = {}

-- Make unitHealthStatuses global so it can be accessed in icon_overlay.lua
unitHealthStatuses = {}
local healthData = {}

-- Throttle timer
local lastUpdate = 0
local THROTTLE_TIME = 0.2  -- Only process every 0.2 seconds

-- Function to wipe data for players who have left the group
local function ClearOldPlayerData()
    local currentGroup = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            currentGroup[unit] = true
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do  -- Exclude player
            local unit = "party" .. i
            currentGroup[unit] = true
        end
        currentGroup["player"] = true
    else
        currentGroup["player"] = true
    end

    -- Remove players no longer in the group
    for unit in pairs(unitHealthStatuses) do
        if not currentGroup[unit] then
            unitHealthStatuses[unit] = nil
        end
    end
end

-- Helper function to get health percentage
local function GetHealthPercentage(unit)
    local maxHealth = UnitHealthMax(unit)
    if maxHealth == 0 then return 1 end  -- Avoid division by zero
    return UnitHealth(unit) / maxHealth
end

-- Helper function to determine role priority based on the dropdown setting
local function GetRolePriority(role)
    if UFLSettings.roleSortOrder == "Tank, Healers, DPS" then
        if role == "TANK" then return 1
        elseif role == "HEALER" then return 2
        else return 3  -- DPS
        end
    elseif UFLSettings.roleSortOrder == "Tank, DPS, Healers" then
        if role == "TANK" then return 1
        elseif role == "DAMAGER" then return 2
        else return 3  -- Healer
        end
    end
    return 4  -- Default to lowest priority if role is unrecognized
end

-- Cache to store previous health percentages for the "under 100% health" group
local previousHealthPercentages = {}

-- Function to check if any unit's health in the "under 100% health" group has changed by 2% or more
local function ShouldResortUnder100Group(groupUnits)
    for _, unitInfo in ipairs(groupUnits) do
        if unitInfo.healthPercent < 1 then  -- Only check "under 100% health" units
            local prevHealth = previousHealthPercentages[unitInfo.unit] or unitInfo.healthPercent
            if math.abs(unitInfo.healthPercent - prevHealth) >= 0.02 then
                previousHealthPercentages[unitInfo.unit] = unitInfo.healthPercent  -- Update cache
                return true  -- Trigger re-sort if change is 2% or more
            end
            previousHealthPercentages[unitInfo.unit] = unitInfo.healthPercent  -- Update cache
        end
    end
    return false
end


-- Updated Sort function to separate 100% health, in-range players into their own group
-- Updated Sort function to ensure proper grouping of 100% health, in-range players
local function SortGroupUnits(groupUnits)
    table.sort(groupUnits, function(a, b)
        -- Step 1: Tanks always stay at the front in a fixed order
        if a.role == "TANK" and b.role ~= "TANK" then return true end
        if b.role == "TANK" and a.role ~= "TANK" then return false end
        if a.role == "TANK" and b.role == "TANK" then return a.unit < b.unit end

        -- Step 2: Dead players are always at the end, regardless of range, with no sorting within this group
        local aIsDead = UnitIsDeadOrGhost(a.unit)
        local bIsDead = UnitIsDeadOrGhost(b.unit)
        if aIsDead and not bIsDead then return false end
        if bIsDead and not aIsDead then return true end
        if aIsDead and bIsDead then return a.unit < b.unit end


        -- Step 3: Out-of-range players follow dead players, without sorting within this group
        if a.outOfRange and not b.outOfRange then return false end
        if not a.outOfRange and b.outOfRange then return true end
        if a.outOfRange and b.outOfRange then return a.unit < b.unit end

        -- Step 4: Separate 100% health, in-range players to follow tanks, ahead of under-100% in-range players
        if a.healthPercent == 1 and b.healthPercent < 1 then return false end
        if b.healthPercent == 1 and a.healthPercent < 1 then return true end
        if a.healthPercent == 1 and b.healthPercent == 1 then return a.unit < b.unit end

        -- Step 5: In-range players below 100% health are sorted by health percentage and role priority
        if a.healthPercent < 1 and b.healthPercent < 1 then
            if a.healthPercent ~= b.healthPercent then
                return a.healthPercent < b.healthPercent
            else
                -- Fallback to role priority for players below 100% health
                local rolePriorityA = GetRolePriority(a.role)
                local rolePriorityB = GetRolePriority(b.role)
                return rolePriorityA < rolePriorityB
            end
        end
    end)
end


-- Update sorting trigger in UpdateOutOfRangeUnits to apply 2% threshold only to under 100% health group
local function UpdateOutOfRangeUnits()
    local groupUnits = {}  -- Build a unified list for sorting
    local frames = GetAllRaidFrames()  -- Collect all frames

    -- Populate groupUnits based on frame data
    for _, frame in ipairs(frames) do
        local unit = frame.unit
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            local healthPercent = GetHealthPercentage(unit)
            local isOutOfRange = not UnitInRange(unit) and role ~= "TANK"
            table.insert(groupUnits, {unit = unit, outOfRange = isOutOfRange, healthPercent = healthPercent, role = role})
        end
    end

    -- Apply sorting only if under 100% health group has a significant health change or out-of-combat check
    if ShouldResortUnder100Group(groupUnits) or not InCombatLockdown() then
        SortGroupUnits(groupUnits)
    end

    -- Apply sorted units back to frames
    for i, unitInfo in ipairs(groupUnits) do
        local frame = frames[i]
        if frame then
            CompactUnitFrame_SetUnit(frame, unitInfo.unit)
            frame:Show()
        end
    end
end







-- Function to collect all raid frames into a unified list for consistent sorting
local function GetAllRaidFrames()
    local frames = {}

    -- Collect individual CompactRaidFrameX frames
    local i = 1
    while true do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            table.insert(frames, frame)
            i = i + 1
        else
            break
        end
    end

    -- Collect frames within CompactRaidGroupXMemberY groups if they exist
    for groupIndex = 1, NUM_RAID_GROUPS do
        local groupFrame = _G["CompactRaidGroup" .. groupIndex]
        if groupFrame then
            for memberIndex = 1, MEMBERS_PER_RAID_GROUP do
                local memberFrame = groupFrame["member" .. memberIndex]
                if memberFrame then
                    table.insert(frames, memberFrame)
                end
            end
        end
    end

    return frames
end


-- Function to check if Combined Groups mode is enabled
local function IsCombinedGroupsMode()
    return not _G["CompactRaidGroup1"]
end

-- Cache to store previous health percentages to detect significant changes
local previousHealthPercentages = {}

-- Function to update and apply sorting for Combined Groups mode or regular raid layout
-- Function to update and apply sorting for Combined Groups mode or regular raid layout
local function UpdateOutOfRangeUnits()
    local groupUnits = {}  -- Build a unified list for sorting
    local frames = GetAllRaidFrames()  -- Collect all frames

    -- Populate groupUnits based on frame data
    for _, frame in ipairs(frames) do
        local unit = frame.unit
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            local healthPercent = GetHealthPercentage(unit)
            local isOutOfRange = not UnitInRange(unit) and role ~= "TANK"

            -- Add players out of range, under 100% health, or tanks for necessary sorting
            if isOutOfRange or healthPercent < 1 or role == "TANK" then
                table.insert(groupUnits, {unit = unit, outOfRange = isOutOfRange, healthPercent = healthPercent, role = role})
            else
                -- In-range players at 100% health are added only if they differ by role priority
                if UFLSettings.roleSortOrder then
                    table.insert(groupUnits, {unit = unit, outOfRange = isOutOfRange, healthPercent = healthPercent, role = role})
                end
            end
        end
    end

    -- Sort the collected groupUnits
    if ShouldResortUnder100Group(groupUnits) or not InCombatLockdown() then
        SortGroupUnits(groupUnits)
    end
    

    -- Apply sorted units back to frames
    for i, unitInfo in ipairs(groupUnits) do
        local frame = frames[i]
        if frame then
            CompactUnitFrame_SetUnit(frame, unitInfo.unit)
            frame:Show()
        end
    end
end

-- Function to apply an overlay based on the physical display of a debuff icon
local function ApplyDebuffOverlay(frame)
    if not frame or frame:IsForbidden() then return end

    -- Ensure overlay exists
    if not frame.overlay then
        frame.overlay = frame:CreateTexture(nil, "OVERLAY")
        frame.overlay:SetAllPoints()
        frame.overlay:SetColorTexture(0.3, 0.8, 0.7, 0.65)  -- Turquoise/magenta at 30% transparency
    end

    local debuffIconShowing = false

    -- Check if the unit is in range and alive before applying overlay
    local unit = frame.unit
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitInRange(unit) then
        -- Check debuff frames for physical visibility (indicating an active debuff icon)
        for i = 1, frame.maxDebuffs or 3 do
            local debuffFrame = frame.debuffFrames and frame.debuffFrames[i]

            -- Check if debuff frame is physically shown on the bottom-left (debuff location)
            if debuffFrame and debuffFrame:IsShown() and debuffFrame:GetPoint() == "BOTTOMLEFT" then
                debuffIconShowing = true
                break
            end
        end
    end

    -- Toggle overlay based on whether the physical debuff icon is shown
    if debuffIconShowing then
        frame.overlay:Show()
    else
        frame.overlay:Hide()
    end
end

-- Hook into the Blizzard function to detect updates on auras, specifically checking for debuff icon visibility
hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
    ApplyDebuffOverlay(frame)
end)


-- Hook into the Blizzard function that updates auras on unit frames
hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
    ApplyDebuffOverlay(frame)
end)

-- Function to update health statuses
local function UpdateHealthStatuses()
    if InCombatLockdown() and not UFLSettings.updateInCombat then return end

    wipe(unitHealthStatuses)
    wipe(healthData)

    local function CollectHealthData(unit)
        if UnitExists(unit) and UnitGroupRolesAssigned(unit) ~= "TANK" then
            local effectiveHealth = UnitHealthMax(unit) + UnitGetTotalAbsorbs(unit)
            table.insert(healthData, {unit = unit, effectiveHealth = effectiveHealth})
        end
    end

    local totalGroupSize = 0
    if IsInRaid() then
        totalGroupSize = GetNumGroupMembers()
        for i = 1, GetNumGroupMembers() do
            CollectHealthData("raid" .. i)
        end
    elseif IsInGroup() then
        totalGroupSize = GetNumGroupMembers()
        for i = 1, GetNumGroupMembers() - 1 do
            CollectHealthData("party" .. i)
        end
        CollectHealthData("player")
    else
        totalGroupSize = 1
        CollectHealthData("player")
    end

    if totalGroupSize <= 2 then
        return
    end

    local numSquishy
    if totalGroupSize >= 20 then
        numSquishy = 8
    elseif totalGroupSize >= 16 then
        numSquishy = 6
    elseif totalGroupSize >= 10 then
        numSquishy = 4
    else
        numSquishy = 2
    end

    table.sort(healthData, function(a, b) return a.effectiveHealth < b.effectiveHealth end)

    for i = 1, numSquishy do
        local data = healthData[i]
        if data then
            unitHealthStatuses[data.unit] = "Squishy"
        end
    end
end

-- Hook into Blizzard's function to set up frames and enforce sorting
hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
    ProcessUnitFrame(frame)
    UpdateOutOfRangeUnits()  -- Re-apply sorting each time frames are set up
end)

-- Function to process a unit frame
local function ProcessUnitFrame(frame)
    if not frame or frame:IsForbidden() then return end
    SetCustomIconAndOverlay(frame)
    UpdateUnitFrameIconAndOverlay(frame)
end

-- Function to process all unit frames
local function ProcessAllUnitFrames()
    UpdateHealthStatuses()

    -- Process party frames
    local i = 1
    while true do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame then
            ProcessUnitFrame(frame)
            i = i + 1
        else
            break
        end
    end

    -- Process raid frames
    for i = 1, NUM_RAID_GROUPS do
        local group = _G["CompactRaidGroup" .. i]
        if group then
            for j = 1, MEMBERS_PER_RAID_GROUP do
                local frame = group["member" .. j]
                if frame then
                    ProcessUnitFrame(frame)
                end
            end
        end
    end

    -- Process individual raid frames
    local i = 1
    while true do
        local frame = _G["CompactRaidFrame" .. i]
        if frame then
            ProcessUnitFrame(frame)
            i = i + 1
        else
            break
        end
    end
end

-- Hook into Blizzard's function to update unit frames
hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame)
    ProcessUnitFrame(frame)
end)

-- Timer to periodically verify sort order outside of combat
local function StartOutOfCombatSortCheck()
    if not UFLSettings.sortByHealth and not UFLSettings.sortOutOfRange and not UFLSettings.roleSortOrder then return end

    -- Only run this check outside of combat
    C_Timer.NewTicker(3, function()
        if not InCombatLockdown() then
            UpdateOutOfRangeUnits()  -- Reapply sorting to ensure alignment with dropdown selection
        end
    end)
end

-- Event handler for health-related events
local function HandleHealthRelatedEvents(unit)
    if unit and UnitExists(unit) then
        UpdateHealthStatuses()
        ProcessAllUnitFrames()
    end
end

-- Initialize the addon and start sorting check
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SquishyFrames" then
        if not UFLSettings then
            UFLSettings = {
                updateInCombat = true,
                debugMode = false,
                sortOutOfRange = false,
                sortByHealth = true,
                roleSortOrder = "Tank, Healers, DPS",
                ignoreGroups = false,
            }
        end
        StartOutOfCombatSortCheck()  -- Start periodic sorting verification
        return
    end

    local currentTime = GetTime()
    if currentTime - lastUpdate < THROTTLE_TIME then
        return
    end
    lastUpdate = currentTime

    local shouldProcessAll = false

    if event == "PLAYER_REGEN_ENABLED" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        ClearOldPlayerData()
        shouldProcessAll = true
    elseif event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_CONNECTION" or event == "UNIT_HEALTH" or event == "UNIT_DISPLAYPOWER" then
        HandleHealthRelatedEvents(arg1)
        UpdateOutOfRangeUnits()
    end

    if event == "UNIT_AURA" or event == "UNIT_PHASE" then
        UpdateOutOfRangeUnits()
    end

    if shouldProcessAll then
        ProcessAllUnitFrames()
    end
end)

-- Additional events for out-of-range tracking and health updates
-- Delay sorting by 3 seconds when a player joins or leaves the group
local rosterUpdateTimer = nil
EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Cancel any existing timer to reset the delay
        if rosterUpdateTimer then
            rosterUpdateTimer:Cancel()
        end
        -- Create a new timer to trigger sorting after 3 seconds
        rosterUpdateTimer = C_Timer.NewTimer(3, function()
            ClearOldPlayerData()
            UpdateOutOfRangeUnits()
            ProcessAllUnitFrames()
        end)
        return
    end
    -- Original event handling code follows...
    local currentTime = GetTime()
    if currentTime - lastUpdate < THROTTLE_TIME then
        return
    end
    lastUpdate = currentTime
    local shouldProcessAll = false

    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        ClearOldPlayerData()
        shouldProcessAll = true
    elseif event == "UNIT_MAXHEALTH" or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_CONNECTION" or event == "UNIT_HEALTH" or event == "UNIT_DISPLAYPOWER" then
        HandleHealthRelatedEvents(arg1)
        UpdateOutOfRangeUnits()
    end

    if event == "UNIT_AURA" or event == "UNIT_PHASE" then
        UpdateOutOfRangeUnits()
    end

    if shouldProcessAll then
        ProcessAllUnitFrames()
    end
end)

EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("UNIT_MAXHEALTH")
EventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
EventFrame:RegisterEvent("UNIT_CONNECTION")
EventFrame:RegisterEvent("UNIT_HEALTH")
EventFrame:RegisterEvent("UNIT_DISPLAYPOWER") -- For power type changes
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventFrame:RegisterEvent("UNIT_AURA")
EventFrame:RegisterEvent("UNIT_PHASE")


-- Function to toggle combat updates
function UFL_ToggleCombatUpdates(value)
    UFLSettings.updateInCombat = value
end

-- Function to enable or disable Party Sorting
function UFL_ToggleSortOutOfRange(value)
    UFLSettings.sortOutOfRange = value
    UpdateOutOfRangeUnits()
end

-- Function to enable or disable debug mode
function UFL_ToggleDebugMode(value)
    UFLSettings.debugMode = value
end

-- Function to toggle sorting by health
function UFL_ToggleSortByHealth(value)
    UFLSettings.sortByHealth = value
    UpdateOutOfRangeUnits()
end
