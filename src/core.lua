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
local strlower = strlower
local wipe = wipe

-- WoW API

local Core = LibStub("AceAddon-3.0"):NewAddon("GroupFinderImprovementsCore", "AceEvent-3.0", "AceTimer-3.0")
GroupFinderImprovements.Core = Core

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
	self:OnConfigChanged()
end

function Core:OnPlayerEnteringWorld()
	self:_createRefreshButton()

	for name, module in self:IterateModules() do
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

	self._min_members = db:GetCharacterData("filters", "members", "min")
	self._max_members = db:GetCharacterData("filters", "members", "max")

	self._min_tanks = db:GetCharacterData("filters", "tanks", "min")
	self._max_tanks = db:GetCharacterData("filters", "tanks", "max")
	
	self._min_healers = db:GetCharacterData("filters", "healers", "min")
	self._max_healers = db:GetCharacterData("filters", "healers", "max")

	self._min_dps = db:GetCharacterData("filters", "dps", "min")
	self._max_dps = db:GetCharacterData("filters", "dps", "max")

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

function Core:OnLFGListSearchResultsReceived()
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
	if self._autoRefreshRunning then
		LFGBrowseFrameRefreshButton:Click()
		self._autoRefreshTimer = nil
	end
end

function Core:_onSortSearchResults(results)
	local getSearchResultInfo = C_LFGList.GetSearchResultInfo
	for i = #results, 1, -1 do
		local id = results[i]
		local searchInfo = getSearchResultInfo(id)
		if not searchInfo.hasSelf then
			local leaderName = searchInfo.leaderName
			local numMembers = searchInfo.numMembers

			if searchInfo.isDelisted then
				tremove(results, i)
			elseif (self._min_members and self._min_members > numMembers) or (self._max_members and self._max_members < numMembers) then
				tremove(results, i)
			else
				local memberCounts = C_LFGList.GetSearchResultMemberCounts(id)
				if (self._min_tanks and self._min_tanks > memberCounts.TANK) or (self._max_tanks and self._max_tanks < memberCounts.TANK) then
					tremove(results, i)
				elseif (self._min_healers and self._min_healers > memberCounts.HEALER) or (self._max_healers and self._max_healers < memberCounts.HEALER) then
					tremove(results, i)
				elseif (self._min_dps and self._min_dps > memberCounts.DAMAGER) or (self._max_dps and self._max_dps < memberCounts.DAMAGER) then
					tremove(results, i)
				elseif self._blacklistedPlayers[leaderName] then
					tremove(results, i)
				end
			end
		end
	end

	self._latestResults = results
end

function Core:_onGetSearchEntryMenu(frame, resultId)
	if not self._contextMenuModified then
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
	end

	if self._contextMenuBlacklist then
		local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId)
		self._contextMenuBlacklist.arg1 = resultId
		self._contextMenuBlacklist.arg2 = searchResultInfo.leaderName
	end
end

function Core:_onBlackListPlayer(_, id, name)
	GroupFinderImprovements.Db:SetProfileData(name, true, "blacklist")


	local dataProvider = CreateDataProvider();
	local results = self._latestResults;
	for index = 1, #results do
		dataProvider:Insert({resultID=results[index]});
	end
	LFGBrowseFrame.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition);
end