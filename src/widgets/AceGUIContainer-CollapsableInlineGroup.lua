--[[-----------------------------------------------------------------------------
CollapsableInlineGroup Container
Simple container widget that creates a visible "box" with an optional title that can be collapsed and expaneded.
-------------------------------------------------------------------------------]]
local Type, Version = "CollapsableInlineGroup", 1

local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs = pairs
local stringformat = string.format

-- WoW APIs
local CreateFrame = CreateFrame
local UIParent = UIParent
local BackdropTemplateMixin = BackdropTemplateMixin

local methods = {
	["OnAcquire"] = function(self)
		self:SetWidth(300)
		self:SetHeight(100)
		self:SetTitle("")
	end,

	["SetTitle"] = function(self, title)
		local text
		if self.border:IsShown() then
			text = stringformat("[-] %s", title)
		else
			text = stringformat("[+] %s", title)
		end
		self.titleText:SetText(text)
		self.title = title
	end,


	["LayoutFinished"] = function(self, width, height)
		if self.noAutoHeight then
			return
		end

		if self.border:IsShown() then
			self:SetHeight((height or 0) + self.titleFrame:GetHeight() + 20)
		else
			self:SetHeight(self.titleFrame:GetHeight())
		end
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		local contentwidth = width - 20

		if contentwidth < 0 then
			contentwidth = 0
		end

		if contentwidth ~= content.width then
			content:SetWidth(contentwidth)
			content.width = contentwidth
			self:Fire("OnWidthSet", width)
		end
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		local contentheight = height - 20
		if contentheight < 0 then
			contentheight = 0
		end

		if contentheight ~= content.height then
			content:SetHeight(contentheight)
			content.height = contentheight
		end
	end,

	["RegisterCallback"] = function(self, cb)
		self._cb = cb
	end,

	["Collapse"] = function(self)
		self.border:Hide()
		self:SetHeight(self.titleFrame:GetHeight())
		self:SetTitle(self.title)

		self:Fire("Collapse")
	end,

	["Expand"] = function(self)
		self.border:Show()
		self:SetTitle(self.title)
		self:Fire("Expand")
	end,

	["Toggle"] = function(self)
		local border = self.border

		local isShown = border:IsShown()
		if isShown then
			border:Hide()
			self:SetHeight(self.titleFrame:GetHeight())
		else
			border:Show()
		end

		AceGUI:ClearFocus()
		self:SetTitle(self.title)
		self:Fire(isShown and "Collapse" or "Expand")
	end,

	["IsExpanded"] = function(self)
		return self.border:IsShown()
	end,

	["SetTitleFont"] = function(self, font, size, flags)
		self.titleText:SetFont(font, size, flags)
		self.titleFrame:SetHeight(self.titleText:GetStringHeight())
	end
}

local PaneBackdrop  = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")

	local titleFrame = CreateFrame("Frame", nil, frame)
	titleFrame:SetPoint("TOPLEFT", 0, 0)
	titleFrame:SetPoint("TOPRIGHT", 0, 0)

	local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titleText:SetPoint("TOPLEFT", 4, -4)
	titleText:SetPoint("BOTTOMRIGHT", -4, 4)
	titleText:SetJustifyH("LEFT")
	titleText:SetHeight(18)
	titleFrame:SetHeight(titleText:GetStringHeight() + 8)

	local border = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	border:SetPoint("TOPLEFT", titleFrame, "BOTTOMLEFT", 0, 0)
	border:SetPoint("BOTTOMRIGHT", 0, 0)
	border:SetBackdrop(PaneBackdrop)
	border:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	border:SetBackdropBorderColor(0.4, 0.4, 0.4)

	--Container Support
	local content = CreateFrame("Frame", nil, border)
	content:SetPoint("TOPLEFT", 10, -10)
	content:SetPoint("BOTTOMRIGHT", -10, 10)

	local widget = {
		frame     = frame,
		border    = border,
		content   = content,
		titleFrame = titleFrame,
		titleText = titleText,
		type      = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	titleFrame:SetScript("OnMouseDown", function(frame, button)
		widget:Toggle(button)
	end)

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)