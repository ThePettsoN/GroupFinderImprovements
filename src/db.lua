local _, GroupFinderImprovements = ...

local Db = {}
GroupFinderImprovements.Core:RegisterModule("Db", Db, "AceEvent-3.0")

local DEFAULTS = {
    profile = {
		blacklist = {},
		refresh_interval = 2,
    },
    char = {
		filters = {
			members = {
				min = nil,
				max = nil,
			},
			tanks = {
				min = nil,
				max = nil,
			},
			healers = {
				min = nil,
				max = nil,
			},
			dps = {
				min = nil,
				max = nil,
			}
		},
	},
}

function Db:OnInitialize()
    self._db = LibStub("AceDB-3.0"):New("GroupFinderImprovementsDB", DEFAULTS)
	self._db.RegisterCallback(self, "OnProfileReset", "_onProfileChanged")
	self._db.RegisterCallback(self, "OnProfileChanged", "_onProfileChanged")
end

function Db:_onProfileChanged(...)
	self:SendMessage("ConfigChanged", ...)
end

function Db:SetCharacterData(key, value, ...)
	local data = self._db.char
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	data[key] = value
	self:_onProfileChanged("character", key, value, ...)
end

function Db:GetCharacterData(...)
	local data = self._db.char
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	return data
end

function Db:SetProfileData(key, value, ...)
	local data = self._db.profile
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	data[key] = value
	self:_onProfileChanged("profile", key, value, ...)
end

function Db:GetProfileData(...)
	local data = self._db.profile
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end

	return data
end