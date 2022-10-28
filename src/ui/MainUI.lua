local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- Wow API
local CLFGList = C_LFGList
local CreateFrame = CreateFrame
local CLOSE = CLOSE

-- Lua functions


local MainUI = {}
GroupFinderImprovements.Core:RegisterModule("MainUI", MainUI, "AceHook-3.0", "AceEvent-3.0")

function MainUI:OnInitialize()
    self:Debug("OnInitialize")
    self:Reset()
end

function MainUI:OnEnable()
    self:Debug("OnEnable")

    self._listingUI = GroupFinderImprovements.Core:GetModule("ListingUI")
    self._browseUI = GroupFinderImprovements.Core:GetModule("BrowseUI")

    self:RegisterEvent("GROUP_LEFT", "OnGroupLeft")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE", "OnLFGListActiveEntryUpdate")
    self:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE", "OnLFGListAvailabilityUpdate") -- Called when available activites changes
    self:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TIMEOUT", "OnLFGListEntryExpiredTimeout")
    self:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS", "OnLFGListEntryExpiredTooManyPlayers")
    self:RegisterEvent("LFG_LIST_ROLE_UPDATE", "OnLFGListRoleUpdate")
    self:RegisterEvent("LFG_LIST_SEARCH_FAILED", "OnLFGListSearchFailed")
    self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", "OnLFGListSearchResultsReceived")
    self:RegisterEvent("PARTY_LEADER_CHANGED", "OnPartyLeaderChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", "OnPlayerRolesAssigned")
    self:RegisterEvent("REPORT_PLAYER_RESULT", "OnReportPlayerResult")

    self:RegisterMessage("SetLeftButtonText", "OnSetLeftButtonText")
    self:RegisterMessage("SetRightButtonText", "OnSetRightButtonText")
end

function MainUI:Reset()
    self._activeFrame = nil
    self._currentViewName = nil

    if self._frame then
        self._frame:ReleaseChildren()
        self._frame = nil
    end
end

function MainUI:CreateUI()
    if self._frame then
        self:Warning("Tried to create already existing UI")
        return
    end

    self:Debug("CreateUI")

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Group Finder")
    frame:EnableResize(true)
    frame:SetLayout("Fill")
    frame:SetWidth(420)
    frame.frame:SetMinResize(420, 200)

    frame.statustext:GetParent():Hide()

    local tab = AceGUI:Create("TabGroup")
    tab:SetLayout("Fill")
    tab:SetFullHeight(true)
    tab:SetFullWidth(true)

    tab:SetTabs({
        { text = "Create Listing", value = "listing" },
        { text="Group Browser", value="browser" }
    })
    tab:SetCallback("OnGroupSelected", function(tabGroup, event, newTab)
        self:ActivateView(newTab)
    end)
    frame:AddChild(tab)

    local leftButton = CreateFrame("Button", TOC .. "LeftButton", frame.frame, "UIPanelButtonTemplate")
    leftButton:SetText("Back")
    leftButton:SetHeight(20)
	leftButton:SetWidth(100)
    leftButton:SetPoint("BOTTOMLEFT", frame.frame, "BOTTOMLEFT", 27, 17)
    leftButton:Show()
    -- leftButton:Disable()
    leftButton:SetScript("OnClick", function(...)
        if self._currentViewName == "listing" then
            self._listingUI:OnLeftButtonClick(...)
        else
            self._browseUI:OnLeftButtonClick(...)
        end
    end)

    local rightButton = CreateFrame("Button", TOC .. "RightButton", frame.frame, "UIPanelButtonTemplate")
    rightButton:SetText("List Self")
    rightButton:SetHeight(20)
	rightButton:SetWidth(100)
    rightButton:SetPoint("BOTTOMRIGHT", frame.frame, "BOTTOMRIGHT", -27, 17)
    rightButton:Show()
    -- rightButton:Disable()
    rightButton:SetScript("OnClick", function(...)
        if self._currentViewName == "listing" then
            self._listingUI:OnRightButtonClick(...)
        else
            self._browseUI:OnRightButtonClick(...)
        end
    end)

    -- Hide Close button
    local children = { frame.frame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child:IsObjectType("Button") and child:GetText() == CLOSE then
            child:Hide()
            break
        end
    end

    self._frame = frame
    self._frame:Hide()
    self._leftButton = leftButton
    self._rightButton = rightButton
    self._tabView = tab
end

function MainUI:ActivateView(view)
    self:Debug("ActivateView: Current View: %s | New View: %s", tostring(self._currentViewName), view)
    if self._currentViewName == view then
        self:Warning("New view is same as old. Ignoring")
        return
    end

    self:Debug("HEJ")

    if view == "listing" then
        self._browseUI:Deactivate()
    else
        self._listingUI:Deactivate()
    end

    self._tabView:ReleaseChildren()
    if view == "listing" then
        self._listingUI:CreateUI(self._tabView)
        self._leftButton:SetText("Back")
        self._rightButton:SetText("List Self")
    else
        self._browseUI:CreateUI(self._tabView)
        self._leftButton:SetText("Send Message")
        self._rightButton:SetText("Group Invite")
    end

    if view == "listing" then
        self._listingUI:Activate()
        self._activeFrame = self._listingUI
    else
        self._browseUI:Activate()
        self._activeFrame = self._browseUI
    end

    self._currentViewName = view
end

function MainUI:Show()
    self._frame:Show()
end

function MainUI:Hide()
    self._frame:Hide()
end

function MainUI:Toggle()
    if self._frame:IsShown() then
        self._frame:Hide()
    else
        self._frame:Show()
    end
end

function MainUI:ToggleLFGParentFrame()
    self:Debug("OnToggleLFGParentFrame")
    self:Toggle()
end

-- EVENTS
function MainUI:OnGroupLeft(event, partyCategory)
    self:Debug("OnGroupLeft")

    if self._activeFrame.OnGroupLeft then
        self._activeFrame:OnGroupLeft(partyCategory)
    end
end

function MainUI:OnGroupRosterUpdate(event, ...)
    self:Debug("OnGroupRosterUpdate")

    if self._activeFrame.OnGroupRosterUpdate then
        self._activeFrame:OnGroupRosterUpdate(...)
    end
end

function MainUI:OnLFGListActiveEntryUpdate(event, created)
    local hasActiveEntryInfo = created or CLFGList.HasActiveEntryInfo()

    local activeEntryInfo = hasActiveEntryInfo and CLFGList.GetActiveEntryInfo() or nil
    self:Debug("OnLFGListActiveEntryUpdate | Created: %q | hasActiveEntryInfo %q | have activeEntryInfo %q", tostring(created), tostring(hasActiveEntryInfo), tostring(activeEntryInfo ~= nil))

    self._listingUI:SetActiveEntry(created, activeEntryInfo)
    self._browseUI:SetActiveEntry(created, activeEntryInfo)

    if hasActiveEntryInfo then
        self._tabView:SelectTab("browser")
    else
        self._tabView:SelectTab("listing")
    end
end

function MainUI:OnLFGListAvailabilityUpdate(event, ...)
    self:Debug("OnLFGListEntryExpiredTimeout")
end

function MainUI:OnLFGListEntryExpiredTimeout(event)
    self:Debug("OnLFGListEntryExpiredTimeout")

    if self._activeFrame.OnLFGListEntryExpiredTimeout then
        self._activeFrame:OnLFGListEntryExpiredTimeout()
    end
end

function MainUI:OnLFGListEntryExpiredTooManyPlayers(event, ...)
    self:Debug("OnLFGListEntryExpiredTooManyPlayers")

    if self._activeFrame.OnLFGListEntryExpiredTooManyPlayers then
        self._activeFrame:OnLFGListEntryExpiredTooManyPlayers()
    end
end

function MainUI:OnLFGListRoleUpdate(event)
    self:Debug("OnLFGListRoleUpdate")

    local roles = CLFGList.GetRoles()
    self._listingUI:SetSoloRoles(roles)
end

function MainUI:OnLFGListSearchFailed(event)
    self:Debug("OnLFGListSearchFailed")

    self._browseUI:SetSearching(false)
end

function MainUI:OnLFGListSearchResultsReceived(event)
    self:Debug("OnLFGListSearchResultsReceived")

    self._browseUI:SetSearching(false)

    if self._activeFrame.OnLFGListSearchResultsReceived then
        self._activeFrame:OnLFGListSearchResultsReceived()
    end
end

function MainUI:OnPartyLeaderChanged(event, ...)
    self:Debug("OnPartyLeaderChanged")

    if self._activeFrame.OnPartyLeaderChanged then
        self._activeFrame:OnPartyLeaderChanged()
    end
end

function MainUI:OnPlayerEnteringWorld(event, initial)
    self:Debug("OnPlayerEnteringWorld | initial: %q", tostring(initial))

    if not initial then
        self:Reset()
    end

    self:CreateUI()
    self:Show()

    self._tabView:SelectTab("listing")

    if self._activeFrame.OnPlayerEnteringWorld then
        self._activeFrame:OnPlayerEnteringWorld(initial)
    end

    -- self:RawHook("ToggleLFGParentFrame", true)
end

function MainUI:OnPlayerRolesAssigned(event, ...)
    self:Debug("OnPlayerRolesAssigned")

    if self._activeFrame.OnPlayerRolesAssigned then
        self._activeFrame:OnPlayerRolesAssigned()
    end
end

function MainUI:OnReportPlayerResult(event, ...)
    self:Debug("OnReportPlayerResult")

    if self._activeFrame.OnReportPlayerResult then
        self._activeFrame:OnReportPlayerResult()
    end
end

function MainUI:OnSetLeftButtonText(event, text, enabled)
    self._leftButton:SetText(text)
    self._leftButton:SetEnabled(enabled)
end

function MainUI:OnSetRightButtonText(event, text, enabled)
    self._rightButton:SetText(text)
    self._rightButton:SetEnabled(enabled)
end