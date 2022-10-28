local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WoW API
local CLFGList = C_LFGList

-- Lua functions

local ListingOverviewUI = {}
GroupFinderImprovements.Core:RegisterModule("ListingOverviewUI", ListingOverviewUI, "AceEvent-3.0")

function ListingOverviewUI:OnInitialize()
    self:Debug("OnInitialize")
end

function ListingOverviewUI:OnEnable()
    self:Debug("OnEnable")
end

function ListingOverviewUI:Release()
    if not self._container then
        self:Error("Tried to hide UI before created")
        return
    end

    self._container:ReleaseChildren()
end

function ListingOverviewUI:CreateUI(tabFrame)
    self:Debug("CreateUI")

    self._container = tabFrame

    local categories = CLFGList.GetAvailableCategories()
    for i = 1, #categories do
        self:CreateCategoryButton(tabFrame, categories[i])
    end
end

function ListingOverviewUI:CreateCategoryButton(container, categoryId)
    local categoryInfo = CLFGList.GetCategoryInfo(categoryId)

    local button = AceGUI:Create("Button")
    button:SetText(categoryInfo)
    button:SetRelativeWidth(1)
    button:SetCallback("OnClick", function() self:OnCategoryButtonClick(categoryId) end)

    container:AddChild(button)

    return button
end

function ListingOverviewUI:OnCategoryButtonClick(id)
    self:Debug("OnCategoryButtonClick %d", id)
    self:SendMessage("CategoryButtonClick", id)
end