local _, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

-- Lua API
local tremove = tremove

-- WoW API
local CreateFrame = CreateFrame

local Gui = {}
GroupFinderImprovements.Core:RegisterModule("Gui", Gui, "AceEvent-3.0")

function Gui:OnInitialize()
    self._frame = nil
    self._expandConfigButton = nil
end

function Gui:OnEnable()
    self:RegisterMessage("ConfigChanged", "OnConfigChanged")
end

function Gui:OnConfigChanged()
	local db = GroupFinderImprovements.Db
    self:_createBlacklistSection()
end

function Gui:OnConfigButtonClick(buttonFrame)
    local frame = self._frame
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function Gui:_createConfigButton()
    local lfgParentFrame = LFGParentFrame

    local children = { lfgParentFrame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child.GetPushedTexture and child:GetPushedTexture() and not child:GetName() then
            local expandButton = CreateFrame("Button", nil, lfgParentFrame, "UIPanelCloseButtonNoScripts")
            expandButton:SetPoint("RIGHT", child, "LEFT", 8, 0)
            expandButton:SetWidth(child:GetWidth() - 2)
            expandButton:SetHeight(child:GetHeight() - 2)
            expandButton:SetScript("OnClick", function(frame, ...) self:OnConfigButtonClick(frame) end)
            expandButton:Hide()

            local collapseButton = CreateFrame("Button", nil, lfgParentFrame, "UIPanelCloseButtonNoScripts")
            collapseButton:SetPoint("RIGHT", child, "LEFT", 8, 0)
            collapseButton:SetWidth(child:GetWidth() - 2)
            collapseButton:SetHeight(child:GetHeight() - 2)
            collapseButton:SetScript("OnClick", function(frame, ...) self:OnConfigButtonClick(frame) end)
            collapseButton:Hide()

            self._expandConfigButton = expandButton
            self._collapseConfigButton = collapseButton


            expandButton:SetNormalTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Up")
            expandButton:SetDisabledTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Disabled")
            expandButton:SetPushedTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Down")

            collapseButton:SetNormalTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Up")
            collapseButton:SetDisabledTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Disabled")
            collapseButton:SetPushedTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Down")

            break
        end
    end
end

function Gui:OnFrameVisibilityToggle(show)
    if not self._expandConfigButton then
        self:_createConfigButton()
    end

    if show then
        self._expandConfigButton:Hide()
        self._collapseConfigButton:Show()
    else
        self._expandConfigButton:Show()
        self._collapseConfigButton:Hide()
    end

end

function Gui:_createFrame()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("GroupFinderImprovements")
    frame:EnableResize(false)
    frame:SetLayout("List")

    frame.frame:SetParent("LFGBrowseFrame")
    frame.frame:SetMovable(false)
    frame.titletext:GetParent():EnableMouse(false)

    frame.statustext:GetParent():Hide()

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", LFGBrowseFrame, "TOPRIGHT", UIPanelWindows.LFGParentFrame.xoffset, -UIPanelWindows.LFGParentFrame.yoffset)
    frame:SetHeight(UIPanelWindows.LFGParentFrame.height - UIPanelWindows.LFGParentFrame.yoffset + frame.titlebg:GetHeight() / 2)
    frame:SetWidth(UIPanelWindows.LFGParentFrame.width)

    frame:SetCallback("OnShow", function(widget, event) self:OnFrameVisibilityToggle(true) end)
    frame:SetCallback("OnClose", function(widget, event) self:OnFrameVisibilityToggle(false) end)

    self._frame = frame
    frame.gui = self
end

function Gui:_createContainer()
    local container = AceGUI:Create("ScrollFrame")
	container:SetFullWidth(true)
	container:SetLayout("Flow")
    container.RemoveChild = function(self, widget)
		for i = 1, #self.children do
			local child = self.children[i]
			if child == widget then
				tremove(self.children, i)
				break
			end
		end
	end

    self._frame:AddChild(container)
    self._container = container
end

function Gui:_createRefreshSection()
    local refreshIntervalSlider = AceGUI:Create("Slider")
    refreshIntervalSlider:SetSliderValues(2, 60, 1)
    refreshIntervalSlider:SetRelativeWidth(1)
    refreshIntervalSlider:SetValue(GroupFinderImprovements.Db:GetProfileData("refresh_interval"))
    refreshIntervalSlider:SetLabel("Auto refresh interval")
    refreshIntervalSlider:SetHeight(refreshIntervalSlider.frame:GetHeight() + 32)
    refreshIntervalSlider:SetCallback("OnValueChanged", function(widget, event, value) self:_OnRefreshIntervalValueChanged(value) end)
    self._container:AddChild(refreshIntervalSlider)
end

function Gui:_createMembersSection()
    local groupLabel = AceGUI:Create("Label")
    groupLabel:SetRelativeWidth(0.5)
    groupLabel:SetText("Group Composition")
    groupLabel:SetFontObject(GameFontNormal)
    groupLabel:SetColor(1.0, 0.82, 0.0)
    
    local minLabel = AceGUI:Create("Label")
    minLabel:SetRelativeWidth(0.25)
    minLabel:SetText("Min")
    minLabel:SetFontObject(GameFontNormal)
    minLabel:SetColor(1.0, 0.82, 0.0)
    
    local maxLabel = AceGUI:Create("Label")
    maxLabel:SetRelativeWidth(0.25)
    maxLabel:SetText("Max")
    maxLabel:SetFontObject(GameFontNormal)
    maxLabel:SetColor(1.0, 0.82, 0.0)
    
    self._container:AddChild(groupLabel)
    self._container:AddChild(minLabel)
    self._container:AddChild(maxLabel)

    self:_createMembersGUI()
    self:_createTankGUI()
    self:_createHealersGUI()
    self:_createDpsGUI()
end

function Gui:_createBlacklistSection()
    if not self._blacklistedPlayers then
        self._blacklistedPlayers = {}
        local header = AceGUI:Create("Label")
        header:SetRelativeWidth(1)
        header:SetText("Blacklist")
        header:SetFontObject(GameFontNormal)
        header:SetColor(1.0, 0.82, 0.0)
        header.alignoffset = 32
        self._container:AddChild(header)
    end
    
    local blacklist = GroupFinderImprovements.Db:GetProfileData("blacklist")
    for name, _ in pairs(blacklist) do
        if not self._blacklistedPlayers[name] then
            local label = AceGUI:Create("Label")
            label:SetText(name)
            label:SetRelativeWidth(0.4)
            label:SetJustifyV("MIDDLE")

            local delButton = AceGUI:Create("Icon")
            delButton:SetImage("Interface/Common/VOICECHAT-MUTED")
            delButton:SetRelativeWidth(0.1)
            delButton:SetImageSize(16, 16)
            delButton:SetCallback("OnClick", function() self:_onRemoveBlacklist(name) end)
            self._container:AddChild(delButton)
            self._container:AddChild(label)

            self._blacklistedPlayers[name] = {
                label = label,
                button = delButton,
            }
        end
    end
end

function Gui:OnPlayerEnteringWorld()
    self:_createFrame()
    self:_createContainer()
    self:_createRefreshSection()
    self:_createMembersSection()
    self:_createBlacklistSection()
end

function Gui:_createGUI()
    local label = AceGUI:Create("Label")
    label:SetRelativeWidth(0.5)

    local minEditBox = AceGUI:Create("EditBox")
    minEditBox:SetRelativeWidth(0.25)
    minEditBox:SetMaxLetters(2)
    minEditBox.editbox:SetNumeric(1)

    local maxEditBox = AceGUI:Create("EditBox")
    maxEditBox:SetRelativeWidth(0.25)
    maxEditBox:SetMaxLetters(2)

    self._container:AddChild(label)
    self._container:AddChild(minEditBox)
    self._container:AddChild(maxEditBox)

    return label, minEditBox, maxEditBox
end

function Gui:_createMembersGUI()
    local db = GroupFinderImprovements.Db

    local label, minBox, maxBox = self:_createGUI()

    label:SetText("Members:")
    minBox:SetText(db:GetCharacterData("filters", "members", "min"))
    maxBox:SetText(db:GetCharacterData("filters", "members", "max"))

    minBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_minPlayersEditBox", "min", value, "filters", "members") end)
    maxBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_maxPlayersEditBox", "max", value, "filters", "members") end)

    self._minPlayersEditBox = minBox
    self._maxPlayersEditBox = maxBox
end

function Gui:_createTankGUI()
    local db = GroupFinderImprovements.Db

    local label, minBox, maxBox = self:_createGUI()

    label:SetText("Tanks:")
    minBox:SetText(db:GetCharacterData("filters", "tanks", "min"))
    maxBox:SetText(db:GetCharacterData("filters", "tanks", "max"))

    minBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_minTanksEditBox", "min", value, "filters", "tanks") end)
    maxBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_maxTanksEditBox", "max", value, "filters", "tanks") end)

    self._minTanksEditBox = minBox
    self._maxTanksEditBox = maxBox
end

function Gui:_createHealersGUI()
    local db = GroupFinderImprovements.Db

    local label, minBox, maxBox = self:_createGUI()

    label:SetText("Healers:")
    minBox:SetText(db:GetCharacterData("filters", "healers", "min"))
    maxBox:SetText(db:GetCharacterData("filters", "healers", "max"))

    minBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_minHealersEditBox", "min", value, "filters", "healers") end)
    maxBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_minHealersEditBox", "max", value, "filters", "healers") end)

    self._minHealersEditBox = minBox
    self._maxHealersEditBox = maxBox
end

function Gui:_createDpsGUI()
    local db = GroupFinderImprovements.Db

    local label, minBox, maxBox = self:_createGUI()
    label.alignoffset = 32
    minBox.alignoffset = 32
    maxBox.alignoffset = 32

    label:SetText("DPS:")
    minBox:SetText(db:GetCharacterData("filters", "dps", "min"))
    maxBox:SetText(db:GetCharacterData("filters", "dps", "max"))

    minBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_minDpsEditBox", "min", value, "filters", "dps") end)
    maxBox:SetCallback("OnEnterPressed", function(widget, event, value) self:_onEditBoxChanged("_maxDpsEditBox", "max", value, "filters", "dps") end)

    self._minDpsEditBox = minBox
    self._maxDpsEditBox = maxBox
end

function Gui:_onEditBoxChanged(variableName, key, value, ...)
    if not value or value == "" then
        GroupFinderImprovements.Db:SetCharacterData(key, nil, ...)
        self[variableName].editbox:ClearFocus()
    else
        local nValue = tonumber(value)
        GroupFinderImprovements.Db:SetCharacterData(key, nValue, ...)
    end
end

function Gui:_onRemoveBlacklist(name)
    GroupFinderImprovements.Db:SetProfileData(name, nil, "blacklist")

    local data = self._blacklistedPlayers[name]
    self._container:RemoveChild(data.label)
    self._container:RemoveChild(data.button)
    data.label:Release()
    data.button:Release()

    self._blacklistedPlayers[name] = nil

    self._container:DoLayout()
end

function Gui:_OnRefreshIntervalValueChanged(value)
    GroupFinderImprovements.Db:SetProfileData("refresh_interval", value)
end