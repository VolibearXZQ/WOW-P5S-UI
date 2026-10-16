local _, addon = ...

local PanelTheme = {}
addon.PanelTheme = PanelTheme

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PANEL_BACKGROUND_TEXTURE = "Interface\\DialogFrame\\UI-DialogBox-Background"

local COLORS = {
    panelBackground = { 0.035, 0.040, 0.060, 0.96 },
    panelBorder = { 0.24, 0.28, 0.36, 0.95 },

    headerBackground = { 0.055, 0.060, 0.085, 0.98 },
    contentShade = { 0.015, 0.018, 0.030, 0.34 },

    accent = { 0.82, 0.07, 0.05, 1.00 },
    accentBright = { 1.00, 0.25, 0.20, 1.00 },
    accentSoft = { 0.90, 0.08, 0.06, 0.15 },

    controlBackground = { 0.050, 0.058, 0.080, 0.94 },
    controlBorder = { 0.28, 0.32, 0.40, 0.90 },
    controlHover = { 0.095, 0.105, 0.140, 0.98 },
    controlPressed = { 0.030, 0.035, 0.055, 0.98 },
    controlDisabled = { 0.035, 0.038, 0.050, 0.78 },

    text = { 0.94, 0.95, 0.98, 1.00 },
    textDim = { 0.60, 0.62, 0.68, 1.00 },
}

PanelTheme.COLORS = COLORS

local PANEL_BACKDROP = {
    bgFile = PANEL_BACKGROUND_TEXTURE,
    edgeFile = WHITE_TEXTURE,
    tile = true,
    tileSize = 32,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local CONTROL_BACKDROP = {
    bgFile = WHITE_TEXTURE,
    edgeFile = WHITE_TEXTURE,
    edgeSize = 1,
}

local function SetTextureColor(texture, color, alpha)
    if not texture then return end
    texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4])
end

local function TintTexture(texture, color, alpha)
    if not texture then return end
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    texture:SetVertexColor(color[1], color[2], color[3], alpha or color[4])
end

local function SetFontColor(fontString, color)
    if not fontString then return end
    fontString:SetTextColor(color[1], color[2], color[3], color[4])
end

local function EnsureBackdrop(frame)
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
    return frame.SetBackdrop ~= nil
end

local function GetNamedRegion(control, key)
    if control[key] then return control[key] end
    local name = control.GetName and control:GetName()
    if name then return _G[name .. key] end
end

local function HideNamedRegions(control, keys)
    for _, key in ipairs(keys) do
        local region = GetNamedRegion(control, key)
        if region then
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function HideNineSlice(control)
    if control.NineSlice then
        control.NineSlice:Hide()
    end
end

local function GetControlText(control)
    if control.Text then return control.Text end
    local name = control.GetName and control:GetName()
    if name then return _G[name .. "Text"] end
end

function PanelTheme:ApplyOptionsPanel(frame)
    if not frame or frame._p5sPanelThemeStyled then return end
    frame._p5sPanelThemeStyled = true

    if EnsureBackdrop(frame) then
        frame:SetBackdrop(PANEL_BACKDROP)
        frame:SetBackdropColor(
            COLORS.panelBackground[1],
            COLORS.panelBackground[2],
            COLORS.panelBackground[3],
            COLORS.panelBackground[4]
        )
        frame:SetBackdropBorderColor(
            COLORS.panelBorder[1],
            COLORS.panelBorder[2],
            COLORS.panelBorder[3],
            COLORS.panelBorder[4]
        )
    end

    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:HookScript("OnShow", function(panel)
        panel:Raise()
    end)

    local contentShade = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    contentShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -50)
    contentShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    SetTextureColor(contentShade, COLORS.contentShade)
    frame.ContentShade = contentShade

    local headerBackground = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    headerBackground:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    headerBackground:SetHeight(38)
    SetTextureColor(headerBackground, COLORS.headerBackground)
    frame.TitleBg = headerBackground

    local headerDivider = frame:CreateTexture(nil, "BORDER", nil, 2)
    headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -39)
    headerDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -39)
    headerDivider:SetHeight(1)
    SetTextureColor(headerDivider, COLORS.accent, 0.68)
    frame.HeaderDivider = headerDivider

    local headerLeftAccent = frame:CreateTexture(nil, "BORDER", nil, 3)
    headerLeftAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    headerLeftAccent:SetPoint("BOTTOMLEFT", headerDivider, "TOPLEFT", 0, 0)
    headerLeftAccent:SetWidth(3)
    SetTextureColor(headerLeftAccent, COLORS.accent, 0.90)

    local headerRightAccent = frame:CreateTexture(nil, "BORDER", nil, 3)
    headerRightAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    headerRightAccent:SetPoint("BOTTOMRIGHT", headerDivider, "TOPRIGHT", 0, 0)
    headerRightAccent:SetWidth(3)
    SetTextureColor(headerRightAccent, COLORS.accent, 0.90)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -7)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    self:StyleCloseButton(closeButton)
    frame.CloseButton = closeButton
end

function PanelTheme:StyleCloseButton(button)
    if not button or button._p5sPanelThemeStyled then return end
    button._p5sPanelThemeStyled = true

    TintTexture(button:GetNormalTexture(), COLORS.accentBright)
    TintTexture(button:GetPushedTexture(), COLORS.accent)
    TintTexture(button:GetHighlightTexture(), COLORS.accentBright)
    TintTexture(button:GetDisabledTexture(), COLORS.textDim)
end

function PanelTheme:StylePanelTitle(fontString)
    SetFontColor(fontString, COLORS.text)
end

function PanelTheme:StyleSection(section, title, accent)
    if EnsureBackdrop(section) then
        section:SetBackdrop(CONTROL_BACKDROP)
        section:SetBackdropColor(0.035, 0.040, 0.058, 0.72)
        section:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            0.72
        )
    end
    SetFontColor(title, COLORS.accentBright)
    SetTextureColor(accent, COLORS.accent)
end

function PanelTheme:StyleBodyText(fontString)
    SetFontColor(fontString, COLORS.text)
end

function PanelTheme:StyleMutedText(fontString)
    SetFontColor(fontString, COLORS.textDim)
end

local function UpdateButtonStyle(button)
    if not button:IsEnabled() then
        button:SetBackdropColor(
            COLORS.controlDisabled[1],
            COLORS.controlDisabled[2],
            COLORS.controlDisabled[3],
            COLORS.controlDisabled[4]
        )
        button:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            0.45
        )
        SetFontColor(button:GetFontString(), COLORS.textDim)
    elseif button._p5sThemePressed then
        button:SetBackdropColor(
            COLORS.controlPressed[1],
            COLORS.controlPressed[2],
            COLORS.controlPressed[3],
            COLORS.controlPressed[4]
        )
        button:SetBackdropBorderColor(
            COLORS.accent[1],
            COLORS.accent[2],
            COLORS.accent[3],
            COLORS.accent[4]
        )
        SetFontColor(button:GetFontString(), COLORS.text)
    elseif button:IsMouseOver() then
        button:SetBackdropColor(
            COLORS.controlHover[1],
            COLORS.controlHover[2],
            COLORS.controlHover[3],
            COLORS.controlHover[4]
        )
        button:SetBackdropBorderColor(
            COLORS.accentBright[1],
            COLORS.accentBright[2],
            COLORS.accentBright[3],
            COLORS.accentBright[4]
        )
        SetFontColor(button:GetFontString(), COLORS.text)
    else
        button:SetBackdropColor(
            COLORS.controlBackground[1],
            COLORS.controlBackground[2],
            COLORS.controlBackground[3],
            COLORS.controlBackground[4]
        )
        button:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            COLORS.controlBorder[4]
        )
        SetFontColor(button:GetFontString(), COLORS.text)
    end
end

function PanelTheme:StyleButton(button)
    if not button or button._p5sPanelThemeStyled then return end
    button._p5sPanelThemeStyled = true

    HideNineSlice(button)
    HideNamedRegions(button, { "Left", "Middle", "Right" })

    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local disabledTexture = button:GetDisabledTexture()
    if normalTexture then normalTexture:SetAlpha(0) end
    if pushedTexture then pushedTexture:SetAlpha(0) end
    if disabledTexture then disabledTexture:SetAlpha(0) end

    if EnsureBackdrop(button) then
        button:SetBackdrop(CONTROL_BACKDROP)
    end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    SetTextureColor(highlight, COLORS.accentSoft)
    button:SetHighlightTexture(highlight)

    button:HookScript("OnEnter", UpdateButtonStyle)
    button:HookScript("OnLeave", function(self)
        self._p5sThemePressed = false
        UpdateButtonStyle(self)
    end)
    button:HookScript("OnMouseDown", function(self)
        self._p5sThemePressed = true
        UpdateButtonStyle(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        self._p5sThemePressed = false
        UpdateButtonStyle(self)
    end)
    button:HookScript("OnShow", UpdateButtonStyle)
    UpdateButtonStyle(button)
end

local function UpdateCheckBoxStyle(checkButton)
    if not checkButton:IsEnabled() then
        checkButton:SetBackdropColor(
            COLORS.controlDisabled[1],
            COLORS.controlDisabled[2],
            COLORS.controlDisabled[3],
            COLORS.controlDisabled[4]
        )
        checkButton:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            0.45
        )
        SetFontColor(GetControlText(checkButton), COLORS.textDim)
    elseif checkButton:IsMouseOver() then
        checkButton:SetBackdropColor(
            COLORS.controlHover[1],
            COLORS.controlHover[2],
            COLORS.controlHover[3],
            COLORS.controlHover[4]
        )
        checkButton:SetBackdropBorderColor(
            COLORS.accentBright[1],
            COLORS.accentBright[2],
            COLORS.accentBright[3],
            COLORS.accentBright[4]
        )
        SetFontColor(GetControlText(checkButton), COLORS.text)
    else
        checkButton:SetBackdropColor(
            COLORS.controlBackground[1],
            COLORS.controlBackground[2],
            COLORS.controlBackground[3],
            COLORS.controlBackground[4]
        )
        checkButton:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            COLORS.controlBorder[4]
        )
        SetFontColor(GetControlText(checkButton), COLORS.text)
    end
end

function PanelTheme:StyleCheckBox(checkButton)
    if not checkButton or checkButton._p5sPanelThemeStyled then return end
    checkButton._p5sPanelThemeStyled = true

    checkButton:SetSize(22, 22)
    -- Set*Texture requires an asset; use the dedicated clearing APIs.
    checkButton:ClearNormalTexture()
    checkButton:ClearPushedTexture()
    checkButton:ClearDisabledTexture()

    if EnsureBackdrop(checkButton) then
        checkButton:SetBackdrop(CONTROL_BACKDROP)
    end

    checkButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local checkedTexture = checkButton:GetCheckedTexture()
    checkedTexture:ClearAllPoints()
    checkedTexture:SetPoint("CENTER")
    checkedTexture:SetSize(18, 18)
    TintTexture(checkedTexture, COLORS.accentBright)

    checkButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local disabledCheckedTexture = checkButton:GetDisabledCheckedTexture()
    if disabledCheckedTexture then
        disabledCheckedTexture:ClearAllPoints()
        disabledCheckedTexture:SetPoint("CENTER")
        disabledCheckedTexture:SetSize(18, 18)
        TintTexture(disabledCheckedTexture, COLORS.textDim)
    end

    local highlight = checkButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(checkButton)
    SetTextureColor(highlight, COLORS.accentSoft)
    checkButton:SetHighlightTexture(highlight)

    checkButton:HookScript("OnEnter", UpdateCheckBoxStyle)
    checkButton:HookScript("OnLeave", UpdateCheckBoxStyle)
    checkButton:HookScript("OnShow", UpdateCheckBoxStyle)
    UpdateCheckBoxStyle(checkButton)
end

function PanelTheme:StyleEditBox(editBox)
    if not editBox or editBox._p5sPanelThemeStyled then return end
    editBox._p5sPanelThemeStyled = true

    HideNineSlice(editBox)
    HideNamedRegions(editBox, {
        "Left", "Middle", "Mid", "Right",
        "LeftTexture", "MiddleTexture", "RightTexture",
    })

    if EnsureBackdrop(editBox) then
        editBox:SetBackdrop(CONTROL_BACKDROP)
        editBox:SetBackdropColor(
            COLORS.controlBackground[1],
            COLORS.controlBackground[2],
            COLORS.controlBackground[3],
            COLORS.controlBackground[4]
        )
        editBox:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            COLORS.controlBorder[4]
        )
    end

    editBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3], COLORS.text[4])
    editBox:SetTextInsets(7, 7, 0, 0)
    editBox:HookScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(
            COLORS.accentBright[1],
            COLORS.accentBright[2],
            COLORS.accentBright[3],
            COLORS.accentBright[4]
        )
    end)
    editBox:HookScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(
            COLORS.controlBorder[1],
            COLORS.controlBorder[2],
            COLORS.controlBorder[3],
            COLORS.controlBorder[4]
        )
    end)
end

function PanelTheme:StyleSlider(slider)
    if not slider or slider._p5sPanelThemeStyled then return end
    slider._p5sPanelThemeStyled = true

    HideNamedRegions(slider, { "Left", "Middle", "Mid", "Right" })

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 2, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", -2, 0)
    track:SetHeight(4)
    SetTextureColor(track, COLORS.controlBorder)
    slider._p5sThemeTrack = track

    local thumb = slider:GetThumbTexture()
    if thumb then
        TintTexture(thumb, COLORS.accentBright)
    end

    local name = slider:GetName()
    if name then
        SetFontColor(_G[name .. "Text"], COLORS.text)
        SetFontColor(_G[name .. "Low"], COLORS.textDim)
        SetFontColor(_G[name .. "High"], COLORS.textDim)
    end

    slider:HookScript("OnEnter", function(self)
        SetTextureColor(self._p5sThemeTrack, COLORS.accent, 0.72)
    end)
    slider:HookScript("OnLeave", function(self)
        SetTextureColor(self._p5sThemeTrack, COLORS.controlBorder)
    end)
end

local function SetDropDownBorder(dropdown, color)
    if not dropdown._p5sThemeBorders then return end
    for _, border in ipairs(dropdown._p5sThemeBorders) do
        SetTextureColor(border, color)
    end
end

function PanelTheme:StyleDropDown(dropdown)
    if not dropdown or dropdown._p5sPanelThemeStyled then return end
    dropdown._p5sPanelThemeStyled = true

    HideNamedRegions(dropdown, { "Left", "Middle", "Mid", "Right" })

    local background = dropdown:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 16, -5)
    background:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -16, 5)
    SetTextureColor(background, COLORS.controlBackground)
    dropdown._p5sThemeBackground = background

    local top = dropdown:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", background, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", background, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = dropdown:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = dropdown:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", background, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)

    local right = dropdown:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", background, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)

    dropdown._p5sThemeBorders = { top, bottom, left, right }
    SetDropDownBorder(dropdown, COLORS.controlBorder)

    local name = dropdown:GetName()
    local button = dropdown.Button or (name and _G[name .. "Button"])
    local text = dropdown.Text or (name and _G[name .. "Text"])
    SetFontColor(text, COLORS.text)

    if button then
        TintTexture(button:GetNormalTexture(), COLORS.accentBright)
        TintTexture(button:GetPushedTexture(), COLORS.accent)
        TintTexture(button:GetHighlightTexture(), COLORS.accentBright)
        button:HookScript("OnEnter", function()
            SetTextureColor(background, COLORS.controlHover)
            SetDropDownBorder(dropdown, COLORS.accentBright)
        end)
        button:HookScript("OnLeave", function()
            SetTextureColor(background, COLORS.controlBackground)
            SetDropDownBorder(dropdown, COLORS.controlBorder)
        end)
        button:HookScript("OnMouseDown", function()
            SetTextureColor(background, COLORS.controlPressed)
            SetDropDownBorder(dropdown, COLORS.accent)
        end)
        button:HookScript("OnMouseUp", function()
            SetTextureColor(background, COLORS.controlHover)
            SetDropDownBorder(dropdown, COLORS.accentBright)
        end)
    end
end
