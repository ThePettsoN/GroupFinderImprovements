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

            for i = 1, #activities do
                local activityId = activities[i]
                local activityInfo = CLFGList.GetActivityInfoTable(activityId)
                local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName

                local entry = AceGUI:Create("CheckBox")
                entry:SetLabel(name)
                entry:SetFullWidth(true)
                entry.activityId = activityId
                entry:SetCallback("OnValueChanged", function(frame, event, value)
                    self:SendMessage("ActivityValueChanged", activityId, value)
                end)

                if activeActivities and tContains(activeActivities, activityId) then
                    entry:SetValue(true)
                    self:SendMessage("ActivityValueChanged", activityId, true)
                end

                self._container:AddChild(entry)
                self._entires[#self._entires+1] = entry
            end

        end
    end
end
