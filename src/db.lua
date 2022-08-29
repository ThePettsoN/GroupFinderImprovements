local _, GroupFinderImprovements = ...

local Db = {}
GroupFinderImprovements.Core:RegisterModule("Db", Db, "AceEvent-3.0")

local DEFAULTS = {
    profile = {
    },
    char = {
	},
}

function Db:OnInitialize()
    self._db = LibStub("AceDB-3.0"):New("GroupFinderImprovementsDB", DEFAULTS)
	self._db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self._db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
end

function Db:OnProfileChanged()
	self:SendMessage("ConfigChange")
end

function Db:SetCharacterData(key, value, ...)
	local data = self._db.char
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end
	data[key] = value
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
end

function Db:GetProfileData(...)
	local data = self._db.profile
	for i = 1, select("#", ...) do
		data = data[select(i, ...)]
	end

	return data
end