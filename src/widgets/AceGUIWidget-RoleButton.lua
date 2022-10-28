--[[-----------------------------------------------------------------------------
RoleButton Widget
-------------------------------------------------------------------------------]]
local Type, Version = "RoleButton", 1
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

	-- ["OnRelease"] = nil,

	["SetDisabled"] = function(self, disabled)
		self.disabled = disabled
		if disabled then
			self.frame:Disable()
		else
			self.frame:Enable()
		end
	end,

    ["SetRole"] = function(self, role)
        self.button:GetNormalTexture():SetTexCoord(GetTexCoordsForRole(role))
        if role ~= "GUIDE" then
            if not self.background then
                local background = self.button:CreateTexture("Background", "BACKGROUND")
                background:SetTexture("Interface/LFGFrame/UI-LFG-ICONS-ROLEBACKGROUNDS")
                background:SetWidth(80)
                background:SetHeight(80)
                background:SetAlpha(0.6)
                background:ClearAllPoints()
                background:SetPoint("CENTER")

                self.background = background
            end
            self.background:SetTexCoord(GetBackgroundTexCoordsForRole(role))
        end
    end,

    ["GetValue"] = function(self)
		return self.checkButton:GetChecked()
	end,

    ["SetValue"] = function(self, value)
        self.checkButton:SetChecked(value)
    end
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetWidth(80)
    frame:SetHeight(80)
    frame:SetPoint("TOPLEFT")

    local button = CreateFrame("Button", nil, frame)
    button:SetNormalTexture("Interface/LFGFrame/UI-LFG-ICON-ROLES")

    button:SetWidth(48)
    button:SetHeight(48)
    button:SetPoint("CENTER")

    local checkBox = CreateFrame("CheckButton", nil, button)
    checkBox:SetWidth("24")
    checkBox:SetHeight("24")
    checkBox:SetPoint("BOTTOMLEFT", -5, -5)

    checkBox:SetNormalTexture("Interface/Buttons/UI-CheckBox-Up")
    checkBox:SetPushedTexture("Interface/Buttons/UI-CheckBox-Down")
    checkBox:SetHighlightTexture("Interface/Buttons/UI-CheckBox-Highlight")
    checkBox:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
    checkBox:SetDisabledTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")

    button:SetScript("OnEnter", function(...)
        if checkBox:IsEnabled() then
            checkBox:LockHighlight()
        end
    end)
    button:SetScript("OnLeave", function(...)
        checkBox:UnlockHighlight()
    end)
    button:SetScript("OnClick", function(...)
        checkBox:Click(...)
    end)

    checkBox:SetScript("OnClick", function(...) frame.obj:Fire("OnValueChanged", ...) end)

    button.CheckButton = checkBox

    local widget = {
        frame = frame,
        button = button,
        checkButton = checkBox,
        type = Type
	}

    for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)