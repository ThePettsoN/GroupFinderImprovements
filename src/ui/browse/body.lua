local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

local BrowseBodyUI = {}
GroupFinderImprovements.Core:RegisterModule("BrowseBodyUI", BrowseBodyUI, "AceEvent-3.0")

function BrowseBodyUI:OnInitialize()
    self:Debug("OnInitialize")
end

function BrowseBodyUI:OnEnable()
    self:Debug("OnEnable")
end

function BrowseBodyUI:Release()
    if not self._container then
        self:Error("Tried to hide UI before created")
        return
    end

    self._container:ReleaseChildren()
end

function BrowseBodyUI:CreateUI(tabFrame)
end

function BrowseBodyUI:Populate()
end
