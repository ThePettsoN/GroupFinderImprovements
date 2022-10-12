local _, GroupFinderImprovements = ...

local BrowseImprovements = {}
GroupFinderImprovements.Core:RegisterModule("BrowseImprovements", BrowseImprovements, "AceEvent-3.0", "AceTimer-3.0")
local Const = GroupFinderImprovements.Const
local Debug = GroupFinderImprovements.Debug

-- Lua API
local tremove = tremove
local hooksecurefunc = hooksecurefunc
local tinsert = tinsert

-- WoW API
local CreateFrame = CreateFrame
local CreateDataProvider = CreateDataProvider
local C_LFGList = C_LFGList
local C_FriendList = C_FriendList

function BrowseImprovements:OnInitialize()
	self._autoRefreshButton = nil
	self._autoRefreshInterval = 2
	self._autoRefreshTimerHandle = nil
	self._autoRefreshIsRunning = false

	self._storedResults = {}
	self._blacklistedPlayers = {}

	self._filters = {
		numMembers = { 0, 999 },
		numTanks = { 0, 999 },
		numHealers = { 0, 999 },
		numDamagers = { 0, 999 },
	}
end

function BrowseImprovements:OnEnable()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Module \"BrowseImprovements\" enabled")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", "OnLFGListSearchResultsReceived")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", "OnLFGListSearchResultReceived")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function BrowseImprovements:CreateRefreshButton()
	if self._autoRefreshButton then
		GroupFinderImprovements:dprint(Debug.Severity.WARNING, "Tried to create refresh button, already exists")
		return
	end

	local searchButton = LFGBrowseFrameRefreshButton

	local button = CreateFrame("Button", nil, LFGBrowseFrame)
	button:SetPoint("RIGHT", searchButton, "LEFT", 0, 0)

	if Const.ElvUI then
		button:SetWidth(32)
		button:SetHeight(32)
	else
		button:SetWidth(searchButton:GetWidth())
		button:SetHeight(searchButton:GetHeight())
	end

	button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
	button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
	button:SetDisabledTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")

	button:Disable()
	button:GetDisabledTexture():SetDesaturated(true)
	button:SetScript("OnClick", function(frame, ...)
		self:RefreshButtonClick(frame, ...)
	end)

	self._autoRefreshButton = button
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Auto refresh button created")
end

function BrowseImprovements:RefreshButtonClick(frame, ...)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Auto refresh button clicked")
	if self._autoRefreshIsRunning then
		frame:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
		self:StopAutoRefresh()
	else
		frame:SetNormalTexture("Interface/TimeManager/PauseButton")
		self:StartAutoRefresh()
	end
end

function BrowseImprovements:StopAutoRefresh()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Stopping auto refresh")

	self._autoRefreshIsRunning = false
	self:AbortTimer()
end

function BrowseImprovements:StartAutoRefresh()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Starting auto refresh")

	self._autoRefreshIsRunning = true
	if self._autoRefreshTimerHandle then
		GroupFinderImprovements:dprint(Debug.Severity.WARNING, "Trying to start auto refresh with timer already enabled")
		self:CancelTimer(self._autoRefreshTimerHandle)
		self._autoRefreshTimerHandle = nil
	end

	self:OnAutoRefreshTimerTick()
end

function BrowseImprovements:AbortTimer()
	if self._autoRefreshTimerHandle then
		self:CancelTimer(self._autoRefreshTimerHandle)
		self._autoRefreshTimerHandle = nil
	end
end

local function filterNumericalRange(range, value)
	return value >= range[1] and value <= range[2]
end

local numRoles = {
	[Const.RolesLookup.Tank] = 0,
	[Const.RolesLookup.Healer] = 0,
	[Const.RolesLookup.Damager] = 0,
}
function BrowseImprovements:CheckFilterSearchResult(id, searchInfo)
	local leaderName = searchInfo.leaderName
	local numMembers = searchInfo.numMembers

	if searchInfo.hasSelf then
		return false
	end

	if not leaderName then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Failed to get leaderName %q for search result %q", tostring(leaderName), id)
	end

	local filters = self._filters

	if searchInfo.isDelisted then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: IsDelisted | Id: %q | LeaderName %q", id, tostring(leaderName))
		return true
	elseif not filterNumericalRange(filters.numMembers, numMembers) then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: Members out of bounds (%d) | Id: %q | LeaderName %q", numMembers, id, tostring(leaderName))
		return true
	else
		numRoles[Const.RolesLookup.Tank] = 0
		numRoles[Const.RolesLookup.Healer] = 0
		numRoles[Const.RolesLookup.Damager] = 0

		local getSearchResultMemberInfo = C_LFGList.GetSearchResultMemberInfo
		for i = 1, numMembers do
			local name, role, classFile, _, level = getSearchResultMemberInfo(id, i)
			if name and role then
				if Const.Roles[role][classFile] then
					-- GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "%q (%s) counts as %q", name, classFile, role)
					numRoles[role] = numRoles[role] + 1
				else
					-- GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "%q (%s) is not allowed as %q. Count as %q", name, classFile, role, Const.RolesLookup.Damager)
					numRoles[Const.RolesLookup.Damager] = numRoles[Const.RolesLookup.Damager] + 1
				end
			else
				-- GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "%q (%s) failed to get role %q. Count as %q", tostring(name), tostring(classFile), tostring(role), Const.RolesLookup.Damager)
				numRoles[Const.RolesLookup.Damager] = numRoles[Const.RolesLookup.Damager] + 1
			end
		end

		if not filterNumericalRange(filters.numTanks, numRoles[Const.RolesLookup.Tank]) then
			GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: Tanks out of bounds (%d) | Id: %q | LeaderName %q", numRoles[Const.RolesLookup.Tank], id, tostring(leaderName))
			return true
		end
		if not filterNumericalRange(filters.numHealers, numRoles[Const.RolesLookup.Healer]) then
			GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: Healers out of bounds (%d) | Id: %q | LeaderName %q", numRoles[Const.RolesLookup.Healer], id, tostring(leaderName))
			return true
		end
		if not filterNumericalRange(filters.numDamagers, numRoles[Const.RolesLookup.Damager]) then
			GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: Damagers out of bounds (%d) | Id: %q | LeaderName %q", numRoles[Const.RolesLookup.Damager], id, tostring(leaderName))
			return true
		end
	end

	return false
end

function BrowseImprovements:CheckFilterBlacklistPlayers(id, searchInfo)
	local leaderName = searchInfo.leaderName

	if not leaderName then
		return false
	end

	if self._blacklistedPlayers[leaderName] then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Filter entry. Reason: Leader blacklisted | Id: %q | LeaderName %q", id, leaderName)
		return true
	end

	return false
end

function BrowseImprovements:BlacklistPlayer(_, searchResultId, name)
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Blacklist Player: Name: %q | id: %q", name, searchResultId)

	GroupFinderImprovements.Db:SetProfileData(name, true, "blacklist")
	self:RunFilters()
end

function BrowseImprovements:OnPlayerEnteringWorld()
    self:CreateRefreshButton()

	-- UpdateResults
	hooksecurefunc(LFGBrowseFrame, "UpdateResultList", function(frame)
		self:OnSortSearchResults(frame.results)
	end)

	hooksecurefunc("LFGBrowseSearchEntry_OnClick", function(frame, button)
		self:OnLFGBrowseSearchEntryClick(frame, button)
	end)
end

function BrowseImprovements:OnLFGListSearchResultsReceived()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnLFGListSearchResultsReceived")
	GroupFinderImprovements:dprint(
		Debug.Severity.DEBUG,
		"Auto Refresh Running: %q | Refresh Interval: %q | Timer Handle: %q",
		tostring(self._autoRefreshIsRunning),
		tostring(self._autoRefreshInterval),
		tostring(self._autoRefreshTimerHandle ~= nil)
	)

	self:AbortTimer()
	if self._autoRefreshIsRunning then
		self._autoRefreshTimerHandle = self:ScheduleTimer(self.OnAutoRefreshTimerTick, self._autoRefreshInterval, self)
	end

	if not self._autoRefreshButton:IsEnabled() then
		self._autoRefreshButton:Enable()
	end
end

function BrowseImprovements:OnLFGListSearchResultReceived(event, resultId)
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnLFGListSearchResultReceived | Result Id: %d", resultId)

	if LFGBrowseFrame.searching then -- TODO: These should potential be stored for later
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Results are updating. Ignore individual updates")
		return
	end

	if #self._storedResults == 0 then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "No stored results yet. Ignore individual updates")
		return
	end

	local searchInfo = C_LFGList.GetSearchResultInfo(resultId)
	if not searchInfo then
		GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Failed to get search info from resultId %d", resultId)
		return
	end

	if self:CheckFilterSearchResult(resultId, searchInfo) or self:CheckFilterBlacklistPlayers(resultId, searchInfo) then
		local dataProvider = securecallfunction(LFGBrowseFrame.ScrollBox.GetDataProvider, LFGBrowseFrame.ScrollBox)
		if not dataProvider then
			return
		end

		local results = self._storedResults
		for i = #results, 1, -1 do
			if results[i] == resultId then
				securecallfunction(dataProvider.RemoveIndex, dataProvider, i)
				tremove(results, i)
			end
		end
	end
end

function BrowseImprovements:OnConfigChanged(event, category, key, value, ...)
	local db = GroupFinderImprovements.Db
	local dbFilters = db:GetCharacterData("filters")
	local filters = self._filters

	filters.numMembers[1] = dbFilters.members.min or 0
	filters.numMembers[2] = dbFilters.members.max or 999

	filters.numTanks[1] = dbFilters.tanks.min or 0
	filters.numTanks[2] = dbFilters.tanks.max or 999

	filters.numHealers[1] = dbFilters.healers.min or 0
	filters.numHealers[2] = dbFilters.healers.max or 999

	filters.numDamagers[1] = dbFilters.dps.min or 0
	filters.numDamagers[2] = dbFilters.dps.max or 999

	self._blacklistedPlayers = db:GetProfileData("blacklist")
	local autoRefreshInterval = db:GetProfileData("refresh_interval")
	if autoRefreshInterval ~= self._autoRefreshInterval then
		self._autoRefreshInterval = autoRefreshInterval
		if key == "refresh_interval" then
			self:OnLFGListSearchResultsReceived()
		end
	end

	self:RunFilters()
end

function BrowseImprovements:OnAutoRefreshTimerTick()
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "OnAutoRefreshTimerTick | Refresh Running: %q", tostring(self._autoRefreshIsRunning))

	if self._autoRefreshIsRunning then
		self._autoRefreshTimerHandle = nil
		LFGBrowseFrameRefreshButton:Click()
	elseif self._autoRefreshTimerHandle then
		GroupFinderImprovements:dprint(Debug.Severity.WARNING, "Got auto refresh timer tick with refresh disabled but timer handle is still defined")
		self._autoRefreshTimerHandle = nil
	end
end

function BrowseImprovements:OnSortSearchResults(results)
	if not results then
		return
	end

	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnSortSearchResults | Num Results: %d", #results)
	wipe(self._storedResults)
	for i = 1, #results do
		self._storedResults[i] = results[i]
	end

	self:RunFilters()
end


function BrowseImprovements:AddContextMenuButton(text, funcName, arg1, arg2)
	local info = securecallfunction(UIDropDownMenu_CreateInfo)
	info.text = text
	info.notCheckable = true
	info.icon = nil
	info.arg1 = arg1
	info.arg2 = arg2
	info.func = function(...) self[funcName](self, ...) end
	securecallfunction(UIDropDownMenu_AddButton, info)
end

function BrowseImprovements:OnLFGBrowseSearchEntryClick(frame, button)
	if button == "RightButton" then
		local searchResultInfo = C_LFGList.GetSearchResultInfo(frame.resultID)
		local leaderName = searchResultInfo.leaderName

		-- Create title
		securecallfunction(UIDropDownMenu_AddButton, {
			text = "GroupFinderImprovements",
			isTitle = true,
			notCheckable = true,
		})

		self:AddContextMenuButton("Who " .. leaderName, "WhoLookup", frame.resultID, leaderName)
		self:AddContextMenuButton("Blacklist " .. leaderName, "BlacklistPlayer", frame.resultID, leaderName)
		if GroupFinderImprovements:DebugEnabled() then
			self:AddContextMenuButton("Debug " .. leaderName, "DebugEntry", frame.resultID, leaderName)
		end
	end
end

function BrowseImprovements:RunFilters()
	if not LFGBrowseFrame then
		return
	end

	local getSearchResultInfo = C_LFGList.GetSearchResultInfo

	local dataProvider = securecallfunction(LFGBrowseFrame.ScrollBox.GetDataProvider, LFGBrowseFrame.ScrollBox)
	if not dataProvider then
		return
	end

	local results = self._storedResults
	for i = #results, 1, -1 do
		local id = results[i]
		local searchInfo = getSearchResultInfo(id)

		if self:CheckFilterSearchResult(id, searchInfo) or self:CheckFilterBlacklistPlayers(id, searchInfo) then
			securecallfunction(dataProvider.RemoveIndex, dataProvider, i)
			tremove(results, i)
		end
	end
end

function BrowseImprovements:WhoLookup(_, searchResultId, name)
	C_FriendList.SendWho(name)
end

function BrowseImprovements:DebugEntry(_, searchResultId, name)
	local searchInfo = C_LFGList.GetSearchResultInfo(searchResultId)
	GroupFinderImprovements:tDump(searchInfo)
	GroupFinderImprovements:dprint(Debug.Severity.DEBUG, "Id: %d", searchResultId)
end