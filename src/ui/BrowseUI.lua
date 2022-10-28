local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WoW API
local CLFGList = C_LFGList

local BrowseUI = {}
GroupFinderImprovements.Core:RegisterModule("BrowseUI", BrowseUI, "AceHook-3.0", "AceEvent-3.0")

function BrowseUI:OnInitialize()
    self:Debug("OnInitialize")
    self._searching = false
    self._activeEntryInfo = nil
    self._hasActiveEntryInfo = false
    self._active = false
end

function BrowseUI:OnEnable()
    self:Debug("OnEnable")
    self._header = GroupFinderImprovements.Core:GetModule("BrowseHeaderUI")
    self._body = GroupFinderImprovements.Core:GetModule("BrowseBodyUI")

    self:RegisterMessage("Search", "OnSearch")
end

function BrowseUI:Activate()
    self:Debug("Activate")
    self._active = true
    self:UpdateFrameView()
end

function BrowseUI:Deactivate()
    self:Debug("Deactivate")
    self._active = false
end

function BrowseUI:CreateUI(tabFrame)
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
    self._tabFrame = tabFrame
end

function BrowseUI:UpdateFrameView()
    if not self._active then
        return
    end

    self._header:UpdateFrameView(self._activeEntryInfo)
end

function BrowseUI:UpdateButtons()
    if not self._active then
        return
    end
end

function BrowseUI:SetSearching(isSearching)
    self._searching = isSearching
end

function BrowseUI:OnSearch(event)
    if self._searching then
        self:Debug("Already searching")
        return
    end

    local categoryId = self._header:GetSelectedCategory() or 0
    if categoryId then
        self:Debug("categoryId: %d", categoryId)
        local numActivites, activites = self._header:GetSelectedActivities()
        if numActivites == 0 then
            self:Debug("No activites!")
            activites = CLFGList.GetAvailableActivities(categoryId)
        end

        self:SetSearching(true)
        CLFGList.Search(categoryId, activites)
        self:Debug("Searching!")
    end
end

function BrowseUI:OnLFGListAvailabilityUpdate()
    if self._tabFrame then
        self._header:RefreshDropdowns(self._tabFrame)
    end
end

function BrowseUI:OnLFGListSearchResultsReceived()
    local totalResults, results = CLFGList.GetFilteredSearchResults()
end

function BrowseUI:OnReportPlayerResult()
    if not self._active then
        return
    end
end

function BrowseUI:SetActiveEntry(created, activeEntryInfo)
    self._activeEntryInfo = activeEntryInfo
    self._hasActiveEntryInfo = activeEntryInfo ~= nil


    self._header:SetActiveEntry(created, activeEntryInfo)

    -- self:UpdateFrameView()
    -- self:UpdateButtons()
end