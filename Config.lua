-- Config.lua -- the in-game options panel.
--
-- Registered as a canvas category, so it appears under Options -> AddOns
-- alongside every other addon. A canvas rather than the structured settings
-- API, because a colour swatch and a "drag the frame" button do not exist as
-- built-in setting types.
--
-- Every widget writes straight into the saved variables and then calls
-- ns.ApplyDisplay(), so there is no separate apply step and no way for the
-- panel and the frame to drift apart.

local ADDON, ns = ...
local L = ns.L

local panel = CreateFrame("Frame", "CCAlarmOptionsPanel")
panel.name = "CCAlarm"
ns.panel = panel

local db                    -- filled on the first OnShow, after ADDON_LOADED
local widgets = {}          -- everything that has to be refreshed together

-------------------------------------------------------------------------------
-- Small widget helpers
--
-- Templates used here are the ones actually in use across current addons:
-- UICheckButtonTemplate, OptionsSliderTemplate, WowStyle1DropdownTemplate and
-- UIPanelButtonTemplate.
-------------------------------------------------------------------------------

local function heading(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function checkbox(parent, text, x, y, get, set)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box.text:SetText(text)
    box:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.ApplyDisplay()
    end)
    widgets[#widgets + 1] = function() box:SetChecked(get()) end
    return box
end

local sliderCount = 0
local function slider(parent, text, x, y, low, high, step, get, set)
    sliderCount = sliderCount + 1
    -- OptionsSliderTemplate needs a global name: it anchors its own Low/High
    -- labels via $parent.
    local bar = CreateFrame("Slider", "CCAlarmSlider" .. sliderCount, parent,
                            "OptionsSliderTemplate")
    bar:SetPoint("TOPLEFT", x + 6, y)
    bar:SetWidth(200)
    bar:SetMinMaxValues(low, high)
    bar:SetValueStep(step)
    bar:SetObeyStepOnDrag(true)
    _G[bar:GetName() .. "Low"]:SetText(low)
    _G[bar:GetName() .. "High"]:SetText(high)
    bar:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        _G[self:GetName() .. "Text"]:SetText(text .. ": " .. value)
        set(value)
        ns.ApplyDisplay()
    end)
    widgets[#widgets + 1] = function()
        local value = get()
        bar:SetValue(value)
        _G[bar:GetName() .. "Text"]:SetText(text .. ": " .. value)
    end
    return bar
end

local function dropdown(parent, x, y, width, list, get, set)
    local menu = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    menu:SetPoint("TOPLEFT", x, y)
    menu:SetWidth(width)
    menu:SetupMenu(function(_, root)
        for _, entry in ipairs(list()) do
            root:CreateRadio(entry,
                function() return get() == entry end,
                function() set(entry); ns.ApplyDisplay(); menu:GenerateMenu() end)
        end
    end)
    widgets[#widgets + 1] = function() menu:SetDefaultText(get() or "") end
    return menu
end

local function button(parent, text, x, y, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetSize(width, 22)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function colourSwatch(parent, x, y, get, set)
    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetPoint("TOPLEFT", x, y)
    swatch:SetSize(20, 20)
    swatch.tex = swatch:CreateTexture(nil, "ARTWORK")
    swatch.tex:SetAllPoints()
    swatch:SetScript("OnClick", function()
        local c = get()
        local function apply(restore)
            local r, g, b
            if restore then
                r, g, b = restore.r or restore[1], restore.g or restore[2], restore.b or restore[3]
            else
                r, g, b = ColorPickerFrame:GetColorRGB()
            end
            set(r, g, b)
            swatch.tex:SetColorTexture(r, g, b)
            ns.ApplyDisplay()
        end
        -- Modern API where present, legacy fields otherwise.
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = c.r, g = c.g, b = c.b,
                swatchFunc = apply, cancelFunc = apply, hasOpacity = false,
            })
        else
            ColorPickerFrame.func = apply
            ColorPickerFrame.cancelFunc = apply
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Show()
        end
    end)
    widgets[#widgets + 1] = function()
        local c = get()
        swatch.tex:SetColorTexture(c.r or 1, c.g or 0.1, c.b or 0.1)
    end
    return swatch
end

-------------------------------------------------------------------------------
-- Panel contents
-------------------------------------------------------------------------------

local built = false
local function build()
    if built then return end
    built = true
    db = ns.GetDB()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["OPT_TITLE"])

    local y = -56

    -- General ----------------------------------------------------------------
    heading(panel, L["OPT_GENERAL"], 16, y); y = y - 24
    checkbox(panel, L["OPT_ENABLED"], 16, y,
             function() return db.enabled end,
             function(v) db.enabled = v end); y = y - 28

    heading(panel, L["OPT_ROLES"], 16, y); y = y - 24
    checkbox(panel, L["OPT_ROLE_HEALER"], 16, y,
             function() return db.roles.HEALER end,
             function(v) db.roles.HEALER = v end)
    checkbox(panel, L["OPT_ROLE_TANK"], 176, y,
             function() return db.roles.TANK end,
             function(v) db.roles.TANK = v end); y = y - 28

    heading(panel, L["OPT_ZONES"], 16, y); y = y - 24
    local zones = {
        { L["OPT_ZONE_DUNGEON"], "inDungeon" }, { L["OPT_ZONE_ARENA"], "inArena" },
        { L["OPT_ZONE_WORLD"], "inWorld" }, { L["OPT_ZONE_RAID"], "inRaid" },
        { L["OPT_ZONE_BG"], "inBattleground" },
    }
    for i, zone in ipairs(zones) do
        local column = ((i - 1) % 3) * 160
        checkbox(panel, zone[1], 16 + column, y - math.floor((i - 1) / 3) * 26,
                 function() return db[zone[2]] end,
                 function(v) db[zone[2]] = v end)
    end
    y = y - 26 * math.ceil(#zones / 3) - 12

    -- Warning text -----------------------------------------------------------
    heading(panel, L["OPT_TEXT"], 16, y); y = y - 24
    checkbox(panel, L["OPT_SHOW_TEXT"], 16, y,
             function() return db.warningText end,
             function(v) db.warningText = v end); y = y - 32

    local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 20, y); fontLabel:SetText(L["OPT_FONT"]); y = y - 20
    dropdown(panel, 16, y, 220,
             function() return (ns.FontList()) end,
             function() return db.fontName end,
             function(v) db.fontName = v end)

    local outlineLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    outlineLabel:SetPoint("TOPLEFT", 256, y + 20); outlineLabel:SetText(L["OPT_FONT_OUTLINE"])
    local OUTLINES = { NONE = L["OPT_OUTLINE_NONE"], OUTLINE = L["OPT_OUTLINE_THIN"],
                       THICKOUTLINE = L["OPT_OUTLINE_THICK"] }
    local ORDER = { "NONE", "OUTLINE", "THICKOUTLINE" }
    dropdown(panel, 252, y, 140,
             function()
                 local names = {}
                 for _, key in ipairs(ORDER) do names[#names + 1] = OUTLINES[key] end
                 return names
             end,
             function() return OUTLINES[db.fontOutline or "OUTLINE"] end,
             function(v)
                 for key, label in pairs(OUTLINES) do
                     if label == v then db.fontOutline = key end
                 end
             end)
    y = y - 34

    slider(panel, L["OPT_FONT_SIZE"], 16, y - 8, 10, 72, 1,
           function() return db.textSize end,
           function(v) db.textSize = v end)

    local colourLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colourLabel:SetPoint("TOPLEFT", 282, y - 12); colourLabel:SetText(L["OPT_FONT_COLOR"])
    colourSwatch(panel, 256, y - 10,
                 function() return db.fontColor end,
                 function(r, g, b) db.fontColor = { r = r, g = g, b = b } end)
    y = y - 52

    -- Icons ------------------------------------------------------------------
    heading(panel, L["OPT_ICONS"], 16, y); y = y - 24
    checkbox(panel, L["OPT_SHOW_ICONS"], 16, y,
             function() return db.icons end,
             function(v) db.icons = v end); y = y - 34
    slider(panel, L["OPT_ICON_SIZE"], 16, y, 16, 96, 2,
           function() return db.iconSize end,
           function(v) db.iconSize = v end)
    slider(panel, L["OPT_MAX_ICONS"], 256, y, 1, 10, 1,
           function() return db.maxIcons end,
           function(v) db.maxIcons = v end)
    y = y - 46

    -- Sound ------------------------------------------------------------------
    heading(panel, L["OPT_SOUND"], 16, y); y = y - 24
    checkbox(panel, L["OPT_PLAY_SOUND"], 16, y,
             function() return db.sound end,
             function(v) db.sound = v end); y = y - 26
    local soundLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    soundLabel:SetPoint("TOPLEFT", 20, y); soundLabel:SetText(L["OPT_SOUND_CHOICE"]); y = y - 20
    dropdown(panel, 16, y, 220, ns.SoundList,
             function() return db.soundName end,
             function(v) db.soundName = v end)
    button(panel, L["OPT_SOUND_TEST"], 246, y, 90, function() ns.PlayAlarm() end)
    y = y - 40

    -- Position ---------------------------------------------------------------
    heading(panel, L["OPT_POSITION"], 16, y); y = y - 26
    local lockButton
    lockButton = button(panel, L["OPT_UNLOCK"], 16, y, 150, function()
        ns.SetUnlocked(db.locked)
        lockButton:SetText(db.locked and L["OPT_UNLOCK"] or L["OPT_LOCK"])
    end)
    button(panel, L["OPT_RESET_POS"], 176, y, 150, function() ns.ResetPosition() end)
    button(panel, L["OPT_TEST"], 336, y, 110, function() ns.Test() end)
    y = y - 26

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 18, y)
    hint:SetText(L["OPT_UNLOCKED_HINT"])
    y = y - 22

    if not ns.LSM() then
        local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", 18, y)
        note:SetText(L["OPT_NO_LSM"])
    end
end

local function refresh()
    for _, update in ipairs(widgets) do update() end
end

panel:SetScript("OnShow", function()
    build()
    refresh()
end)

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------

function ns.RegisterOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        ns.optionsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)     -- pre-Dragonflight clients
    end
end

function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and ns.optionsCategory then
        Settings.OpenToCategory(ns.optionsCategory.ID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)  -- known Blizzard quirk
    end
end
