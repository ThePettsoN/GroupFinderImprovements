local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WoW API
local CLFGList = C_LFGList
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local GetNumTalentGroups = GetNumTalentGroups
local GetTalentGroupRole = GetTalentGroupRole

-- Lua functions

local ListingHeaderUI = {}
GroupFinderImprovements.Core:RegisterModule("ListingHeaderUI", ListingHeaderUI, "AceEvent-3.0")

function ListingHeaderUI:OnInitialize()
    self:Debug("OnInitialize")
    self._initialUICreated = false
end

function ListingHeaderUI:OnEnable()
    self:Debug("OnEnable")
end

function ListingHeaderUI:Release()
    if not self._container then
        self:Error("Tried to hide UI before created")
        return
    end

    self._container:ReleaseChildren()
end

function ListingHeaderUI:CreateUI(tabFrame)
    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("Flow")
    tabFrame:AddChild(container)
    self._container = container

    local tankButton = AceGUI:Create("RoleButton")
    tankButton:SetRole("TANK")
    tankButton:SetCallback("OnValueChanged", function(_, _, checkbox)
        self:OnRoleButtonCheckboxClick(checkbox)
    end)

    local healerButton = AceGUI:Create("RoleButton")
    healerButton:SetRole("HEALER")
    healerButton:SetCallback("OnValueChanged", function(_, _, checkbox)
        self:OnRoleButtonCheckboxClick(checkbox)
    end)

    local damagerButton = AceGUI:Create("RoleButton")
    damagerButton:SetRole("DAMAGER")
    damagerButton:SetCallback("OnValueChanged", function(_, _, checkbox)
        self:OnRoleButtonCheckboxClick(checkbox)
    end)

    local guideButton = AceGUI:Create("RoleButton")
    guideButton:SetRole("GUIDE")
    guideButton:SetCallback("OnValueChanged", function(_, _, checkbox)
        self:OnRoleButtonCheckboxClick(checkbox)
    end)

    container:AddChild(tankButton)
    container:AddChild(healerButton)
    container:AddChild(damagerButton)
    container:AddChild(guideButton)

    self._roleButtons = {
        TANK = tankButton,
        HEALER = healerButton,
        DAMAGER = damagerButton,
        GUIDE = guideButton
    }

    local divider = AceGUI:Create("Divider")
    divider:SetFullWidth(true)
    divider:SetHeight(8)
    container:AddChild(divider)

    -- local divider = self:CreateRoleHeaderDivider(container)
    -- divider:SetFullWidth(true)
    -- container:AddChild(divider)

    if not self._initialUICreated then
        self:LoadSoloRolesFromTalents()
    end
    self._initialUICreated = true
end

function ListingHeaderUI:OnRoleButtonCheckboxClick(checkBox)
    if checkBox:GetChecked() then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end

    if not self:SaveSoloRoles() then
        checkBox:SetChecked(not checkBox:SetChecked())
    end
end

function ListingHeaderUI:SetSoloRoles(roles)
    self._roleButtons.TANK.checkButton:SetChecked(roles.tank)
    self._roleButtons.HEALER.checkButton:SetChecked(roles.healer)
    self._roleButtons.DAMAGER.checkButton:SetChecked(roles.dps)
end

function ListingHeaderUI:SaveSoloRoles()
	return CLFGList.SetRoles({
		tank   = self._roleButtons.TANK.checkButton:GetChecked(),
		healer = self._roleButtons.HEALER.checkButton:GetChecked(),
		dps    = self._roleButtons.DAMAGER.checkButton:GetChecked(),
	})
end

function ListingHeaderUI:LoadSoloRolesFromTalents()
    self:Debug("LoadSoloRolesFromTalents")
    local roleButtons = self._roleButtons

    for i = 1, GetNumTalentGroups() do
        for k, v in pairs(roleButtons) do
            if GetTalentGroupRole(i) == k then
                v.checkButton:SetChecked(true)
            end
        end
    end

    self:SaveSoloRoles()
end

function ListingHeaderUI:NewPlayerFriendlyEnabled()
    return self._roleButtons.GUIDE:GetValue()
end

function ListingHeaderUI:SetNewPlayerFriendlyEnabled(value)
    self._roleButtons.GUIDE:SetValue(value)
end