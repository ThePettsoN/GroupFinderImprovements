local _, GroupFinderImprovements = ...
local AceGUI = LibStub("AceGUI-3.0")

local stringformat = string.format
local wipe = wipe

local Gui = {}
GroupFinderImprovements.Core:RegisterModule("Gui", Gui)

function Gui:OnInitialize()
    self._frame = nil
    self._config_button = nil
end

function Gui:OnEnable()
end

function Gui:OnConfigButtonClick(buttonFrame)
    local frame = self._frame
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

local function OnConfigButtonClick(frame)
    frame.gui:OnConfigButtonClick(frame)
end

function Gui:_createConfigButton()
    local children = { LFGParentFrame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child:GetObjectType() == "Button" then
            local tex = child:GetNormalTexture()
            if tex and tex:GetTextureFileID() == 130832 then
                local button = CreateFrame("Button", nil, LFGParentFrame, "UIPanelCloseButtonNoScripts")
                button:SetPoint("TOPRIGHT", child, "TOPLEFT", 8, 0)
                button:SetWidth(child:GetWidth() - 2)
                button:SetHeight(child:GetHeight() - 2)
                button:SetScript("OnClick", OnConfigButtonClick)

                self._config_button = button
                button.gui = self
            end
        end
    end
end

function Gui:OnFrameVisibilityToggle(show)
    if not self._config_button then
        self:_createConfigButton()
    end

    local button = self._config_button
    if show then
        button:SetNormalTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Up")
        button:SetDisabledTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Disabled")
        button:SetPushedTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Collapse-Down")
    else
        button:SetNormalTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Up")
        button:SetDisabledTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Disabled")
        button:SetPushedTexture("Interface/Addons/GroupFinderImprovements/Media/Images/ConfigButton/Expand-Down")
    end

end

local function OnFrameVisibilityToggle(widget, event)
    local self = widget.gui
    self:OnFrameVisibilityToggle(event == "OnShow")
end

function Gui:OnPlayerEnteringWorld()
    print("OnPlayerEnteringWorld")

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("GroupFinderImprovements")
    frame:EnableResize(false)

    frame.frame:SetParent("LFGBrowseFrame")
    frame.frame:SetMovable(false)
    frame.titletext:GetParent():EnableMouse(false)

    frame.statustext:GetParent():Hide()
    -- frame:Hide()

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", LFGBrowseFrame, "TOPRIGHT", UIPanelWindows.LFGParentFrame.xoffset, -UIPanelWindows.LFGParentFrame.yoffset)
    frame:SetHeight(UIPanelWindows.LFGParentFrame.height - UIPanelWindows.LFGParentFrame.yoffset + frame.titlebg:GetHeight() / 2)
    frame:SetWidth(UIPanelWindows.LFGParentFrame.width)
    self._frame = frame
    frame.gui = self

    -- LFGParentFrame:SetScript("OnShow", function(...) self:_onLFGParentFrameShow(...) end)
    frame:SetCallback("OnShow", OnFrameVisibilityToggle)
    frame:SetCallback("OnClose", OnFrameVisibilityToggle)
end