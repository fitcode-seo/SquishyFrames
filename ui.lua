-- Assuming ui.lua handles the /ufl popup and its checkboxes

-- Function to create the /ufl popup if it doesn't exist
local function CreateUflPopup()
    if UFL_Popup then return end

    UFL_Popup = CreateFrame("Frame", "UFL_Popup", UIParent, "UIPanelDialogTemplate")
    UFL_Popup:SetSize(300, 270)
    UFL_Popup:SetPoint("CENTER")
    UFL_Popup:Hide()

    UFL_Popup.title = UFL_Popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    UFL_Popup.title:SetPoint("TOP", 0, -10)
    UFL_Popup.title:SetText("SquishyFrames Settings")

    local function CreateCheckbox(parent, name, text, onClick, yOffset)
        local checkbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        checkbox.Text:SetText(text)
        checkbox:SetScript("OnClick", onClick)
        return checkbox
    end

    local function CreateDropdown(parent, name, items, onClick, yOffset)
        local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
        
        UIDropDownMenu_SetWidth(dropdown, 180)
        UIDropDownMenu_SetText(dropdown, items[1].text)
        
        UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
            for _, item in ipairs(items) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = item.text
                info.func = function()
                    UIDropDownMenu_SetText(dropdown, item.text)
                    UIDropDownMenu_JustifyText(dropdown, "LEFT")
                    onClick(item.value)
                    UpdateOutOfRangeUnits()  -- Trigger a resort when dropdown selection changes
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        return dropdown
    end

    local roleSortOptions = {
        { text = "Tank, Healers, DPS", value = "Tank, Healers, DPS" },
        { text = "Tank, DPS, Healers", value = "Tank, DPS, Healers" },
    }

    UFL_Popup.updateInCombatCheckbox = CreateCheckbox(UFL_Popup, "UpdateInCombat", "Update in Combat", function(self)
        UFL_ToggleCombatUpdates(self:GetChecked())
    end, -30)

    UFL_Popup.sortOutOfRangeCheckbox = CreateCheckbox(UFL_Popup, "SortOutOfRange", "Sort Out-of-Range Players to End", function(self)
        UFL_ToggleSortOutOfRange(self:GetChecked())
        UpdateOutOfRangeUnits()  -- Ensure sorting is refreshed immediately when toggled
    end, -60)

    UFL_Popup.sortByHealthCheckbox = CreateCheckbox(UFL_Popup, "SortByHealth", "Sort Unit Frames By Health", function(self)
        UFL_ToggleSortByHealth(self:GetChecked())
        UpdateOutOfRangeUnits()  -- Ensure sorting is refreshed immediately when toggled
    end, -90)

    UFL_Popup.roleSortDropdown = CreateDropdown(UFL_Popup, "RoleSortOrder", roleSortOptions, function(value)
        UFLSettings.roleSortOrder = value
        UpdateOutOfRangeUnits()  -- Ensure sorting is refreshed based on new dropdown selection
    end, -120)

    UFL_Popup.ignoreGroupsCheckbox = CreateCheckbox(UFL_Popup, "IgnoreGroups", "Ignore Groups for Sorting", function(self)
        UFLSettings.ignoreGroups = self:GetChecked()
        UpdateOutOfRangeUnits()  -- Ensure sorting is refreshed immediately when toggled
    end, -150)

    UFL_Popup.closeButton = CreateFrame("Button", nil, UFL_Popup, "UIPanelButtonTemplate")
    UFL_Popup.closeButton:SetSize(80, 22)
    UFL_Popup.closeButton:SetPoint("BOTTOMRIGHT", -20, 20)
    UFL_Popup.closeButton:SetText("Close")
    UFL_Popup.closeButton:SetScript("OnClick", function()
        UFL_Popup:Hide()
    end)
end

local function ShowUflPopup()
    CreateUflPopup()

    if UFLSettings then
        UFL_Popup.updateInCombatCheckbox:SetChecked(UFLSettings.updateInCombat)
        UFL_Popup.sortOutOfRangeCheckbox:SetChecked(UFLSettings.sortOutOfRange)
        UFL_Popup.sortByHealthCheckbox:SetChecked(UFLSettings.sortByHealth)
        UFL_Popup.ignoreGroupsCheckbox:SetChecked(UFLSettings.ignoreGroups)
        UIDropDownMenu_SetText(UFL_Popup.roleSortDropdown, UFLSettings.roleSortOrder or "Tank, Healers, DPS")
    end

    UFL_Popup:Show()
end

SLASH_UFL1 = "/ufl"
SlashCmdList["UFL"] = function(msg)
    ShowUflPopup()
end
