local TOCNAME, GroupFinderImprovements = ...

local Core = LibStub("AceAddon-3.0"):NewAddon("GroupFinderImprovementsCore")
GroupFinderImprovements.Core = Core

local DebugTools = LibStub:GetLibrary("ThePettsonDebugTools-1.0", true)
local Debug = DebugTools:New(GroupFinderImprovements, TOCNAME)
GroupFinderImprovements.Debug = Debug
GroupFinderImprovements:SetDebug(false)

local Const = {
	RolesLookup = {
		Tank = "TANK",
		Healer = "HEALER",
		Damager = "DAMAGER",
	},
	Roles = {
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
		},
	},
}
GroupFinderImprovements.Const = Const

function Core:OnInitialize()
	GroupFinderImprovements.Const.ElvUI = _G.ElvUI ~= nil
end

function Core:OnEnable()
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	GroupFinderImprovements[name] = mod
end
