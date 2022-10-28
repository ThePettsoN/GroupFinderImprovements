local TOCNAME, GroupFinderImprovements = ...

local Core = LibStub("AceAddon-3.0"):NewAddon(TOCNAME)

local DebugTools = LibStub:GetLibrary("ThePettsonDebugTools-1.0", true)
local Debug = DebugTools:New()

GroupFinderImprovements.Core = Core

function Core:OnInitialize()
	Debug:Mixin(self, TOCNAME, true)

	self:Debug("OnInitialize")
end

function Core:OnEnable()
	self:Debug("OnEnable")
end

function Core:RegisterModule(name, module, ...)
	local mod = self:NewModule(name, module, ...)
	GroupFinderImprovements[name] = mod

	Debug:Mixin(mod, name, true)
end
