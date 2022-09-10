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

function ListingImprovements:OnInitialize()
    self._lockedInstanceIds = {}
	self._savedInstances = {}
	self._dataRangeCallbackRegistered = false
	self._lastCategoryId = nil
end

function ListingImprovements:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function ListingImprovements:OnPlayerEnteringWorld()
	self:UpdateAllowedRoles()
	self:RefreshSavedInstances()

	hooksecurefunc("LFGListingActivityView_UpdateActivities", function(frame, categoryId)
		self:OnUpdateListningsActivities(frame, categoryId)
	end)
	hooksecurefunc(LFGListingFrame, "SetAllActivitiesForActivityGroup", function(...)
		self:OnSetAllActivitiesForActivityGroup(...)
	end)

	hooksecurefunc('LFGListingActivityView_InitActivityGroupButton', function(button, _, isCollapsed)
		button.CheckButton:SetDisabledTexture("Interface\\Buttons\\LockButton-Locked-Up")
		button.CheckButton:GetDisabledTexture():SetDesaturated(true)
	end)
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
	for i = 1, numSavedInstances do
		local name = GetSavedInstanceInfo(i)
		self._savedInstances[name] = true
	end
end

function ListingImprovements:LockSavedInstances(categoryId)
	local getAvailableActivities = C_LFGList.GetAvailableActivities
	local getActivityInfoTable = C_LFGList.GetActivityInfoTable
	local lockedInstanceIds = self._lockedInstanceIds

	wipe(lockedInstanceIds)

	local activityGroups = C_LFGList.GetAvailableActivityGroups(categoryId)
	for i = 1, #activityGroups do
		local activityGroupId = activityGroups[i]
		local activities = getAvailableActivities(categoryId, activityGroupId)
		if #activities > 0 then
			lockedInstanceIds[activityGroupId] = {}
			for j = 1, #activities do
				local activityId = activities[j]
				local activityInfo = getActivityInfoTable(activityId)

				local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
				if self._savedInstances[name] then
					self._lockedInstanceIds[activityGroupId][activityId] = name
				end
			end
		end
	end
end

function ListingImprovements:OnUpdateListningsActivities(frame, categoryId)
	self:LockSavedInstances(categoryId)

	if self._lastCategoryId ~= categoryId then
		self:OnDataRangeChanged(frame)
		self._lastCategoryId = categoryId
	end

	frame.ScrollBox:RegisterCallback(frame.ScrollBox.Event.OnDataRangeChanged, function(...)
		self:OnDataRangeChanged(frame)
	end, self)
end

function ListingImprovements:OnSetAllActivitiesForActivityGroup(frame, activityGroupID, selected, userInput)
	local activityIds = self._lockedInstanceIds[activityGroupID]
	if activityIds then
		for id, _ in pairs(activityIds) do
			frame:SetActivity(id, false)
		end
	end
end

local frameLookup = {}
function ListingImprovements:OnDataRangeChanged(scrollFrame)
	wipe(frameLookup)

	local frames = scrollFrame.ScrollBox:GetFrames()
	for i = 1, #frames do
		local frame = frames[i]
		self:SetScrollBoxEntryEnabled(frame, true)
		frameLookup[frame.NameButton.Name:GetText()] = i
	end

	for _, groupData in pairs(self._lockedInstanceIds) do
		for activityId, name in pairs(groupData) do
			local frame = frames[frameLookup[name]]
			if frame then
				self:SetScrollBoxEntryEnabled(frame, false, activityId)
			end
		end
	end
end

function ListingImprovements:SetScrollBoxEntryEnabled(frame, enabled, activityId)
	if enabled then
		frame.CheckButton:Enable()
		frame.NameButton:Enable()
		frame.NameButton.Name:SetFontObject("GameFontNormal")
	else
		frame.CheckButton:Disable()
		frame.NameButton:Disable()
		frame.NameButton.Name:SetFontObject("GameFontDisable")

		LFGListingFrame:SetActivity(activityId, false, false)
	end
end