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
    self._lockedActivityIds = {}
	self._savedInstances = {}
end

function ListingImprovements:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function ListingImprovements:DisableRoleSelection()
	local _, class, _ = UnitClass("player")

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

function ListingImprovements:OnPlayerEnteringWorld()
    self:DisableRoleSelection()

    wipe(self._savedInstances)

    local numSavedInstances = GetNumSavedInstances()
	for i = 1, numSavedInstances do
		local name = GetSavedInstanceInfo(i)
		self._savedInstances[name] = true
	end

    hooksecurefunc("LFGListingActivityView_UpdateActivities", function(frame, categoryId) self:OnUpdateListningsActivities(frame, categoryId) end)
	hooksecurefunc(LFGListingFrame, "SetAllActivitiesForActivityGroup", function(...) self:OnSetAllActivitiesForActivityGroup(...) end)
end

function ListingImprovements:OnConfigChanged(event, category, key, value, ...)
end

function ListingImprovements:OnUpdateListningsActivities(frame, categoryId)
	wipe(self._lockedActivityIds)

	local activityGroups = C_LFGList.GetAvailableActivityGroups(categoryId)
	for i = 1, #activityGroups do
		local activityGroupID = activityGroups[i]
		local activities = C_LFGList.GetAvailableActivities(categoryId, activityGroupID)
		if (#activities > 0) then
			self._lockedActivityIds[activityGroupID] = {}

			for j = 1, #activities do
				local activityId = activities[j]
				local activityInfo = C_LFGList.GetActivityInfoTable(activityId)
				local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
				if self._savedInstances[name] then
					self._lockedActivityIds[activityGroupID][activityId] = name
				end
			end
		end
	end

	frame.ScrollBox:RegisterCallback(frame.ScrollBox.Event.OnDataRangeChanged, function(...)
		self:OnDataRangeChanged(frame)
	end, self)
end

local frameLookup = {}
function ListingImprovements:OnDataRangeChanged(scrollFrame)
	wipe(frameLookup)

	local frames = scrollFrame.ScrollBox:GetFrames()
	for i = 1, #frames do
		local frame = frames[i]
		frame.CheckButton:Enable()
		frame.NameButton:Enable()
		frame.NameButton.Name:SetFontObject("GameFontNormal")
		frameLookup[frame.NameButton.Name:GetText()] = i
	end

	for _, groupData in pairs(self._lockedActivityIds) do
		for activityId, name in pairs(groupData) do
			local frame = frames[frameLookup[name]]
			if frame then
				frame.NameButton.Name:SetFontObject("GameFontDisable")
				frame.CheckButton:SetDisabledTexture("Interface\\Buttons\\LockButton-Locked-Up")
				frame.CheckButton:GetDisabledTexture():SetDesaturated(true)

				frame.CheckButton:Disable()
				frame.NameButton:Disable()

				LFGListingFrame:SetActivity(activityId, false, false)
			end
		end
	end
end

function ListingImprovements:OnSetAllActivitiesForActivityGroup(frame, activityGroupID, selected, userInput)
	local activityIds = self._lockedActivityIds[activityGroupID]
	if activityIds then
		for id, _ in pairs(activityIds) do
			frame:SetActivity(id, false)
		end
	end
end