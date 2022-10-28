local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- WoW API
local CLFGList = C_LFGList

-- Lua functions
local wipe = wipe
local tContains = tContains

local BrowseHeaderUI = {}
GroupFinderImprovements.Core:RegisterModule("BrowseHeaderUI", BrowseHeaderUI, "AceEvent-3.0")

function BrowseHeaderUI:OnInitialize()
    self:Debug("OnInitialize")
end

function BrowseHeaderUI:OnEnable()
    self:Debug("OnEnable")

end

function BrowseHeaderUI:Release()
    if not self._container then
        self:Error("Tried to hide UI before created")
        return
    end

    self._container:ReleaseChildren()
end

function BrowseHeaderUI:CreateUI(tabFrame)
    self:Debug("CreateUI")

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("Flow")
    tabFrame:AddChild(container)
    self._container = container

    local categoryDropdown = AceGUI:Create("Dropdown")
    -- categoryDropdown:SetLabel("Categories")

    local categories = CLFGList.GetAvailableCategories()
    for i = 1, #categories do
        local categoryId = categories[i]
        local categoryInfo = CLFGList.GetCategoryInfo(categoryId)
        categoryDropdown:AddItem(categoryId, categoryInfo, "Dropdown-Item-Toggle")
    end
    categoryDropdown:SetRelativeWidth(0.5)
    categoryDropdown:SetCallback("OnValueChanged", function(frame, event, value)
        self:OnCategoryDropdownChanged(value)
    end)

    container:AddChild(categoryDropdown)

    local filterDropdown = AceGUI:Create("Dropdown")
    -- filterDropdown:SetLabel("Filter by activity")
    filterDropdown:SetRelativeWidth(0.5)
    filterDropdown:SetMultiselect(true)
    filterDropdown.RemoveItem = function(self, value)
        self.list[value] = nil
        self.pullout:RemoveItem(value)
    end
    filterDropdown.Clear = function(self)
        wipe(self.list)
        self.pullout:Clear()
    end
    filterDropdown.pullout.RemoveItem = function(self, value)
        for i = 1, #self.items do
            if self.items[i].value == value then
                table.remove(self.items, i)
                break
            end
        end
    end

    container:AddChild(filterDropdown)

    self._categoryDropdown = categoryDropdown
    self._filterDropdown = filterDropdown
    self._tabFrame = tabFrame
end

function BrowseHeaderUI:OnCategoryDropdownChanged(categoryId)
    self:Debug("OnCategoryDropdownChanged. CategoryId: %d", categoryId)
    self._filterDropdown:Clear()
    self._selectedCategory = categoryId

    self._filterDropdown:SetText("Filter by activity")
    if categoryId then
        local activityGroups = CLFGList.GetAvailableActivityGroups(categoryId)
        local disable = true
        for i = 1, #activityGroups do
            local activityGroupId = activityGroups[i]

            local activities = CLFGList.GetAvailableActivities(categoryId, activityGroupId)
            if #activities > 0 then
                disable = false
                local groupName, orderIndex = CLFGList.GetActivityGroupInfo(activityGroupId)
                local pullout = self:CreateSubMenu(groupName)
                pullout.itemValues = {}

                for i = 1, #activities do
                    local activityId = activities[i]
                    local activityInfo = CLFGList.GetActivityInfoTable(activityId)
                    local activityName = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName

                    local toggle = AceGUI:Create("Dropdown-Item-Toggle")

                    if self._hasActiveEntryInfo and tContains(self._activeEntryInfo.activityIDs, activityId) then
                        toggle:SetValue(true)
                    end

                    toggle:SetText(activityName)
                    toggle:SetCallback("OnValueChanged", function(frame, event, value)
                        self:SendMessage("Search")
                        print(self:GetNumSelectedActivites())
                        if self:GetNumSelectedActivites() == 1 then
                            self._filterDropdown:SetText("OnEnable")
                        else
                            self._filterDropdown:SetText("OnEnable2")
                        end
                    end)
                    pullout:AddItem(toggle)
                    pullout.itemValues[#pullout.itemValues+1] = activityId
                end
            end
        end

        self._filterDropdown:SetDisabled(disable)
    else
        self._filterDropdown:SetDisabled(true)
        self._categoryDropdown:SetText("Category")
    end
end

function BrowseHeaderUI:CreateSubMenu(groupName)
    local subMenu = AceGUI:Create("Dropdown-Item-Menu")
    subMenu:SetText(groupName)

    local origClear = subMenu.Clear
    subMenu.Clear = function(self)
        origClear(self)
        if self.submenu then
            self.submenu:Clear()
            self.submenu = nil
        end
    end

    local pullout = AceGUI:Create("Dropdown-Pullout")
    subMenu:SetMenu(pullout)
    self._filterDropdown.pullout:AddItem(subMenu)

    return pullout
end

function BrowseHeaderUI:RefreshDropdowns()
    self._container:ReleaseChildren()
    self:CreateUI(self._tabFrame)
end

function BrowseHeaderUI:GetSelectedCategory()
    self:Debug("GetSelectedCategory | Category: %d", self._selectedCategory)
    return self._selectedCategory
end

function BrowseHeaderUI:GetSelectedActivities()
    local selectedActivites = {}
    local categories = self._filterDropdown.pullout.items
    for i = 1, #categories do
        local subMenu = categories[i].submenu
        local activityItems = subMenu.items
        local activityValues = subMenu.itemValues
        for j = 1, #activityItems do
            self:Debug("Checking %s", activityItems[j]:GetText())
            if activityItems[j]:GetValue() then
                self:Debug("%s is checked! Adding value %d", activityItems[j]:GetText(), activityValues[j])
                selectedActivites[#selectedActivites + 1] = activityValues[j]
            end
        end
    end

    return #selectedActivites, selectedActivites
end

function BrowseHeaderUI:GetNumSelectedActivites()
    local counter = 0
    local categories = self._filterDropdown.pullout.items
    for i = 1, #categories do
        local subMenu = categories[i].submenu
        local activityItems = subMenu.items
        for j = 1, #activityItems do
            if activityItems[j]:GetValue() then
                counter = counter + 1
            end
        end
    end

    return counter
end

function BrowseHeaderUI:UpdateFrameView(activityInfo)
    if not self._categoryDropdown then
        return
    end

    if not activityInfo then
        self._categoryDropdown:SetValue(nil)
        self:OnCategoryDropdownChanged(nil)
    else
        local activityInfo = CLFGList.GetActivityInfoTable(activityInfo.activityIDs[1])
        self._categoryDropdown:SetValue(activityInfo.categoryID)
        self:OnCategoryDropdownChanged(activityInfo.categoryID)
    end
end

function BrowseHeaderUI:SetActiveEntry(created, activeEntryInfo)
    self._activeEntryInfo = activeEntryInfo
    self._hasActiveEntryInfo = activeEntryInfo ~= nil
end