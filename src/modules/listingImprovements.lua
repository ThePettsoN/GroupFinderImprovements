local _, GroupFinderImprovements = ...

local ListingImprovements = {}
GroupFinderImprovements.Core:RegisterModule("ListingImprovements", ListingImprovements, "AceEvent-3.0")
local Const = GroupFinderImprovements.Const
local Debug = GroupFinderImprovements.Debug

-- WoW API
local C_LFGList = C_LFGList
local GetNumSavedInstances = GetNumSavedInstances
local GetSavedInstanceInfo = GetSavedInstanceInfo
local UnitClass = UnitClass

-- Lua API
local wipe = wipe
local hooksecurefunc = hooksecurefunc

local expansion = GetBuildInfo():sub(1,1)
local maxLevel
if expansion == "WOTLK" then
	maxLevel = 80
elseif expansion == "TBC" then
	maxLevel = 70
else
	maxLevel = 60
end

function ListingImprovements:OnInitialize()
    self._lockedInstanceIds = {}
	self._savedInstances = {}
	self._dataRangeCallbackRegistered = false
	self._lastCategoryId = nil
end

function ListingImprovements:OnEnable()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Module \"ListingImprovements\" enabled")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function ListingImprovements:OnPlayerEnteringWorld()
	self:UpdateAllowedRoles()

	hooksecurefunc("LFGListingActivityView_UpdateActivities", function(frame, categoryId)
		self:OnUpdateListningsActivities(frame, categoryId)
	end)
	hooksecurefunc(LFGListingFrame, "SetAllActivitiesForActivityGroup", function(...)
		self:OnSetAllActivitiesForActivityGroup(...)
	end)

	hooksecurefunc("LFGListingActivityView_InitActivityButton", function(frame)
		self:SetScrollBoxStyle(frame)
	end)

	hooksecurefunc("LFGListingActivityView_InitActivityGroupButton", function()
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "LFGListingActivityView_InitActivityGroupButton")
	end)

	LFGListingFrame:HookScript("OnShow", function(...) self:OnListningFrameShow(...) end)
end

function ListingImprovements:OnConfigChanged(event, category, key, value, ...)
end

function ListingImprovements:UpdateAllowedRoles()
	local _, class, _ = UnitClass("player")

	-- Find the "role" frames in the LFG UI
	local children = { LFGListingFrameSoloRoleButtons:GetChildren() }
	for _, frame in pairs(children) do
		if not Const.Roles[frame.roleID][class] then
			local checkButton = frame.CheckButton
			if checkButton then
				checkButton:Disable()
				checkButton:GetNormalTexture():SetDesaturated(true)
				checkButton:SetChecked(false)
			end

			frame:GetNormalTexture():SetDesaturated(true)
			_G[frame:GetName() .. "Background"]:SetDesaturated(true)
		end
	end
end

function ListingImprovements:RefreshSavedInstances()
	wipe(self._savedInstances)

	local numSavedInstances = GetNumSavedInstances()
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "RefreshSavedInstances - num saved instances: %d", numSavedInstances)
	for i = 1, numSavedInstances do
		local name = GetSavedInstanceInfo(i)
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "RefreshSavedInstances - %q", name)
		self._savedInstances[#self._savedInstances + 1] = name
	end
end

local HeroicActivityGroups = {
	[288] = true, -- TBC Heroic
	[289] = true, -- WOTLK Heroic
	[290] = true, -- Vanilla Raids
	[291] = true, -- TBC Raids
	[292] = true, -- WOTLK Raids
}

function ListingImprovements:LockSavedInstances(categoryId)
	local getAvailableActivities = C_LFGList.GetAvailableActivities
	local getActivityInfoTable = C_LFGList.GetActivityInfoTable
	local lockedInstanceIds = self._lockedInstanceIds

	wipe(lockedInstanceIds)

	local activityGroups = C_LFGList.GetAvailableActivityGroups(categoryId)
	for i = 1, #activityGroups do
		local activityGroupId = activityGroups[i]
		
		if HeroicActivityGroups[activityGroupId] then
			local activities = getAvailableActivities(categoryId, activityGroupId)
			if #activities > 0 then
				lockedInstanceIds[activityGroupId] = {}
				for j = 1, #activities do
					local activityId = activities[j]
					local activityInfo = getActivityInfoTable(activityId)

					local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
					for i = 1, #self._savedInstances do
						local savedName = self._savedInstances[i]
						if string.find(savedName, name) then
							self._lockedInstanceIds[activityGroupId][activityId] = name
							break
						end
					end
				end
			end
		end
	end
end

function ListingImprovements:OnUpdateListningsActivities(frame, categoryId)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnUpdateListningsActivities")
	self:LockSavedInstances(categoryId)

	if self._lastCategoryId ~= categoryId then
		self:OnDataRangeChanged(frame)
		self._lastCategoryId = categoryId
	end

	frame.ScrollBox:RegisterCallback(frame.ScrollBox.Event.OnDataRangeChanged, function(...)
		self:OnDataRangeChanged(frame)
	end, self)
end

local frameLookup = {}
function ListingImprovements:OnSetAllActivitiesForActivityGroup(lFGListingFrame, activityGroupID, selected, userInput)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnSetAllActivitiesForActivityGroup")
	local frames = LFGListingFrameActivityView.ScrollBox:GetFrames()
	local activityIds = self._lockedInstanceIds[activityGroupID]
	if activityIds then
		for activityId, name in pairs(activityIds) do
			local frame = frames[frameLookup[name]]
			if frame then
				self:SetScrollBoxEntryEnabled(frame, false, activityId)
			end
		end
	end
end

function ListingImprovements:OnDataRangeChanged(scrollFrame)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnDataRangeChanged")
	wipe(frameLookup)

	local frames = scrollFrame.ScrollBox:GetFrames()
	for i = 1, #frames do
		local frame = frames[i]
		local elementData = frame:GetElementData()
		local parent = elementData.parent
		local data = parent:GetData()

		self:SetScrollBoxEntryEnabled(frame, true)
		if data and HeroicActivityGroups[data.activityGroupID] then
			frameLookup[frame.NameButton.Name:GetText()] = i
		end
	end

	for activityGroupId, groupData in pairs(self._lockedInstanceIds) do
		for activityId, name in pairs(groupData) do
			local frame = frames[frameLookup[name]]
			if frame then
				self:SetScrollBoxEntryEnabled(frame, false, activityId)
				self:SetScrollBoxStyle(frame)
			end
		end
	end
end

function ListingImprovements:OnListningFrameShow()
	self:RefreshSavedInstances()
end

function ListingImprovements:SetScrollBoxEntryEnabled(frame, enabled, activityId)
	if enabled then
		frame.CheckButton:Enable()
		frame.NameButton:Enable()
		frame.NameButton.Name:SetFontObject("GameFontNormal")
	else
		frame.CheckButton:Disable()
		frame.NameButton:Disable()
		frame.CheckButton:SetChecked(false)

		LFGListingFrame:SetActivity(activityId, false, false)
	end
end

function ListingImprovements:SetScrollBoxStyle(frame)
	if frame.CheckButton:IsEnabled() then
		frame.CheckButton:Enable()
		frame.NameButton:Enable()
		frame.NameButton.Name:SetFontObject("GameFontNormal")
	else
		frame.NameButton.Name:SetFontObject("GameFontDisable")
		frame.CheckButton:SetDisabledTexture("Interface\\Buttons\\LockButton-Locked-Up")
		frame.CheckButton:GetDisabledTexture():SetDesaturated(true)
	end
end