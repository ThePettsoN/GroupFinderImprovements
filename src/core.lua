local _, GroupFinderImprovements = ...

GroupFinderImprovements.DEBUG = false

GroupFinderImprovements.dprint = function(msg, ...)
	if GroupFinderImprovements.DEBUG then
		print(string.format("[GroupFinderImprovements] %s", string.format(msg, ...)))
	end
end

-- Lua API
local tRemove = table.remove
local stringformat = string.format
local stringgmatch = string.gmatch
local tremove = tremove
local tinsert = tinsert

-- WoW API
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_LFGList = C_LFGList
local CreateDataProvider = CreateDataProvider

local Core = LibStub("AceAddon-3.0"):NewAddon("GroupFinderImprovementsCore", "AceEvent-3.0", "AceTimer-3.0")
GroupFinderImprovements.Core = Core

local ROLES = {
	TANK = {
		PALADIN = true,
		WARRIOR = true,
		DRUID = true,
		DEATHKNIGHT = true,
	},
	HEALER = {
		PALADIN = true,
		PRIEST = true,
		SHAMAN = true,
		DRUID = true,
	},
	DAMAGER = {
		WARRIOR = true,
		PALADIN = true,
		HUNTER = true,
		ROGUE = true,
		PRIEST = true,
		DEATHKNIGHT = true,
		SHAMAN = true,
		MAGE = true,
		WARLOCK = true,
		DRUID = true,
	}
}

function Core:OnInitialize()
	GroupFinderImprovements.Const = {
		ElvUI = _G.ElvUI ~= nil
	}

	self._autoRefreshRunning = false
	self._autoRefreshInterval = 2
	self._autoRefreshTimer = nil
	self._autoRefreshButton = nil
	self._contextMenuBlacklist = nil
	self._contextMenuModified = false
	self._blacklistedPlayers = {}
	self._latestResults = {}
end

function Core:OnEnable()
	self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", "OnLFGListSearchResultsReceived")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", "OnLFGListSearchResultReceived")
	self:OnConfigChanged()
end

function Core:OnPlayerEnteringWorld()
	self:_createRefreshButton()
	self:_disableRoleSelection()

	for _, module in self:IterateModules() do
		if module.OnPlayerEnteringWorld then
			module:OnPlayerEnteringWorld()
		end
	end

	hooksecurefunc("LFGBrowseUtil_SortSearchResults", function(results) self:_onSortSearchResults(results) end)
	hooksecurefunc(LFGBrowseFrame, "GetSearchEntryMenu", function(frame, resultID)
		self:_onGetSearchEntryMenu(frame, resultID)
	end)
end

function Core:_createRefreshButton()
	local searchButton = LFGBrowseFrameRefreshButton

	local button = CreateFrame("Button", nil, LFGBrowseFrame)
	button:SetPoint("RIGHT", searchButton, "LEFT", 0, 0)

	if GroupFinderImprovements.Const.ElvUI then
		button:SetWidth(32)
		button:SetHeight(32)
	else
		button:SetWidth(searchButton:GetWidth())
		button:SetHeight(searchButton:GetHeight())
	end
	
	button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
	button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
	button:SetDisabledTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")

	button:SetScript("OnClick", function(frame, ...) self:_onRefreshButtonClick(frame, ...) end)
	button:Disable()
	button:GetDisabledTexture():SetDesaturated(true)

	self._autoRefreshButton = button
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	GroupFinderImprovements[name] = mod
end

function Core:OnConfigChanged(event, category, key, value, ...)
	local db = GroupFinderImprovements.Db

	self._min_members = db:GetCharacterData("filters", "members", "min") or 0
	self._max_members = db:GetCharacterData("filters", "members", "max") or 999

	self._min_tanks = db:GetCharacterData("filters", "tanks", "min") or 0
	self._max_tanks = db:GetCharacterData("filters", "tanks", "max") or 999
	
	self._min_healers = db:GetCharacterData("filters", "healers", "min") or 0
	self._max_healers = db:GetCharacterData("filters", "healers", "max") or 999

	self._min_dps = db:GetCharacterData("filters", "dps", "min") or 0
	self._max_dps = db:GetCharacterData("filters", "dps", "max") or 999

	self._blacklistedPlayers = db:GetProfileData("blacklist")
	local autoRefreshInterval = db:GetProfileData("refresh_interval")
	if autoRefreshInterval ~= self._autoRefreshInterval then
		self._autoRefreshInterval = autoRefreshInterval
		if key == "refresh_interval" then
			self:OnLFGListSearchResultsReceived()
		end
	end

	self:_onSortSearchResults(self._latestResults)
end

function Core:_updateStaleResults()
	if LFGBrowseFrame then
		local dataProvider = CreateDataProvider();
		local results = self._latestResults;
		for index = 1, #results do
			dataProvider:Insert({resultID=results[index]});
		end
		LFGBrowseFrame.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
	end
end

function Core:OnLFGListSearchResultsReceived()
	GroupFinderImprovements.dprint("OnLFGListSearchResultsReceived: Addon Running: %q | Refresh Interval: %q | Timer Running: %q", tostring(self._autoRefreshRunning), tostring(self._autoRefreshInterval), tostring(self._autoRefreshTimer ~= nil))
	if self._autoRefreshTimer then
		self:CancelTimer(self._autoRefreshTimer)
		self._autoRefreshTimer = nil
	end

	if self._autoRefreshRunning then
		self._autoRefreshTimer = self:ScheduleTimer(self._onTimer, self._autoRefreshInterval, self)
	end

	if not self._autoRefreshButton:IsEnabled() then
		self._autoRefreshButton:Enable()
	end
end

function Core:OnLFGListSearchResultReceived(event, resultId)
	GroupFinderImprovements.dprint("OnLFGListSearchResultReceived: %q", resultId)
	local searchInfo = C_LFGList.GetSearchResultInfo(resultId)
	if searchInfo and self:_shouldFilter(resultId, searchInfo) then
		for i = 1, #self._latestResults do
			if self._latestResults[i] == resultId then
				GroupFinderImprovements.dprint("New filtered entry removed")
				tremove(self._latestResults, i)
				self:_updateStaleResults()
				break
			end
		end
	end
end

local numTanks, numHealers, numDPS = 0, 0, 0
local TANK_ROLE = "TANK"
local HEALER_ROLE = "HEALER"
function Core:_shouldFilter(id, searchInfo)
	local leaderName = searchInfo.leaderName
	local numMembers = searchInfo.numMembers

	if not leaderName then
		return false
	end

	if searchInfo.isDelisted then
		GroupFinderImprovements.dprint("Filter entry. Reason: IsDelisted | Id: %q | LeaderName %q", id, leaderName)
		return true
	elseif self._min_members > numMembers or self._max_members < numMembers then
		GroupFinderImprovements.dprint("Filter entry. Reason: Members out of bounds (%d) | Id: %q | LeaderName %q", numMembers, id, leaderName)
		return true
	else
		numTanks, numHealers, numDPS = 0, 0, 0
		for i = 1, numMembers do
			local _, role, classFile, _, level = C_LFGList.GetSearchResultMemberInfo(id, i)
			if role == TANK_ROLE and ROLES.TANK[classFile] then
				numTanks = numTanks + 1
			elseif role == HEALER_ROLE and ROLES.HEALER[classFile] then
				numHealers = numHealers + 1
			else
				numDPS = numDPS + 1
			end
		end

		if self._min_tanks > numTanks or self._max_tanks < numTanks then
			GroupFinderImprovements.dprint("Filter entry. Reason: Tanks out of bounds (%d) | Id: %q | LeaderName %q", numTanks, id, leaderName)
			return true
		elseif self._min_healers > numHealers or self._max_healers < numHealers then
			GroupFinderImprovements.dprint("Filter entry. Reason: Healers out of bounds (%d) | Id: %q | LeaderName %q", numHealers, id, leaderName)
			return true
		elseif self._min_dps > numDPS or self._max_dps < numDPS then
			GroupFinderImprovements.dprint("Filter entry. Reason: DPS out of bounds (%d) | Id: %q | LeaderName %q", numDPS, id, leaderName)
			return true
		elseif self._blacklistedPlayers[leaderName] then
			GroupFinderImprovements.dprint("Filter entry. Reason: Leader blacklisted | Id: %q | LeaderName %q", id, leaderName)
			return true
		end
	end
	
	return false
end

function Core:_onRefreshButtonClick(frame, ...)
	if self._autoRefreshRunning then
		self._autoRefreshRunning = false
		frame:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
		if self._autoRefreshTimer then
			self:CancelTimer(self._autoRefreshTimer)
			self._autoRefreshTimer = nil
		end
	else
		self._autoRefreshRunning = true
		frame:SetNormalTexture("Interface/TimeManager/PauseButton")
		self:_onTimer()
	end
end

function Core:_onTimer()
	GroupFinderImprovements.dprint("OnTimer: Addon Running: %q", tostring(self._autoRefreshRunning))
	if self._autoRefreshRunning then
		LFGBrowseFrameRefreshButton:Click()
		self._autoRefreshTimer = nil
	end
end

function Core:_onSortSearchResults(results)
	GroupFinderImprovements.dprint("OnSortSearchResults: Num Results: %d", #results)
	local getSearchResultInfo = C_LFGList.GetSearchResultInfo
	for i = #results, 1, -1 do
		local id = results[i]
		local searchInfo = getSearchResultInfo(id)
		if self:_shouldFilter(id, searchInfo) then
			tremove(results, i)
		end
	end

	self._latestResults = results
	self:_updateStaleResults()
end

function Core:_onGetSearchEntryMenu(frame, resultId)
	if not self._contextMenuModified then
		GroupFinderImprovements.dprint("Populate ContextMenu")
		self._contextMenuModified = true

		local menu = LFGBrowseFrame:GetSearchEntryMenu(resultId)
		self._contextMenuBlacklist = {
			text = "Blacklist Leader",
			notCheckable = true,
			arg1 = nil,
			arg2 = nil,
			func = function(_, id, name)
				self:_onBlackListPlayer(_, id, name)
			end
		}
		tinsert(menu, #menu, self._contextMenuBlacklist)

		if GroupFinderImprovements.DEBUG then
			self._debugContext = {
				text = "Debug Entry",
				notCheckable = true,
				arg1 = nil,
				arg2 = nil,
				func = function(_, id, name)
					print(string.format("TEST: %s", menu[1].text))
					local searchInfo = C_LFGList.GetSearchResultInfo(id)
					local memberCounts = C_LFGList.GetSearchResultMemberCounts(id)
					print(string.format("id: %d", id))
					print(string.format("name: %s", searchInfo.leaderName))
					print(string.format("DAMAGER: %d", memberCounts.DAMAGER))
					print(string.format("DAMAGER_REMAINING: %d", memberCounts.DAMAGER_REMAINING))
					print(string.format("TANK: %d", memberCounts.TANK))
					print(string.format("TANK_REMAINING: %d", memberCounts.TANK_REMAINING))
					print(string.format("HEALER: %d", memberCounts.HEALER))
					print(string.format("HEALER_REMAINING: %d", memberCounts.HEALER_REMAINING))
					print(string.format("NOROLE: %d", memberCounts.NOROLE))

					print(string.format("Members: Min %d | Max: %d", self._min_members, self._max_members))
					print(string.format("Tanks: Min %d | Max: %d", self._min_tanks, self._max_tanks))
					print(string.format("Healers: Min %d | Max: %d", self._min_healers, self._max_healers))
					print(string.format("DPS: Min %d | Max: %d", self._min_dps, self._max_dps))
				end
			}
			tinsert(menu, #menu, self._debugContext)
		end
	end

	if self._contextMenuBlacklist then
		local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId)
		self._contextMenuBlacklist.arg1 = resultId
		self._contextMenuBlacklist.arg2 = searchResultInfo.leaderName
	end

	if GroupFinderImprovements.DEBUG then
		if self._debugContext then
			local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId)
			self._debugContext.arg1 = resultId
			self._debugContext.arg2 = searchResultInfo.leaderName
		end
	end
end

function Core:_onBlackListPlayer(_, id, name)
	GroupFinderImprovements.dprint("Blacklist Player: Name: %q | id: %q", name, id)
	GroupFinderImprovements.Db:SetProfileData(name, true, "blacklist")
	self:_updateStaleResults()
end

function Core:_disableRoleSelection()
	local _, class, _ = UnitClass("player")

	local children = { LFGListingFrameSoloRoleButtons:GetChildren() }
	for _, frame in pairs(children) do
		if not ROLES[frame.roleID][class] then
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