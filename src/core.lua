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
local wipe = wipe

-- WoW API

local Core = LibStub("AceAddon-3.0"):NewAddon("GroupFinderImprovementsCore", "AceEvent-3.0", "AceTimer-3.0")
GroupFinderImprovements.Core = Core

function Core:OnInitialize()
	self._autoRefreshRunning = false
	self._autoRefreshInterval = 2
	self._autoRefreshTimer = nil
	self._autoRefreshButton = nil
end

function Core:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
	self:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED", "OnLFGListSearchResultsReceived")
end

function Core:OnPlayerEnteringWorld()
	self:CreateRefreshButton()

	for name, module in self:IterateModules() do
		if module.OnPlayerEnteringWorld then
			module:OnPlayerEnteringWorld()
		end
	end
end

local function OnRefreshButtonClick(frame, ...)
	local self = Core

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

function Core:CreateRefreshButton()
	local searchButton = LFGBrowseFrameRefreshButton

	local button = CreateFrame("Button", nil, LFGBrowseFrame)
	button:SetPoint("RIGHT", searchButton, "LEFT", 0, 0)
	button:SetWidth(searchButton:GetWidth())
	button:SetHeight(searchButton:GetHeight())
	
	button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
	button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
	button:SetDisabledTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")

	button:SetScript("OnClick", OnRefreshButtonClick)
	button:Disable()

	self._autoRefreshButton = button
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	GroupFinderImprovements[name] = mod
end

function Core:OnConfigChange(...)
end



function Core:OnLFGListSearchResultsReceived()
	if self._autoRefreshTimer then
		self:CancelTimer(self._autoRefreshTimer)
		self._autoRefreshTimer = nil
	end

	if self._autoRefreshRunning then
		self:ScheduleTimer(self.OnTimer, self._autoRefreshInterval, self)
	end

	if not self._autoRefreshButton:IsEnabled() then
		self._autoRefreshButton:Enable()
	end
end

function Core:OnTimer()
	if self._autoRefreshRunning then
		LFGBrowseFrameRefreshButton:Click()
		self._autoRefreshTimer = nil
	end
end