local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WoW API
local CLFGList = C_LFGList
local IsInGroup = IsInGroup
local UnitIsGroupLeader = UnitIsGroupLeader
local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME
local StaticPopup_Show = StaticPopup_Show

-- Lua functions
local wipe = wipe


local ListingUI = {}
GroupFinderImprovements.Core:RegisterModule("ListingUI", ListingUI, "AceHook-3.0", "AceEvent-3.0")

function ListingUI:OnInitialize()
    self:Debug("OnInitialize")
    self._activities = {}
    self._activeEntryInfo = nil
    self._hasActiveEntryInfo = false
    self._initialUICreated = false
end

function ListingUI:OnEnable()
    self:Debug("OnEnable")
    self._header = GroupFinderImprovements.Core:GetModule("ListingHeaderUI")
    self._overview = GroupFinderImprovements.Core:GetModule("ListingOverviewUI")
    self._activity = GroupFinderImprovements.Core:GetModule("ListingActivityUI")

    self:RegisterMessage("CategoryButtonClick", "OnCategoryButtonClick")
    self:RegisterMessage("ActivityValueChanged", "OnActivityValueChanged")
end

function ListingUI:Activate()
    self:Debug("Activate")
    self._active = true

    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:Deactivate()
    self:Debug("Deactivate")
    self._active = false
end

function ListingUI:CreateUI(tabFrame)
    self:Debug("CreateUI")
    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetFullHeight(true)
    container:SetLayout("Flow")
    tabFrame:AddChild(container)

    self._header:CreateUI(container)

    local body = AceGUI:Create("ScrollFrame")
    body:SetFullWidth(true)
    body:SetLayout("List")
    body:SetFullHeight(true)
    container:AddChild(body)

    self._containerFrame = container
    self._bodyFrame = body
    self._initialUICreated = true
end

function ListingUI:Release()
    self:Debug("Release")
    AceGUI:Release(self._containerFrame)
end

function ListingUI:IsVisible()
    if not self._containerFrame then
        self:Error("Tried to check if UI is visible before created")
        return
    end

    return self._containerFrame.frame:IsVisible()
end

function ListingUI:OnCategoryButtonClick(event, id)
    self:Debug("OnCategoryButtonClick - %d", id)
    self:SetCategorySelection(id)

    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:OnActivityValueChanged(event, id, value)
    self:Debug("OnCategoryButtonClick - id: %d | value: %s", id, tostring(value))
    self._activities[id] = value
end

function ListingUI:OnLeftButtonClick()
    self:Debug("OnLeftButtonClick")
    if self._selectedCategory then
        self:ResetCategorySelection()
        self:CreateOrUpdateListing()
    end

    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:OnRightButtonClick()
    self:Debug("OnRightButtonClick")

    self:CreateOrUpdateListing()
end

local activites = {}
function ListingUI:CreateOrUpdateListing()
    self:Debug("CreateOrUpdateListing")
    wipe(activites)

    local haveActivites = false
    for k, v in pairs(self._activities) do
        if v then
            haveActivites = true
            activites[#activites+1] = k
        end
    end

    local newPlayerFriendlyEnabled = self._header:NewPlayerFriendlyEnabled()

    if self._hasActiveEntryInfo then
        if haveActivites then
            self:Debug("CreateOrUpdateListing - Update existing listing")
            CLFGList.UpdateListing(activites, newPlayerFriendlyEnabled)
        else
            self:Debug("CreateOrUpdateListing - Delete existing listing")
            CLFGList.RemoveListing()
        end
    elseif haveActivites then
        self:Debug("CreateOrUpdateListing - Create new listing")
        CLFGList.CreateListing(activites, newPlayerFriendlyEnabled)
    else
        self:Debug("CreateOrUpdateListing - No entries selected")
    end
end

function ListingUI:SetActiveEntry(created, activeEntryInfo)
    self._activeEntryInfo = activeEntryInfo
    self._hasActiveEntryInfo = activeEntryInfo ~= nil

    if self._hasActiveEntryInfo then
        local activityInfo = CLFGList.GetActivityInfoTable(activeEntryInfo.activityIDs[1])
        self:SetCategorySelection(activityInfo.categoryID)
    else
        self:ResetCategorySelection()
    end

    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:SetSoloRoles(roles)
    self._header:SetSoloRoles(roles)
end

function ListingUI:UpdateFrameView()
    self:Debug("UpdateFrameView")
    self._bodyFrame:ReleaseChildren()

    if not LFGListingUtil_CanEditListing() then
        self:Debug("Lock Body")
        -- TODO: Lock body
    elseif not self._selectedCategory then
        -- TODO: Show overview
        self._overview:CreateUI(self._bodyFrame)
    else
        -- TODO: Show activities
        self._activity:CreateUI(self._bodyFrame)
        self._activity:Populate(self._selectedCategory)
    end

    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        -- TODO: Hide Solo Role Buttons
        -- TODO: Show Group Role Buttons
    else
        -- TODO: Show Solo Role Buttons
        -- TODO: Hide Group Role Buttons
    end
end

function ListingUI:UpdateButtons()
    self:Debug("UpdateButtons")

    if self._hasActiveEntryInfo then
        self:SendMessage("SetLeftButtonText", "Delist", true)
    else
        local active = self._selectedCategory ~= nil
        self:SendMessage("SetLeftButtonText", "Back", active)
    end
end

function ListingUI:SetCategorySelection(categoryId)
    wipe(self._activities)
    self._selectedCategory = categoryId

    -- self:UpdateFrameView()
end

function ListingUI:ResetCategorySelection()
    self._selectedCategory = nil
    wipe(self._activities)

    -- self:UpdateFrameView()
end

function ListingUI:LoadActiveEntry()
    self:Debug("LoadActiveEntry")

    if self._hasActiveEntryInfo then
        local activityInfo = CLFGList.GetActivityInfoTable(self._activeEntryInfo.activityIDs[1])
        self:SetCategorySelection(activityInfo.categoryID)
        CLFGList.CopyActiveEntryInfoToCreationFields()
        self._header:SetNewPlayerFriendlyEnabled(self._activeEntryInfo.newPlayerFriendly)
    end
end

-- EVENTS
function ListingUI:OnGroupLeft(partyCategory)
    if partyCategory == LE_PARTY_CATEGORY_HOME and not self._hasActiveEntryInfo then
        self:ResetCategorySelection()
    end
end

function ListingUI:OnGroupRosterUpdate(...)
    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:OnLFGListEntryExpiredTimeout()
    if UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
        StaticPopup_Show("LFG_LIST_ENTRY_EXPIRED_TIMEOUT")
    end
end

function ListingUI:OnLFGListEntryExpiredTooManyPlayers()
    if UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME) then
        StaticPopup_Show("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")
    end
end

function ListingUI:OnPartyLeaderChanged(event)
    self:UpdateFrameView()
    self:UpdateButtons()
end

function ListingUI:OnLFGListAvailabilityUpdate(event, ...)
    if self._hasActiveEntryInfo then
        local activityInfo = CLFGList.GetActivityInfoTable(self._activeEntryInfo.activityIDs[1])
        self:SetCategorySelection(activityInfo.categoryID)
        self:LoadActiveEntry()
    end
end

function ListingUI:OnPlayerRolesAssigned(event)
    -- TODO: Populate Group Role button
end
