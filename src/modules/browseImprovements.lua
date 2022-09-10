local _, GroupFinderImprovements = ...

local BrowseImprovements = {}
GroupFinderImprovements.Core:RegisterModule("BrowseImprovements", BrowseImprovements, "AceEvent-3.0", "AceTimer-3.0")
local Const = GroupFinderImprovements.Const
local Debug = GroupFinderImprovements.Debug

-- Lua API
local tremove = tremove
local hooksecurefunc = hooksecurefunc

-- WoW API
local CreateFrame = CreateFrame
local CreateDataProvider = CreateDataProvider
local C_LFGList = C_LFGList

function BrowseImprovements:OnInitialize()
    self._autoRefreshRunning = false
	self._autoRefreshInterval = 2
	self._autoRefreshTimer = nil
    self._autoRefreshButton = nil
    self._isRefreshing = false

    self._contextMenuBlacklist = nil
	self._contextMenuModified = false

	self._blacklistedPlayers = {}

	self._latestResults = {}
end

function BrowseImprovements:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", "OnLFGListSearchResultsReceived")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", "OnLFGListSearchResultReceived")

    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
	self:OnConfigChanged()
end

function BrowseImprovements:CreateRefreshButton()
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

	button:SetScript("OnClick", function(frame, ...) self:OnRefreshButtonClick(frame, ...) end)
	button:Disable()
	button:GetDisabledTexture():SetDesaturated(true)

	self._autoRefreshButton = button
end

function BrowseImprovements:UpdateStaleResults()
	if LFGBrowseFrame then
		local dataProvider = CreateDataProvider()
		local results = self._latestResults;
		for index = 1, #results do
			dataProvider:Insert({resultID=results[index]})
		end

		LFGBrowseFrame.ScrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
	end
end

local numTanks, numHealers, numDPS = 0, 0, 0
function BrowseImprovements:ShouldFilter(id, searchInfo)
	local leaderName = searchInfo.leaderName
	local numMembers = searchInfo.numMembers

	if not leaderName then
		return false
	end

	if searchInfo.isDelisted then
		GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: IsDelisted | Id: %q | LeaderName %q", id, leaderName)
		return true
	elseif self._min_members > numMembers or self._max_members < numMembers then
		GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: Members out of bounds (%d) | Id: %q | LeaderName %q", numMembers, id, leaderName)
		return true
	else
		numTanks, numHealers, numDPS = 0, 0, 0
		for i = 1, numMembers do
			local _, role, classFile, _, level = C_LFGList.GetSearchResultMemberInfo(id, i)
			if role == Const.RolesLookup.Tank and Const.Roles[Const.RolesLookup.Tank][classFile] then
				numTanks = numTanks + 1
            elseif role == Const.RolesLookup.Healer and Const.Roles[Const.RolesLookup.Healer][classFile] then
				numHealers = numHealers + 1
			else
				numDPS = numDPS + 1
			end
		end

		if self._min_tanks > numTanks or self._max_tanks < numTanks then
			GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: Tanks out of bounds (%d) | Id: %q | LeaderName %q", numTanks, id, leaderName)
			return true
		elseif self._min_healers > numHealers or self._max_healers < numHealers then
			GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: Healers out of bounds (%d) | Id: %q | LeaderName %q", numHealers, id, leaderName)
			return true
		elseif self._min_dps > numDPS or self._max_dps < numDPS then
			GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: DPS out of bounds (%d) | Id: %q | LeaderName %q", numDPS, id, leaderName)
			return true
		elseif self._blacklistedPlayers[leaderName] then
			GroupFinderImprovements:dprint(Debug.Severity.INFO, "Filter entry. Reason: Leader blacklisted | Id: %q | LeaderName %q", id, leaderName)
			return true
		end
	end
	
	return false
end

function BrowseImprovements:OnPlayerEnteringWorld()
    self:CreateRefreshButton()

    hooksecurefunc("LFGBrowseUtil_SortSearchResults", function(results) self:OnSortSearchResults(results) end)
	hooksecurefunc(LFGBrowseFrame, "GetSearchEntryMenu", function(frame, resultID)
		self:OnGetSearchEntryMenu(frame, resultID)
	end)
end

function BrowseImprovements:OnLFGListSearchResultsReceived()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnLFGListSearchResultsReceived: Addon Running: %q | Refresh Interval: %q | Timer Running: %q", tostring(self._autoRefreshRunning), tostring(self._autoRefreshInterval), tostring(self._autoRefreshTimer ~= nil))
	if self._autoRefreshTimer then
		self:CancelTimer(self._autoRefreshTimer)
		self._autoRefreshTimer = nil
	end

	if self._autoRefreshRunning then
		self._autoRefreshTimer = self:ScheduleTimer(self.OnTimer, self._autoRefreshInterval, self)
	end

	if not self._autoRefreshButton:IsEnabled() then
		self._autoRefreshButton:Enable()
	end
end

function BrowseImprovements:OnLFGListSearchResultReceived(event, resultId)
    if #self._latestResults == 0 then
        print("Return early")
        return
    end

	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnLFGListSearchResultReceived: %q", resultId)
	local searchInfo = C_LFGList.GetSearchResultInfo(resultId)
	if searchInfo and self:ShouldFilter(resultId, searchInfo) then
		for i = 1, #self._latestResults do
			if self._latestResults[i] == resultId then
				GroupFinderImprovements:dprint(Debug.Severity.INFO, "New filtered entry removed")
				tremove(self._latestResults, i)
				self:UpdateStaleResults()
				break
			end
		end
	end
end

function BrowseImprovements:OnConfigChanged(event, category, key, value, ...)
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

	self:OnSortSearchResults(self._latestResults)
end

function BrowseImprovements:OnBlackListPlayer(_, id, name)
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "Blacklist Player: Name: %q | id: %q", name, id)
	GroupFinderImprovements.Db:SetProfileData(name, true, "blacklist")
	self:UpdateStaleResults()
end

function BrowseImprovements:OnRefreshButtonClick(frame, ...)
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
		self:OnTimer()
	end
end

function BrowseImprovements:OnTimer()
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnTimer: Addon Running: %q", tostring(self._autoRefreshRunning))
	if self._autoRefreshRunning then
		LFGBrowseFrameRefreshButton:Click()
		self._autoRefreshTimer = nil
	end
end

function BrowseImprovements:OnSortSearchResults(results)
	GroupFinderImprovements:dprint(Debug.Severity.INFO, "OnSortSearchResults: Num Results: %d", #results)
	local getSearchResultInfo = C_LFGList.GetSearchResultInfo
	for i = #results, 1, -1 do
		local id = results[i]
		local searchInfo = getSearchResultInfo(id)
		if self:ShouldFilter(id, searchInfo) then
			tremove(results, i)
		end
	end

	self._latestResults = results
	self:UpdateStaleResults()
end

function BrowseImprovements:OnGetSearchEntryMenu(frame, resultId)
	if not self._contextMenuModified then
		GroupFinderImprovements:dprint(Debug.Severity.INFO, "Populate ContextMenu")
		self._contextMenuModified = true

		local menu = LFGBrowseFrame:GetSearchEntryMenu(resultId)
		self._contextMenuBlacklist = {
			text = "Blacklist Leader",
			notCheckable = true,
			arg1 = nil,
			arg2 = nil,
			func = function(_, id, name)
				self:OnBlackListPlayer(_, id, name)
			end
		}
		tinsert(menu, #menu, self._contextMenuBlacklist)

		if GroupFinderImprovements:DebugEnabled() then
			self._debugContext = {
				text = "Debug Entry",
				notCheckable = true,
				arg1 = nil,
				arg2 = nil,
				func = function(_, id, name)
					local searchInfo = C_LFGList.GetSearchResultInfo(id)
					local memberCounts = C_LFGList.GetSearchResultMemberCounts(id)
					GroupFinderImprovements:tDump(searchInfo)
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

	if GroupFinderImprovements:DebugEnabled() then
		if self._debugContext then
			local searchResultInfo = C_LFGList.GetSearchResultInfo(resultId)
			self._debugContext.arg1 = resultId
			self._debugContext.arg2 = searchResultInfo.leaderName
		end
	end
end