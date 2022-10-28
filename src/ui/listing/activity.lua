local TOC, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- Global WoW API
local CLFGList = C_LFGList

-- Lua functions
local wipe = wipe
local tContains = tContains

local ListingActivityUI = {}
GroupFinderImprovements.Core:RegisterModule("ListingActivityUI", ListingActivityUI, "AceEvent-3.0")

function ListingActivityUI:OnInitialize()
    self:Debug("OnInitialize")
    self._entires = {}
end

function ListingActivityUI:OnEnable()
    self:Debug("OnEnable")
end

function ListingActivityUI:Release()
    if not self._container then
        self:Error("Tried to hide UI before created")
        return
    end

    self._container:ReleaseChildren()
end

function ListingActivityUI:CreateUI(tabFrame)
    self:Debug("CreateUI")

    self._container = tabFrame
end


local function sortEntries(lEntry, rEntry)
    if lEntry.orderIndex ~= rEntry.orderIndex then
        return lEntry.orderIndex > rEntry.orderIndex
    elseif lEntry.maxLevel ~= rEntry.maxLevel then
        return lEntry.maxLevel > rEntry.maxLevel
    elseif lEntry.minLevel ~= rEntry.minLevel then
        return lEntry.minLevel > rEntry.minLevel
    else
        return strcmputf8i(lEntry.name, rEntry.name) < 0
    end
end

function ListingActivityUI:Populate(categoryId, activeEntryInfo)
    wipe(self._entires)

    local activities = CLFGList.GetAvailableActivities(categoryId, 0)
    for i = 1, #activities do
        local activityId = activities[i]
        local activityInfo = CLFGList.GetActivityInfoTable(activityId)
        local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
        self:Debug(name)
    end

    local activeActivities = activeEntryInfo and activeEntryInfo.activityIDs

    local activityGroups = CLFGList.GetAvailableActivityGroups(categoryId)
    local temp = {}
    for i = 1, #activityGroups do
        local activityGroupId = activityGroups[i]
        activities = CLFGList.GetAvailableActivities(categoryId, activityGroupId)
        if #activities > 0 then
            local name, orderIndex = CLFGList.GetActivityGroupInfo(activityGroupId)
            -- TODO: Sort
            local test = AceGUI:Create("Heading")
            test:SetText(name)
            test:SetFullWidth(true)
            self._container:AddChild(test)

            wipe(temp)
            for i = 1, #activities do
                local activityId = activities[i]
                local activityInfo = CLFGList.GetActivityInfoTable(activityId)
                local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
                activityInfo.id = activityId
                activityInfo.name = name
                activityInfo.maxLevel = activityInfo.maxLevel ~= 0 and activityInfo.maxLevel or activityInfo.maxLevelSuggestion
                temp[#temp + 1] = activityInfo
            end

            table.sort(temp, sortEntries)

            for i = 1, #temp do
                local activityInfo = temp[i]
                local name = activityInfo.name

                local entry = AceGUI:Create("CheckBox")
                entry:SetLabel(string.format("%s (%d - %d)", name, activityInfo.minLevel, activityInfo.maxLevel))
                entry:SetFullWidth(true)
                entry.activityId = activityInfo.id
                entry:SetCallback("OnValueChanged", function(frame, event, value)
                    self:SendMessage("ActivityValueChanged", activityInfo.id, value)
                end)

                if activeActivities and tContains(activeActivities, activityInfo.id) then
                    entry:SetValue(true)
                    self:SendMessage("ActivityValueChanged", activityInfo.id, true)
                end

                self._entires[#self._entires+1] = entry
                self._container:AddChild(entry)
            end
        end
    end
end
