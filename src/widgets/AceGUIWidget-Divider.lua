--[[-----------------------------------------------------------------------------
Divider Widget
-------------------------------------------------------------------------------]]
local Type, Version = "Divider", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
	end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    local divider = frame:CreateTexture(nil, "BACKGROUND", frame)
	divider:SetHeight(8)
    divider:SetPoint("LEFT", frame, 2, 0)
	divider:SetPoint("RIGHT", frame, -2, 0)
	divider:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	divider:SetTexCoord(0.81, 0.94, 0.5, 1)

    local widget = {
        frame = frame,
        divider = divider,
        type = Type
	}

    for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)