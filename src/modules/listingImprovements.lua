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


local HeroicActivityGroups = {
	[288] = true, -- TBC Heroic
	[289] = true, -- WOTLK Heroic
	[290] = true, -- Vanilla Raids
	[291] = true, -- TBC Raids
	[292] = true, -- 10 WOTLK Raids
	[293] = true, -- 25 WOTLK Raids
}

local FrameLookup = {}
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
	self._savedEntries = {} -- Object<EntryId, Name>
	self._savedInstances = {} -- Array<Name>
	self._dataRangeCallbackRegistered = false -- Boolean
	self._lastCategoryId = nil -- Number
end

function ListingImprovements:OnEnable()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Module \"ListingImprovements\" enabled")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function ListingImprovements:OnPlayerEnteringWorld()
	self:UpdateAllowedRoles()

	hooksecurefunc("LFGListingActivityView_UpdateActivities", function(frame, categoryId) -- Called on LFGListingActivityView being shown
		self:OnUpdateListningsActivities(frame, categoryId)
	end)

	hooksecurefunc("LFGListingActivityView_InitActivityButton", function(buttonFrame, data) -- Called on all entries when a group's checkbutton is being clicked
		local name = buttonFrame.NameButton.Name:GetText()
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Entry %q being changed due to group button", name)

		for _, savedEntryname in pairs(self._savedEntries) do
			if name == savedEntryname then
				local activityInfoTable = C_LFGList.GetActivityInfoTable(data.activityID)
				if HeroicActivityGroups[activityInfoTable.categoryID] then
					self:LockInstance(buttonFrame)
					break
				end
			end
		end
	end)

	hooksecurefunc(LFGListingFrame, "UpdatePostButtonEnableState", function(frame, isRecursive)
		if not isRecursive then
			self:CheckAllowedToPost()
		end
	end)

	LFGListingFrame:HookScript("OnShow", function(...) self:OnListningFrameShow(...) end)
end

function ListingImprovements:OnConfigChanged(event, category, key, value, ...)
end

function ListingImprovements:CheckAllowedToPost()
	if not self._roleButtons then
		return
	end

	local anyChecked = false
	for _, frame in pairs(self._roleButtons) do
		if frame.CheckButton:GetChecked() then
			anyChecked = true
			break
		end
	end

	if not anyChecked then
		LFGListingFrame.PostButton:SetEnabled(false)
	else
		LFGListingFrame:UpdatePostButtonEnableState(true)
	end
end

function ListingImprovements:UpdateAllowedRoles()
	local _, class, _ = UnitClass("player")

	if not self._roleButtons then
		self._roleButtons = { LFGListingFrameSoloRoleButtons:GetChildren() }
	end

	for _, frame in pairs(self._roleButtons) do
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

		frame.CheckButton:HookScript("OnClick", function()
			self:CheckAllowedToPost()
		end)
	end
end

-- Clear all saved instances and refresh
function ListingImprovements:RefreshSavedInstances()
	wipe(self._savedInstances)

	local numSavedInstances = GetNumSavedInstances()
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "RefreshSavedInstances - num saved instances: %d", numSavedInstances)
	for i = 1, numSavedInstances do
		local name, _, _, _, _, _, _, isRaid, maxPlayers = GetSavedInstanceInfo(i)
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "RefreshSavedInstances - %q", name)
		self._savedInstances[#self._savedInstances + 1] = {
			name = name,
			isRaid = isRaid,
			raidActivityGroupId = isRaid and (maxPlayers == 25 and 293 or 292) or nil
		}
	end
end

-- Map the saved instances with the entries in the current category
function ListingImprovements:UpdateSavedEntries(categoryId)
	local savedEntries = self._savedEntries
	wipe(savedEntries)

	local activityGroups = C_LFGList.GetAvailableActivityGroups(categoryId)
	for i = 1, #activityGroups do

		local activityGroupId = activityGroups[i]
		if HeroicActivityGroups[activityGroupId] then

			local activities = C_LFGList.GetAvailableActivities(categoryId, activityGroupId)
			for j = 1, #activities do

				local activityId = activities[j]
				local activityInfo = C_LFGList.GetActivityInfoTable(activityId)
				local name = activityInfo.shortName ~= "" and activityInfo.shortName or activityInfo.fullName
				for k = 1, #self._savedInstances do

					local data = self._savedInstances[k]
					if not data.isRaid or data.raidActivityGroupId == activityGroupId then
						if string.find(data.name, name:gsub("%-", "%%-")) then
							savedEntries[activityId] = name
							break
						end
					end
				end
			end
		end
	end
end

function ListingImprovements:OnUpdateListningsActivities(frame, categoryId)  -- Called on LFGListingActivityView being shown
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnUpdateListningsActivities")
	self:UpdateSavedEntries(categoryId)

	if self._lastCategoryId ~= categoryId then
		self:OnDataRangeChanged(frame)
		self._lastCategoryId = categoryId
	end

	frame.ScrollBox:RegisterCallback(frame.ScrollBox.Event.OnDataRangeChanged, function(...)
		self:OnDataRangeChanged(frame)
	end, self)
end
test = nil
-- Called when the data in the scroll frame is being changed. Either by opening the frame, scrolling, or expanding/collapsing a group
function ListingImprovements:OnDataRangeChanged(scrollFrame)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnDataRangeChanged")
	wipe(FrameLookup)

	-- Go through all frames, filter out all instances that you can get saved in
	-- Store each frame based on their text
	local frames = scrollFrame.ScrollBox:GetFrames()
	for i = 1, #frames do
		local frame = frames[i]
		local elementData = frame:GetElementData()
		local parent = elementData.parent
		local data = parent:GetData()

		if data and HeroicActivityGroups[data.activityGroupID] then
			FrameLookup[frame.NameButton.Name:GetText()] = i
		end
	end

	-- Go through each saved instances, if the saved instance matches a frame then lock it
	for id, name in pairs(self._savedEntries) do
		local frame = frames[FrameLookup[name]]
		if frame and frame:GetElementData().data.activityID == id then
			self:LockInstance(frame)
		end
	end
end

-- Called when the listing frame is being shown
function ListingImprovements:OnListningFrameShow()
	self:RefreshSavedInstances()
end

local StringCache = {} -- Object<Name, Modified Name>
function ListingImprovements:LockInstance(frame)
	local name = frame:GetElementData().data.name
	local str = StringCache[name]
	if not str then
		str = string.format("|TInterface\\Buttons\\LockButton-Locked-Up:%d|t%s", frame.NameButton.Name:GetStringHeight() * 2, name)
		StringCache[name] = str
	end
	frame.NameButton.Name:SetText(str)
end
