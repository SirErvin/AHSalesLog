-- AHSalesLog.lua
-- Protokolliert Auktionshaus-Verkäufe
-- Interface: TBC Classic Anniversary

-- ============================================================
-- Konstanten & Hilfsvariablen
-- ============================================================

local ADDON_NAME = "AHSalesLog"
local ADDON_VERSION = "1.25.11"
local MAX_ENTRIES = 200
local MAIL_DELAY = 3600  -- 1 Stunde bis Mail ankommt
local UNDO_WINDOW_SECONDS = 10

local COL_TS     = 85
local COL_GOLD   = 34
local COL_SILVER = 28
local COL_COPPER = 28
local COL_TIMER  = 55

local ICON_GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12|t"
local ICON_SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:12|t"
local ICON_COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:12|t"

local FRAME_WIDTH  = 460
local FRAME_HEIGHT = 345
local MIN_WIDTH    = 400
local MIN_HEIGHT   = 250
local ROW_HEIGHT   = 18
local HEADER_H     = 16
local TAB_H        = 22
local PAD          = 8

-- Feste Spaltenbreiten + Gaps + Padding + Scrollbar
local COL_FIXED = COL_TS + 4 + COL_GOLD + 2 + COL_SILVER + 2 + COL_COPPER + 4 + COL_TIMER + 2 + PAD + (PAD + 20) + 4

local function GetItemColWidth()
    if AHSalesLogFrame then
        return math.max(AHSalesLogFrame:GetWidth() - COL_FIXED, 80)
    end
    return FRAME_WIDTH - COL_FIXED
end

local FONT_LIST = {
    { name = "Standard",  path = "GameFontNormalSmall" },
    { name = "Friz QT",   path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial",     path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus",  path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri",    path = "Fonts\\skurri.TTF" },
}

local THEME_LIST = {
    { key = "classic",   nameKey = "theme_classic" },
    { key = "dark",      nameKey = "theme_dark" },
    { key = "cleandark", nameKey = "theme_cleandark" },
    { key = "baganator", nameKey = "theme_modern" },
}

local LOCALES = {
    de = {
        option_language = "Sprache:",
        language_de = "Deutsch",
        language_en = "English",
        option_manual_delete = "Einzelne Eintraege per Rechtsklick loeschen",
        option_auto_clean_sold = "Verkauft-Tab am Postfach automatisch leeren",
        option_font = "Schriftart:",
        option_theme = "Design:",
        option_reload = "Neu laden",
        option_reload_hint = "Neu laden empfohlen nach Design-Wechsel.",
        option_mini_widget = "Mini-Widget anzeigen (letzter Verkauf)",
        option_transparency = "Transparenz:",
        option_size = "Groesse:",
        option_layout = "Layout:",
        option_layout_side = "Nebeneinander",
        option_layout_stack = "Uebereinander",
        option_widget_hint = "STRG + Ziehen zum Verschieben.",
        option_font_example = "%s - Beispieltext 123g",
        tab_sold = "Verkauft",
        tab_listed = "Eingestellt",
        tab_history = "Verlauf",
        tab_options = "Optionen",
        filter_today = "Heute",
        filter_week = "Woche",
        filter_month = "Monat",
        filter_year = "Jahr",
        filter_all = "Alles",
        header_time = "Zeit",
        header_item = "Item",
        header_mail = "Post",
        header_timer = "Timer",
        button_clear = "Leeren",
        clear_confirm_all = "Alle Eintraege im aktuellen Tab loeschen?",
        clear_confirm_ready_fmt = "%d abgeholte Eintraege entfernen?",
        popup_yes = "Ja",
        popup_no = "Nein",
        msg_no_ready_entries = "|cff00ff00AHSalesLog:|r Keine abgeholten Eintraege vorhanden.",
        tooltip_price = "Preis: %s",
        tooltip_delete_hint = "Rechtsklick: Eintrag loeschen",
        row_expired_suffix = "  |cffff4444(abgelaufen)|r",
        timer_ready = "Bereit",
        timer_expired = "Abgelaufen",
        count_entries_fmt = "%d Eintr.",
        sum_prefix = "Summe: ",
        sum_ready_fmt = "  |cff88ccff(Bereit: %s)|r",
        sum_all_ready = "  |cff88ccff(alles bereit)|r",
        minimap_title = "AH Log",
        minimap_toggle = "Klick: Fenster ein-/ausblenden",
        minimap_drag = "Drag: Position aendern",
        miniwidget_empty = "Keine Eintr.",
        miniwidget_title = "AH Sales Log",
        miniwidget_open = "Klick: Fenster oeffnen",
        miniwidget_move = "STRG+Ziehen: Verschieben",
        msg_test_entry = "|cff00ff00AHSalesLog:|r Testeintrag (Eingestellt -> Verkauft).",
        msg_test_listed = "|cff00ff00AHSalesLog:|r Testeintrag im 'Eingestellt'-Tab.",
        msg_debug_header = "|cff00ff00AHSalesLog Debug:|r",
        debug_yes = "ja",
        debug_no = "nein",
        debug_present = "vorhanden",
        debug_missing = "|cffff0000nicht gefunden|r",
        debug_empty = "leer",
        debug_detected = "erkannt",
        debug_not_present = "nicht vorhanden",
        debug_line_version = "  Version: %s",
        debug_line_ah_open = "  AH offen: %s",
        debug_line_get_sell_info = "  GetAuctionSellItemInfo: %s",
        debug_line_buyout_frame = "  BuyoutPrice Frame: %s",
        debug_line_sell_item = "  Sell-Slot Item: %s",
        debug_line_saved_buyout = "  Gespeicherter Buyout: %s",
        debug_line_auctionator = "  Auctionator: %s",
        debug_line_pending = "  Pending Auctions: %d",
        debug_line_sold = "  Sold Entries: %d",
        debug_line_slot_live = "  Slot LIVE: %s",
        debug_line_buyout_live = "  Buyout LIVE: %s",
        msg_auctionator_detected = "|cff00ff00AHSalesLog|r Auctionator erkannt.",
        msg_loaded_fmt = "|cff00ff00AHSalesLog|r v%s geladen.  /ahlog  /ahlogdebug",
        msg_auto_removed_fmt = "|cff00ff00AHSalesLog:|r %d abgeholte Eintraege automatisch entfernt.",
        undo_button_fmt = "Rueckgaengig (%d)",
        msg_undo_restored_fmt = "|cff00ff00AHSalesLog:|r %d Eintraege wiederhergestellt.",
        theme_classic = "Classic",
        theme_dark = "Dunkel",
        theme_cleandark = "Clean Dark",
        theme_modern = "Modern",
    },
    en = {
        option_language = "Language:",
        language_de = "Deutsch",
        language_en = "English",
        option_manual_delete = "Delete individual entries via right-click",
        option_auto_clean_sold = "Auto-clear Sold tab at mailbox",
        option_font = "Font:",
        option_theme = "Theme:",
        option_reload = "Reload",
        option_reload_hint = "Reload recommended after theme changes.",
        option_mini_widget = "Show mini widget (latest sale)",
        option_transparency = "Opacity:",
        option_size = "Size:",
        option_layout = "Layout:",
        option_layout_side = "Side by side",
        option_layout_stack = "Stacked",
        option_widget_hint = "CTRL + drag to move.",
        option_font_example = "%s - Example text 123g",
        tab_sold = "Sold",
        tab_listed = "Listed",
        tab_history = "History",
        tab_options = "Options",
        filter_today = "Today",
        filter_week = "Week",
        filter_month = "Month",
        filter_year = "Year",
        filter_all = "All",
        header_time = "Time",
        header_item = "Item",
        header_mail = "Mail",
        header_timer = "Timer",
        button_clear = "Clear",
        clear_confirm_all = "Delete all entries in the current tab?",
        clear_confirm_ready_fmt = "Remove %d collected entries?",
        popup_yes = "Yes",
        popup_no = "No",
        msg_no_ready_entries = "|cff00ff00AHSalesLog:|r No collected entries found.",
        tooltip_price = "Price: %s",
        tooltip_delete_hint = "Right-click: delete entry",
        row_expired_suffix = "  |cffff4444(expired)|r",
        timer_ready = "Ready",
        timer_expired = "Expired",
        count_entries_fmt = "%d entries",
        sum_prefix = "Total: ",
        sum_ready_fmt = "  |cff88ccff(Ready: %s)|r",
        sum_all_ready = "  |cff88ccff(all ready)|r",
        minimap_title = "AH Log",
        minimap_toggle = "Click: toggle window",
        minimap_drag = "Drag: move position",
        miniwidget_empty = "No entries",
        miniwidget_title = "AH Sales Log",
        miniwidget_open = "Click: open window",
        miniwidget_move = "CTRL+Drag: move",
        msg_test_entry = "|cff00ff00AHSalesLog:|r Test entry (Listed -> Sold).",
        msg_test_listed = "|cff00ff00AHSalesLog:|r Test entry in 'Listed' tab.",
        msg_debug_header = "|cff00ff00AHSalesLog Debug:|r",
        debug_yes = "yes",
        debug_no = "no",
        debug_present = "present",
        debug_missing = "|cffff0000missing|r",
        debug_empty = "empty",
        debug_detected = "detected",
        debug_not_present = "not present",
        debug_line_version = "  Version: %s",
        debug_line_ah_open = "  AH open: %s",
        debug_line_get_sell_info = "  GetAuctionSellItemInfo: %s",
        debug_line_buyout_frame = "  BuyoutPrice Frame: %s",
        debug_line_sell_item = "  Sell slot item: %s",
        debug_line_saved_buyout = "  Stored buyout: %s",
        debug_line_auctionator = "  Auctionator: %s",
        debug_line_pending = "  Pending auctions: %d",
        debug_line_sold = "  Sold entries: %d",
        debug_line_slot_live = "  Slot LIVE: %s",
        debug_line_buyout_live = "  Buyout LIVE: %s",
        msg_auctionator_detected = "|cff00ff00AHSalesLog|r Auctionator detected.",
        msg_loaded_fmt = "|cff00ff00AHSalesLog|r v%s loaded.  /ahlog  /ahlogdebug",
        msg_auto_removed_fmt = "|cff00ff00AHSalesLog:|r %d collected entries removed automatically.",
        undo_button_fmt = "Undo (%d)",
        msg_undo_restored_fmt = "|cff00ff00AHSalesLog:|r Restored %d entries.",
        theme_classic = "Classic",
        theme_dark = "Dark",
        theme_cleandark = "Clean Dark",
        theme_modern = "Modern",
    },
}

local THEME_COLORS = {
    dark = {
        edge  = { 0.12, 0.12, 0.14, 0.95 },
        bg    = { 0.04, 0.04, 0.05, 0.92 },
        title = { 0.08, 0.08, 0.10, 0.95 },
        headerBg = { 0.08, 0.07, 0.06, 0.9 },
        rowEven  = { 0.14, 0.12, 0.10, 0.6 },
        rowOdd   = { 0.08, 0.07, 0.06, 0.4 },
    },
    cleandark = {
        edge  = { 0.0, 0.0, 0.0, 0.9 },
        bg    = { 0.0, 0.0, 0.0, 0.85 },
        title = { 0.05, 0.05, 0.05, 0.9 },
        headerBg = { 0.05, 0.05, 0.05, 0.9 },
        rowEven  = { 0.10, 0.10, 0.10, 0.4 },
        rowOdd   = { 0.0, 0.0, 0.0, 0.0 },
    },
    baganator = {
        -- An Baganator Dark angelehnt (schwarz + goldene Akzente)
        edge  = { 0.16, 0.16, 0.16, 0.72 },
        bg    = { 0.05, 0.05, 0.05, 0.64 },
        title = { 0.03, 0.03, 0.03, 0.76 },
        headerBg   = { 0.02, 0.02, 0.02, 0.72 },
        rowEven    = { 0.10, 0.10, 0.10, 0.24 },
        rowOdd     = { 0.05, 0.05, 0.05, 0.14 },
        titleText  = { 1.00, 0.82, 0.00 },
        headerText = { 0.96, 0.78, 0.18 },
    },
}

local AHSalesLogFrame = nil
local scrollChild     = nil
local rowFrames       = {}
local unseenCount     = 0
local minimapBtn      = nil
local activeTab       = "sold"   -- "sold", "listed" oder "history"
local historyFilter   = "all"   -- "today", "week", "month", "year", "all"
local tabBtnSold      = nil
local tabBtnListed    = nil
local tabBtnHistory   = nil
local tabBtnOptions   = nil
local filterFrame     = nil
local optionsContent  = nil
local miniWidget      = nil

local lastAuctionatorPostTime = 0
local auctionatorRegistered = false
local pendingSyncGraceSeconds = 15
local pendingSyncRequested = false

-- Forward-Declarations (werden in Callbacks schon vor ihrer Definition verwendet)
local ApplyTheme
local ApplyLocalization
local FlashMiniWidget
local LayoutMiniWidget
local UpdateMiniWidget
local ToggleMiniWidget

-- Rate-Limiter für Chat-Filter (verhindert Doppeleinträge bei mehreren Chatframes)
local lastFilterMsg  = nil
local lastFilterTime = 0
local undoState = {
    active = false,
    expiresAt = 0,
    listType = nil, -- "sold" oder "listed"
    removed = nil,  -- { { index = n, entry = tbl }, ... }
}

local function GetLocaleTable()
    local settings = AHSalesLogDB and AHSalesLogDB.settings
    local lang = settings and settings.language or "de"
    return LOCALES[lang] or LOCALES.de
end

local function L(key, ...)
    local locale = GetLocaleTable()
    local value = locale[key] or LOCALES.de[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

local function GetLanguageName(code)
    if code == "en" then
        return L("language_en")
    end
    return L("language_de")
end

local function GetUndoSecondsLeft()
    if not undoState.active then
        return 0
    end
    local left = math.floor((undoState.expiresAt or 0) - GetTime() + 0.999)
    if left < 0 then
        left = 0
    end
    return left
end

local function ClearUndoState()
    undoState.active = false
    undoState.expiresAt = 0
    undoState.listType = nil
    undoState.removed = nil

    if AHSalesLogFrame and AHSalesLogFrame.undoBtn then
        AHSalesLogFrame.undoBtn:Hide()
    end
end

local function UpdateUndoButton()
    if not AHSalesLogFrame or not AHSalesLogFrame.undoBtn then
        return
    end
    local btn = AHSalesLogFrame.undoBtn
    if not undoState.active then
        btn:Hide()
        return
    end
    local left = GetUndoSecondsLeft()
    if left <= 0 then
        ClearUndoState()
        return
    end
    btn:SetText(L("undo_button_fmt", left))
    if activeTab == "options" then
        btn:Hide()
    else
        btn:Show()
    end
end

local function StartUndo(listType, removedEntries)
    if not removedEntries or #removedEntries == 0 then
        return
    end
    undoState.active = true
    undoState.expiresAt = GetTime() + UNDO_WINDOW_SECONDS
    undoState.listType = listType
    undoState.removed = removedEntries
    UpdateUndoButton()
end

local function RestoreUndo()
    if not undoState.active then
        return
    end
    if GetUndoSecondsLeft() <= 0 then
        ClearUndoState()
        return
    end

    local targetList = (undoState.listType == "listed") and AHSalesLogDB.pendingAuctions or AHSalesLogDB.entries
    local removedEntries = undoState.removed or {}
    table.sort(removedEntries, function(a, b)
        return (a.index or 0) < (b.index or 0)
    end)

    for _, removed in ipairs(removedEntries) do
        if removed and removed.entry then
            local idx = removed.index or (#targetList + 1)
            if idx < 1 then idx = 1 end
            if idx > (#targetList + 1) then idx = #targetList + 1 end
            table.insert(targetList, idx, removed.entry)
        end
    end

    local restoredCount = #removedEntries
    ClearUndoState()
    print(L("msg_undo_restored_fmt", restoredCount))
    AHSalesLog_RefreshList()
end

-- ============================================================
-- SavedVariables initialisieren
-- ============================================================

local function InitDB()
    if not AHSalesLogDB then AHSalesLogDB = {} end
    if not AHSalesLogDB.entries          then AHSalesLogDB.entries          = {} end
    if not AHSalesLogDB.framePos         then AHSalesLogDB.framePos         = { point="CENTER", x=0, y=0 } end
    if not AHSalesLogDB.minimapAngle     then AHSalesLogDB.minimapAngle     = 225 end
    if not AHSalesLogDB.seenMailKeys     then AHSalesLogDB.seenMailKeys     = {} end
    if not AHSalesLogDB.pendingAuctions  then AHSalesLogDB.pendingAuctions  = {} end
    if not AHSalesLogDB.history then
        -- Migration: bestehende Einträge in History übernehmen
        AHSalesLogDB.history = {}
        for i = #AHSalesLogDB.entries, 1, -1 do
            local e = AHSalesLogDB.entries[i]
            table.insert(AHSalesLogDB.history, 1, {
                time = e.time, item = e.item, itemLink = e.itemLink, price = e.price,
                buyout = e.buyout, soldAt = e.soldAt, count = e.count,
            })
        end
    end
    AHSalesLogDB.activeMailSales = nil  -- nicht mehr benötigt
    if not AHSalesLogDB.settings         then AHSalesLogDB.settings         = {} end
    if not AHSalesLogDB.settings.language then
        AHSalesLogDB.settings.language = "de"
    end
    if AHSalesLogDB.settings.autoRemoveOnMail == nil then
        AHSalesLogDB.settings.autoRemoveOnMail = false
    end
    if AHSalesLogDB.settings.allowManualDelete == nil then
        AHSalesLogDB.settings.allowManualDelete = false
    end
    if not AHSalesLogDB.settings.fontIndex then
        AHSalesLogDB.settings.fontIndex = 1
    end
    if not AHSalesLogDB.settings.theme then
        AHSalesLogDB.settings.theme = "classic"
    end
    if not AHSalesLogDB.frameSize then
        AHSalesLogDB.frameSize = { w = FRAME_WIDTH, h = FRAME_HEIGHT }
    end
    if AHSalesLogDB.settings.showMiniWidget == nil then
        AHSalesLogDB.settings.showMiniWidget = false
    end
    if not AHSalesLogDB.settings.miniWidgetAlpha then
        AHSalesLogDB.settings.miniWidgetAlpha = 0.8
    end
    if not AHSalesLogDB.miniWidgetPos then
        AHSalesLogDB.miniWidgetPos = { point = "CENTER", x = 0, y = -200 }
    end
    if AHSalesLogDB.settings.autoCleanSold == nil then
        AHSalesLogDB.settings.autoCleanSold = false
    end
    if not AHSalesLogDB.settings.miniWidgetScale then
        AHSalesLogDB.settings.miniWidgetScale = 1.0
    end
    if not AHSalesLogDB.settings.miniWidgetLayout then
        AHSalesLogDB.settings.miniWidgetLayout = "side"  -- "side" oder "stack"
    end
    if not AHSalesLogDB.lastSeenSaleCount then
        AHSalesLogDB.lastSeenSaleCount = #(AHSalesLogDB.entries or {})
    end

    -- Abgelaufene pending-Einträge in Verlauf verschieben
    local now = time()
    local pending = AHSalesLogDB.pendingAuctions
    for i = #pending, 1, -1 do
        local entry = pending[i]
        local dur = entry.duration or 172800
        if now - (entry.posted or 0) > dur then
            table.insert(AHSalesLogDB.history, 1, {
                time   = entry.time,
                item   = entry.item,
                itemLink = entry.itemLink,
                price  = entry.priceStr or FormatMoney(entry.buyout or 0),
                buyout = 0,
                soldAt = entry.posted + dur,
                count  = entry.count or 1,
                expired = true,
            })
            table.remove(pending, i)
        end
    end
end

local function GetTimestamp()
    return date("%d.%m. %H:%M")
end

-- ============================================================
-- Hilfsfunktionen
-- ============================================================

local function FormatMoney(copper)
    if not copper or copper == 0 then return "" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. "g") end
    if s > 0 then table.insert(parts, s .. "s") end
    if c > 0 then table.insert(parts, c .. "c") end
    return table.concat(parts, " ")
end

local function FormatMoneyIcons(copper)
    if not copper or copper == 0 then return "" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then table.insert(parts, g .. ICON_GOLD) end
    if s > 0 then table.insert(parts, s .. ICON_SILVER) end
    if c > 0 then table.insert(parts, c .. ICON_COPPER) end
    return table.concat(parts, " ")
end

local function SplitCopper(copper)
    if not copper or copper == 0 then return 0, 0, 0 end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return g, s, c
end

local function GetFilteredHistory()
    local history = AHSalesLogDB.history
    if historyFilter == "all" then return history end
    local now = time()
    local cutoff
    if historyFilter == "today" then
        -- Mitternacht heute
        local d = date("*t", now)
        cutoff = time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
    elseif historyFilter == "week" then
        cutoff = now - 7 * 86400
    elseif historyFilter == "month" then
        cutoff = now - 30 * 86400
    elseif historyFilter == "year" then
        cutoff = now - 365 * 86400
    else
        return history
    end
    local filtered = {}
    for _, entry in ipairs(history) do
        if (entry.soldAt or 0) >= cutoff then
            table.insert(filtered, entry)
        end
    end
    return filtered
end

local function FormatTimer(seconds, doneText)
    if seconds <= 0 then return doneText or L("timer_ready") end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    end
    return string.format("%d:%02d", m, s)
end

-- Wandelt den AH-Duration-Index (1/2/3) in Sekunden um
local DURATION_SECONDS = { [1] = 12*3600, [2] = 24*3600, [3] = 48*3600 }

local function ReadDurationFromUI()
    if AuctionFrameAuctions and AuctionFrameAuctions.duration then
        return DURATION_SECONDS[AuctionFrameAuctions.duration] or 48*3600
    end
    return 48*3600  -- Fallback
end

local function GetRowFont()
    local idx = AHSalesLogDB and AHSalesLogDB.settings and AHSalesLogDB.settings.fontIndex or 1
    local entry = FONT_LIST[idx]
    if not entry or entry.name == "Standard" then
        return nil -- nil = use GameFontNormalSmall (default)
    end
    return entry.path
end

local function ApplyFontToString(fs)
    local fontPath = GetRowFont()
    if fontPath then
        fs:SetFont(fontPath, 11)
    else
        local f, s, fl = GameFontNormalSmall:GetFont()
        fs:SetFont(f, s, fl)
    end
end

-- Itemlinks und Farbcodes entfernen
local function StripLinks(s)
    -- Schneller Pfad: Item-Name aus [Klammern] extrahieren
    local bracket = s:match("%[(.-)%]")
    if bracket and bracket ~= "" then return bracket end
    -- Fallback: alle Link-Codes entfernen
    return s:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|H[^|]+|h", "")
             :gsub("|h%[(.-)%]|h", "%1")
             :gsub("|h", "")
             :gsub("|r", "")
             :match("^%s*(.-)%s*$")
end

local function ExtractItemLink(s)
    if not s or s == "" then return nil end
    return s:match("(|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
        or s:match("(|Hitem:[^|]+|h%[[^%]]+%]|h)")
end

local function ResolveItemLink(itemName, itemLink)
    if itemLink and itemLink ~= "" then
        return itemLink
    end
    if not itemName or itemName == "" then
        return nil
    end
    local _, link = GetItemInfo(itemName)
    return link
end

-- ============================================================
-- Minimap-Badge
-- ============================================================

local function UpdateMinimapBadge()
    if not minimapBtn then return end
    if unseenCount > 0 then
        minimapBtn.badge:Show()
        minimapBtn.badgeText:SetText(unseenCount > 9 and "9+" or tostring(unseenCount))
    else
        minimapBtn.badge:Hide()
    end
end

-- ============================================================
-- Tab-Styling
-- ============================================================

local function UpdateTabStyle()
    if not tabBtnSold or not tabBtnListed or not tabBtnHistory or not tabBtnOptions then return end
    tabBtnSold:SetNormalFontObject(activeTab == "sold" and "GameFontNormal" or "GameFontNormalSmall")
    tabBtnListed:SetNormalFontObject(activeTab == "listed" and "GameFontNormal" or "GameFontNormalSmall")
    tabBtnHistory:SetNormalFontObject(activeTab == "history" and "GameFontNormal" or "GameFontNormalSmall")
    tabBtnOptions:SetNormalFontObject(activeTab == "options" and "GameFontNormal" or "GameFontNormalSmall")
end

-- ============================================================
-- Eintrag hinzufügen / Preis nachträglich setzen
-- ============================================================

local function AddEntry(item, price, buyoutCopper, itemCount, itemLink)
    local entry = {
        time   = GetTimestamp(),
        item   = item,
        itemLink = ResolveItemLink(item, itemLink),
        price  = price or "",
        buyout = buyoutCopper or 0,
        soldAt = time(),
        count  = itemCount or 1,
    }
    table.insert(AHSalesLogDB.entries, 1, entry)
    while #AHSalesLogDB.entries > MAX_ENTRIES do
        table.remove(AHSalesLogDB.entries)
    end
    -- Permanenter Verlauf (nie gelöscht)
    table.insert(AHSalesLogDB.history, 1, {
        time   = entry.time,
        item   = entry.item,
        itemLink = entry.itemLink,
        price  = entry.price,
        buyout = entry.buyout,
        soldAt = entry.soldAt,
        count  = entry.count,
    })

    if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
        AHSalesLog_RefreshList()
    else
        unseenCount = unseenCount + 1
        UpdateMinimapBadge()
    end
    if miniWidget and miniWidget:IsShown() then
        UpdateMiniWidget()
        FlashMiniWidget()
    end
end

-- Sucht den neuesten Eintrag ohne Preis für das gegebene Item und setzt den Preis.
local function EnrichEntryPrice(item, priceStr, copper)
    for _, entry in ipairs(AHSalesLogDB.entries) do
        if entry.price == "" and entry.item == item then
            entry.price = priceStr
            if not entry.itemLink then
                entry.itemLink = ResolveItemLink(entry.item, nil)
            end
            if copper and copper > 0 then
                entry.buyout = copper
            end
            return true
        end
    end
    return false
end

-- ============================================================
-- Pending-Auktionen: Preis beim Einstellen merken
-- ============================================================

-- Sucht in der pending-Liste nach dem Item und gibt Preis-String + Copper zurück.
-- Entfernt den Eintrag bei Treffer (FIFO).
local function FindPendingPrice(itemName)
    local pending = AHSalesLogDB.pendingAuctions
    for i, entry in ipairs(pending) do
        if entry.item == itemName then
            local priceStr = entry.priceStr or FormatMoney(entry.buyout)
            local copper   = entry.buyout or 0
            local count    = entry.count or 1
            local itemLink = entry.itemLink
            table.remove(pending, i)
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
                AHSalesLog_RefreshList()
            end
            return priceStr, copper, count, itemLink
        end
    end
    return nil, 0
end

local function RemoveOnePendingAuction(itemName, itemCount, buyoutPrice)
    if not itemName or itemName == "" then return false end
    local pending = AHSalesLogDB.pendingAuctions
    local targetCount = itemCount or 1
    local targetBuyout = buyoutPrice or 0

    local function RemoveByMatch(matchFn)
        for i, entry in ipairs(pending) do
            if matchFn(entry) then
                table.remove(pending, i)
                if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
                    AHSalesLog_RefreshList()
                end
                return true
            end
        end
        return false
    end

    if RemoveByMatch(function(entry)
        return entry.item == itemName and (entry.count or 1) == targetCount and (entry.buyout or 0) == targetBuyout
    end) then
        return true
    end

    if RemoveByMatch(function(entry)
        return entry.item == itemName and (entry.count or 1) == targetCount
    end) then
        return true
    end

    return RemoveByMatch(function(entry)
        return entry.item == itemName
    end)
end

local function RemoveOneSoldEntry(itemName, money)
    if not itemName or itemName == "" then return false end
    local targetMoney = money or 0
    if targetMoney <= 0 then return false end

    local entries = AHSalesLogDB.entries
    local now = time()
    local bestReadyIndex = nil
    local bestReadyAge = -1
    local bestAnyIndex = nil
    local bestAnyAge = -1

    for i, entry in ipairs(entries) do
        if entry.item == itemName then
            local entryMoney = entry.buyout or 0
            local matchesMoney = entryMoney > 0 and (
                entryMoney == targetMoney or
                math.floor(entryMoney * 0.95) == targetMoney
            )
            if matchesMoney then
                local soldAt = entry.soldAt or 0
                local age = now - soldAt
                if age > bestAnyAge then
                    bestAnyAge = age
                    bestAnyIndex = i
                end
                if age >= (MAIL_DELAY - 120) and age > bestReadyAge then
                    bestReadyAge = age
                    bestReadyIndex = i
                end
            end
        end
    end

    local removeIndex = bestReadyIndex or bestAnyIndex
    if removeIndex then
        table.remove(entries, removeIndex)
        return true
    end

    return false
end

local function ReconcilePendingWithOwnedAuctions()
    if not GetNumAuctionItems or not GetAuctionItemInfo then return end

    local owned = {}
    for i = 1, GetNumAuctionItems("owner") do
        local name, _, count, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("owner", i)
        if name then
            table.insert(owned, {
                item = name,
                count = count or 1,
                buyout = buyoutPrice or 0,
            })
        end
    end

    local function ConsumeOwnedMatch(entry)
        local entryCount = entry.count or 1
        local entryBuyout = entry.buyout or 0

        for idx, ownedEntry in ipairs(owned) do
            if ownedEntry.item == entry.item and ownedEntry.count == entryCount and ownedEntry.buyout == entryBuyout then
                table.remove(owned, idx)
                return true
            end
        end
        for idx, ownedEntry in ipairs(owned) do
            if ownedEntry.item == entry.item and ownedEntry.count == entryCount then
                table.remove(owned, idx)
                return true
            end
        end
        for idx, ownedEntry in ipairs(owned) do
            if ownedEntry.item == entry.item then
                table.remove(owned, idx)
                return true
            end
        end
        return false
    end

    local pending = AHSalesLogDB.pendingAuctions
    local now = time()
    local changed = false
    for i = #pending, 1, -1 do
        local entry = pending[i]
        if not ConsumeOwnedMatch(entry) then
            local age = now - (entry.posted or now)
            if age > pendingSyncGraceSeconds then
                table.remove(pending, i)
                changed = true
            end
        end
    end

    if changed and AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
        AHSalesLog_RefreshList()
    end
end

local function RequestOwnedAuctionsUpdate()
    if GetOwnerAuctionItems then
        pcall(GetOwnerAuctionItems, 0)
    end
end

local cancelAuctionHooked = false
local function HookCancelAuction()
    if cancelAuctionHooked or not CancelAuction then return end
    hooksecurefunc("CancelAuction", function()
        pendingSyncRequested = true
        RequestOwnedAuctionsUpdate()
    end)
    cancelAuctionHooked = true
end

-- Slot-Monitor: Erfasst Item-Info und Buyout-Preis wenn eine Auktion erstellt wird.
local pendingSellName  = nil
local pendingSellLink  = nil
local pendingSellCount = nil
local pendingSellBuyout = 0
local ahIsOpen = false

local function AddPendingAuction(itemName, itemCount, buyoutPrice, durationSec, itemLink)
    if not itemName then return end
    table.insert(AHSalesLogDB.pendingAuctions, {
        item     = itemName,
        itemLink = ResolveItemLink(itemName, itemLink),
        buyout   = buyoutPrice,
        priceStr = FormatMoney(buyoutPrice),
        count    = itemCount or 1,
        posted   = time(),
        time     = GetTimestamp(),
        duration = durationSec or 48*3600,
    })
    while #AHSalesLogDB.pendingAuctions > 200 do
        table.remove(AHSalesLogDB.pendingAuctions, 1)
    end
    if AHSalesLogFrame and AHSalesLogFrame:IsShown() and activeTab == "listed" then
        AHSalesLog_RefreshList()
    end
end

-- Liest den aktuellen Buyout-Preis aus dem AH-Eingabefeld
local function ReadBuyoutFromUI()
    if BuyoutPrice and MoneyInputFrame_GetCopper then
        return MoneyInputFrame_GetCopper(BuyoutPrice) or 0
    end
    return 0
end

-- Wird bei jedem NEW_AUCTION_UPDATE aufgerufen
local function OnAuctionSlotChanged()
    if not GetAuctionSellItemInfo then return end
    local name, _, count = GetAuctionSellItemInfo()

    if name then
        pendingSellName  = name
        if GetAuctionSellItemLink then
            pendingSellLink = GetAuctionSellItemLink() or pendingSellLink
        end
        pendingSellLink = ResolveItemLink(name, pendingSellLink)
        pendingSellCount = count
    elseif pendingSellName then
        local cursorType = GetCursorInfo()
        if cursorType ~= "item" then
            -- Guard gegen Duplikate: Auctionator feuert oft parallel eigene Events
            if (GetTime() - lastAuctionatorPostTime) > 1.5 then
                local buyout = ReadBuyoutFromUI()
                if buyout == 0 then buyout = pendingSellBuyout end
                AddPendingAuction(pendingSellName, pendingSellCount, buyout, ReadDurationFromUI(), pendingSellLink)
            end
        end
        pendingSellName  = nil
        pendingSellLink  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0
    end
end

-- Polling: speichert den Buyout-Preis regelmäßig solange ein Item im Slot liegt
local pollFrame = CreateFrame("Frame")
pollFrame:Hide()
local pollElapsed = 0
pollFrame:SetScript("OnUpdate", function(self, elapsed)
    pollElapsed = pollElapsed + elapsed
    if pollElapsed < 0.2 then return end
    pollElapsed = 0
    if not ahIsOpen or not pendingSellName then return end
    local buyout = ReadBuyoutFromUI()
    if buyout > 0 then
        pendingSellBuyout = buyout
    end
end)

-- ============================================================
-- Auctionator-Kompatibilität
-- ============================================================

local function TryRegisterAuctionator()
    if auctionatorRegistered then
        return true
    end
    if not Auctionator or not Auctionator.EventBus or not Auctionator.Selling or not Auctionator.Selling.Events then
        return false
    end

    local listener = {}
    function listener:ReceiveEvent(eventName, details)
        if eventName == Auctionator.Selling.Events.PostSuccessful then
            local itemLink = details.itemInfo and details.itemInfo.itemLink or nil
            if not itemLink then return end
            local itemName = StripLinks(itemLink)
            if not itemName or itemName == "" then return end

            local numStacks = details.numStacksReached or details.numStacks or 1
            local stackSize = details.stackSize or 1
            local buyout    = details.buyoutPrice or 0
            local durationSec = DURATION_SECONDS[details.duration] or ReadDurationFromUI()

            for s = 1, numStacks do
                AddPendingAuction(itemName, stackSize, buyout, durationSec, itemLink)
            end

            lastAuctionatorPostTime = GetTime()
            -- Slot-Monitor zuruecksetzen damit kein Duplikat entsteht
            pendingSellName  = nil
            pendingSellLink  = nil
            pendingSellCount = nil
            pendingSellBuyout = 0
        elseif Auctionator.Cancelling and Auctionator.Cancelling.Events and eventName == Auctionator.Cancelling.Events.CancelConfirmed then
            local itemLink = details and details.itemLink or nil
            local itemName = itemLink and StripLinks(itemLink) or nil
            local stackSize = details and details.stackSize or 1
            local stackPrice = details and details.stackPrice or 0
            if itemName and itemName ~= "" then
                RemoveOnePendingAuction(itemName, stackSize, stackPrice)
            end
            pendingSyncRequested = true
            RequestOwnedAuctionsUpdate()
        end
    end

    local events = { Auctionator.Selling.Events.PostSuccessful }
    if Auctionator.Cancelling and Auctionator.Cancelling.Events and Auctionator.Cancelling.Events.CancelConfirmed then
        table.insert(events, Auctionator.Cancelling.Events.CancelConfirmed)
    end
    Auctionator.EventBus:Register(listener, events)
    auctionatorRegistered = true
    return true
end

-- ============================================================
-- Chat-Filter: sofortige Erkennung mit Itemname
-- ============================================================

local function AHSalesLog_ChatFilter(_, _, msg)
    local item = msg:match("gefunden: (.-)%s*$")
                 or msg:match("found for your auction of (.-)%s*$")

    if item and item ~= "" then
        local now = GetTime()
        if msg ~= lastFilterMsg or (now - lastFilterTime) > 0.05 then
            lastFilterMsg  = msg
            lastFilterTime = now
            local cleanName = StripLinks(item)
            local chatItemLink = ExtractItemLink(item)
            local priceStr, copper, count, pendingItemLink = FindPendingPrice(cleanName)
            AddEntry(cleanName, priceStr, copper, count, pendingItemLink or chatItemLink)
        end
    end

    return false
end

-- ============================================================
-- Postfach: Preise nachträglich anreichern
-- ============================================================

local AH_SENDERS = { "Auktionshaus", "Auction House" }

local function IsAHSender(sender)
    if not sender then return false end
    for _, name in ipairs(AH_SENDERS) do
        if sender:find(name, 1, true) then return true end
    end
    return false
end

local function ScanMailbox()
    local numItems = GetInboxNumItems()

    local seenKeys  = AHSalesLogDB.seenMailKeys
    local refreshUI = false

    for i = 1, numItems do
        local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(i)

        if IsAHSender(sender) and money and money > 0 then
            local item = nil
            if subject then
                item = subject:match("%[(.-)%]") or StripLinks(subject)
            end

            local dayKey = math.floor((daysLeft or 0) * 100)
            local key = (subject or "") .. "|" .. tostring(money) .. "|" .. tostring(dayKey)

            if not seenKeys[key] then
                seenKeys[key] = true

                local priceStr = FormatMoney(money)

                if item and item ~= "" then
                    if EnrichEntryPrice(item, priceStr, money) then
                        refreshUI = true
                    end
                end
            end
        end
    end

    -- seenMailKeys auf max. 500 Einträge begrenzen
    local count = 0
    for _ in pairs(seenKeys) do count = count + 1 end
    if count > 500 then
        AHSalesLogDB.seenMailKeys = {}
        for i = 1, numItems do
            local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(i)
            if IsAHSender(sender) and money and money > 0 then
                local dayKey = math.floor((daysLeft or 0) * 100)
                local key = (subject or "") .. "|" .. tostring(money) .. "|" .. tostring(dayKey)
                AHSalesLogDB.seenMailKeys[key] = true
            end
        end
    end

    if refreshUI and AHSalesLogFrame and AHSalesLogFrame:IsShown() then
        AHSalesLog_RefreshList()
    end
end

-- Mail-Cache: speichert Daten aller AH-Mails bei MAIL_INBOX_UPDATE
-- hooksecurefunc feuert NACH dem Call, dann ist money bereits 0
-- Daher cachen wir die Daten vorher und lesen sie im Hook aus dem Cache
local mailCache = {}

local function UpdateMailCache()
    mailCache = {}
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        local _, _, sender, subject, money = GetInboxHeaderInfo(i)
        if IsAHSender(sender) and money and money > 0 then
            local item = nil
            if subject then
                item = subject:match("%[(.-)%]") or StripLinks(subject)
            end
            mailCache[i] = { item = item, money = money }
        end
    end
end

local function OnMailMoneyTaken(mailIndex)
    if not AHSalesLogDB.settings.autoRemoveOnMail then return end
    local cached = mailCache[mailIndex]
    if not cached then return end
    local item = cached.item
    local money = cached.money
    if item and item ~= "" and money and money > 0 then
        if RemoveOneSoldEntry(item, money) then
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
                AHSalesLog_RefreshList()
            end
        end
    end
    mailCache[mailIndex] = nil
end

local takeMoneyHooked = false
local function HookTakeInboxMoney()
    if takeMoneyHooked then return end
    if TakeInboxMoney then
        hooksecurefunc("TakeInboxMoney", function(mailIndex)
            OnMailMoneyTaken(mailIndex)
        end)
    end
    if AutoLootMailItem then
        hooksecurefunc("AutoLootMailItem", function(mailIndex)
            OnMailMoneyTaken(mailIndex)
        end)
    end
    takeMoneyHooked = true
end

-- ============================================================
-- UI: Hauptfenster
-- ============================================================

-- ============================================================
-- Dark-Theme Helfer (wiederverwendbar fuer alle Frames)
-- ============================================================

local function CollectOriginalTextures(f)
    f.originalTextures = {}
    -- Alle Texturen des Frames selbst
    for _, region in ipairs({ f:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            table.insert(f.originalTextures, region)
        end
    end
    -- Inset-Texturen
    if f.Inset then
        for _, region in ipairs({ f.Inset:GetRegions() }) do
            if region:GetObjectType() == "Texture" then
                table.insert(f.originalTextures, region)
            end
        end
    end
    -- NineSlice-Texturen
    if f.NineSlice then
        for _, region in ipairs({ f.NineSlice:GetRegions() }) do
            if region:GetObjectType() == "Texture" then
                table.insert(f.originalTextures, region)
            end
        end
    end
end

local function AddDarkTextures(f)
    local darkEdge = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    darkEdge:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    darkEdge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    darkEdge:Hide()
    f.darkEdge = darkEdge

    local darkBg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    darkBg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    darkBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    darkBg:Hide()
    f.darkBg = darkBg

    local darkTitle = f:CreateTexture(nil, "ARTWORK", nil, -8)
    darkTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    darkTitle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 0)
    darkTitle:SetHeight(22)
    darkTitle:Hide()
    f.darkTitle = darkTitle
end

local function ApplyDarkColors(f, colors)
    if not colors then return end
    if f.darkEdge then f.darkEdge:SetColorTexture(unpack(colors.edge)) end
    if f.darkBg then f.darkBg:SetColorTexture(unpack(colors.bg)) end
    if f.darkTitle then f.darkTitle:SetColorTexture(unpack(colors.title)) end
end

local function SetDarkTexturesVisible(f, visible)
    local textures = { f.darkEdge, f.darkBg, f.darkTitle }
    for _, tex in ipairs(textures) do
        if tex then
            if visible then tex:Show() else tex:Hide() end
        end
    end
end

local function SetOriginalTexturesVisible(f, visible)
    if not f.originalTextures then return end
    for _, tex in ipairs(f.originalTextures) do
        if visible then tex:Show() else tex:Hide() end
    end
end

local function CreateLabeledCheckbox(parent, text, x, y, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetScript("OnClick", onClick)

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    label:SetWidth(320)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    cb.label = label
    return cb
end

local function GetThemeName(key)
    for _, t in ipairs(THEME_LIST) do
        if t.key == key then return L(t.nameKey) end
    end
    return key
end

local function CreateOptionsContent(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -52)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PAD, 6)
    f:Hide()

    local function BuildDropdownButton(parentFrame, name, width, x, y)
        local btn = CreateFrame("Button", name, parentFrame)
        btn:SetSize(width, 22)
        btn:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
        local border = btn:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.4, 0.4, 0.4, 0.8)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
        btn.text:SetJustifyH("LEFT")
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        arrow:SetText("v")
        arrow:SetTextColor(0.7, 0.7, 0.7)
        return btn
    end

    local function BuildDropdown(parentFrame, name, width, itemCount, anchorTo)
        local dd = CreateFrame("Frame", name, parentFrame)
        dd:SetSize(width, itemCount * 24 + 4)
        dd:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -2)
        dd:SetFrameStrata("TOOLTIP")
        dd:Hide()
        local bg = dd:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
        local border = dd:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.4, 0.4, 0.4, 0.8)
        return dd
    end

    local labelX = 10
    local controlX = 150
    local controlW = 170
    local hintW = 280

    local yLanguage = -6
    local yManualDelete = -34
    local yAutoClean = -62
    local yFont = -90
    local yTheme = -118
    local yReload = -146
    local yMiniWidget = -178
    local yAlpha = -208
    local yScale = -236
    local yLayout = -264

    -- === Sprache ===
    local languageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    languageLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yLanguage)
    languageLabel:SetTextColor(1, 1, 1)
    f.languageLabel = languageLabel

    local languageBtn = BuildDropdownButton(f, "AHSalesLogLanguageBtn", controlW, controlX, yLanguage)
    f.languageBtn = languageBtn

    local languageDropdown = BuildDropdown(f, "AHSalesLogLanguageDropdown", controlW, 2, languageBtn)
    local languageRows = {}
    local function ApplyLanguageSelection(lang)
        local nextLang = (lang == "en") and "en" or "de"
        if AHSalesLogDB.settings.language ~= nextLang then
            AHSalesLogDB.settings.language = nextLang
            if ApplyLocalization then
                ApplyLocalization()
            end
        end
        languageDropdown:Hide()
    end
    for li, lang in ipairs({ "de", "en" }) do
        local item = CreateFrame("Button", nil, languageDropdown)
        item:SetSize(controlW - 2, 24)
        item:SetPoint("TOPLEFT", languageDropdown, "TOPLEFT", 1, -(li - 1) * 24 - 2)
        local itemBg = item:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints()
        itemBg:SetColorTexture(0, 0, 0, 0)
        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", item, "LEFT", 6, 0)
        itemText:SetJustifyH("LEFT")
        itemText:SetText(GetLanguageName(lang))
        item:SetScript("OnEnter", function() itemBg:SetColorTexture(0.3, 0.3, 0.5, 0.6) end)
        item:SetScript("OnLeave", function() itemBg:SetColorTexture(0, 0, 0, 0) end)
        item:SetScript("OnClick", function() ApplyLanguageSelection(lang) end)
        table.insert(languageRows, { lang = lang, text = itemText })
    end
    f.languageRows = languageRows
    languageBtn:SetScript("OnClick", function()
        if languageDropdown:IsShown() then languageDropdown:Hide() else languageDropdown:Show() end
    end)
    languageDropdown:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if not self2:IsMouseOver() and not languageBtn:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self2:Hide()
            end
        end)
    end)

    -- === Rechtsklick-Loeschen ===
    local manualDelete = CreateLabeledCheckbox(f, "", labelX - 4, yManualDelete, function(self)
        AHSalesLogDB.settings.allowManualDelete = self:GetChecked() and true or false
    end)
    f.manualDelete = manualDelete

    -- === Auto-Clean Verkauft ===
    local autoCleanCb = CreateLabeledCheckbox(f, "", labelX - 4, yAutoClean, function(self)
        AHSalesLogDB.settings.autoCleanSold = self:GetChecked() and true or false
    end)
    f.autoCleanCb = autoCleanCb

    -- === Schriftart ===
    local fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yFont)
    fontLabel:SetTextColor(1, 1, 1)
    f.fontLabel = fontLabel

    local fontBtn = BuildDropdownButton(f, "AHSalesLogFontBtn", controlW, controlX, yFont)
    f.fontBtn = fontBtn

    local fontDropdown = BuildDropdown(f, "AHSalesLogFontDropdown", controlW, #FONT_LIST, fontBtn)
    local function ApplyFontSelection(idx)
        AHSalesLogDB.settings.fontIndex = idx
        fontBtn.text:SetText(FONT_LIST[idx].name)
        for _, row in ipairs(rowFrames) do
            ApplyFontToString(row.ts)
            ApplyFontToString(row.item)
            ApplyFontToString(row.gold)
            ApplyFontToString(row.silver)
            ApplyFontToString(row.copper)
            ApplyFontToString(row.timer)
        end
        fontDropdown:Hide()
    end
    local fontItems = {}
    for fi = 1, #FONT_LIST do
        local entry = FONT_LIST[fi]
        local item = CreateFrame("Button", nil, fontDropdown)
        item:SetSize(controlW - 2, 24)
        item:SetPoint("TOPLEFT", fontDropdown, "TOPLEFT", 1, -(fi - 1) * 24 - 2)
        local itemBg = item:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints()
        itemBg:SetColorTexture(0, 0, 0, 0)
        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", item, "LEFT", 6, 0)
        itemText:SetJustifyH("LEFT")
        if entry.name ~= "Standard" then
            itemText:SetFont(entry.path, 11)
        end
        item:SetScript("OnEnter", function() itemBg:SetColorTexture(0.3, 0.3, 0.5, 0.6) end)
        item:SetScript("OnLeave", function() itemBg:SetColorTexture(0, 0, 0, 0) end)
        item:SetScript("OnClick", function() ApplyFontSelection(fi) end)
        table.insert(fontItems, { entry = entry, text = itemText })
    end
    f.fontItems = fontItems
    fontBtn:SetScript("OnClick", function()
        if fontDropdown:IsShown() then fontDropdown:Hide() else fontDropdown:Show() end
    end)
    fontDropdown:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if not self2:IsMouseOver() and not fontBtn:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self2:Hide()
            end
        end)
    end)

    -- === Design ===
    local themeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    themeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yTheme)
    themeLabel:SetTextColor(1, 1, 1)
    f.themeLabel = themeLabel

    local themeBtn = BuildDropdownButton(f, "AHSalesLogThemeBtn", controlW, controlX, yTheme)
    f.themeBtn = themeBtn

    local themeDropdown = BuildDropdown(f, "AHSalesLogThemeDropdown", controlW, #THEME_LIST, themeBtn)
    local themeItems = {}
    for ti = 1, #THEME_LIST do
        local entry = THEME_LIST[ti]
        local item = CreateFrame("Button", nil, themeDropdown)
        item:SetSize(controlW - 2, 24)
        item:SetPoint("TOPLEFT", themeDropdown, "TOPLEFT", 1, -(ti - 1) * 24 - 2)
        local itemBg = item:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints()
        itemBg:SetColorTexture(0, 0, 0, 0)
        local itemText = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        itemText:SetPoint("LEFT", item, "LEFT", 6, 0)
        itemText:SetJustifyH("LEFT")
        item:SetScript("OnEnter", function() itemBg:SetColorTexture(0.3, 0.3, 0.5, 0.6) end)
        item:SetScript("OnLeave", function() itemBg:SetColorTexture(0, 0, 0, 0) end)
        item:SetScript("OnClick", function()
            AHSalesLogDB.settings.theme = entry.key
            themeBtn.text:SetText(GetThemeName(entry.key))
            themeDropdown:Hide()
            ApplyTheme()
        end)
        table.insert(themeItems, { entry = entry, text = itemText })
    end
    f.themeItems = themeItems
    themeBtn:SetScript("OnClick", function()
        if themeDropdown:IsShown() then themeDropdown:Hide() else themeDropdown:Show() end
    end)
    themeDropdown:SetScript("OnShow", function(self)
        self:SetScript("OnUpdate", function(self2)
            if not self2:IsMouseOver() and not themeBtn:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self2:Hide()
            end
        end)
    end)

    local reloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reloadBtn:SetSize(controlW, 20)
    reloadBtn:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yReload)
    reloadBtn:SetScript("OnClick", function() ReloadUI() end)
    f.reloadBtn = reloadBtn

    local reloadHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reloadHint:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yReload - 20)
    reloadHint:SetWidth(hintW)
    reloadHint:SetJustifyH("LEFT")
    reloadHint:SetTextColor(0.5, 0.5, 0.5)
    f.reloadHint = reloadHint

    -- === Mini-Widget ===
    local miniWidgetCb = CreateLabeledCheckbox(f, "", labelX - 4, yMiniWidget, function(self)
        AHSalesLogDB.settings.showMiniWidget = self:GetChecked() and true or false
        ToggleMiniWidget()
    end)
    f.miniWidgetCb = miniWidgetCb

    local alphaLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alphaLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yAlpha)
    alphaLabel:SetTextColor(0.8, 0.8, 0.8)
    f.alphaLabel = alphaLabel

    local alphaSlider = CreateFrame("Slider", "AHSalesLogAlphaSlider", f, "OptionsSliderTemplate")
    alphaSlider:SetSize(controlW, 14)
    alphaSlider:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yAlpha + 4)
    alphaSlider:SetMinMaxValues(0.2, 1.0)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider.Low:SetText("20%")
    alphaSlider.High:SetText("100%")
    alphaSlider.Text:SetText("")
    alphaSlider.Text:ClearAllPoints()
    alphaSlider.Text:SetPoint("LEFT", alphaSlider, "RIGHT", 10, 0)
    alphaSlider.Text:SetJustifyH("LEFT")
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        AHSalesLogDB.settings.miniWidgetAlpha = value
        self.Text:SetText(math.floor(value * 100 + 0.5) .. "%")
        if miniWidget then miniWidget:SetAlpha(value) end
    end)
    f.alphaSlider = alphaSlider

    -- === Widget-Groesse ===
    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yScale)
    scaleLabel:SetTextColor(0.8, 0.8, 0.8)
    f.scaleLabel = scaleLabel

    local scaleSlider = CreateFrame("Slider", "AHSalesLogScaleSlider", f, "OptionsSliderTemplate")
    scaleSlider:SetSize(controlW, 14)
    scaleSlider:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yScale + 4)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider.Low:SetText("50%")
    scaleSlider.High:SetText("200%")
    scaleSlider.Text:SetText("")
    scaleSlider.Text:ClearAllPoints()
    scaleSlider.Text:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    scaleSlider.Text:SetJustifyH("LEFT")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        AHSalesLogDB.settings.miniWidgetScale = value
        self.Text:SetText(math.floor(value * 100 + 0.5) .. "%")
        LayoutMiniWidget()
    end)
    f.scaleSlider = scaleSlider

    -- === Widget-Layout ===
    local layoutLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layoutLabel:SetPoint("TOPLEFT", f, "TOPLEFT", labelX, yLayout)
    layoutLabel:SetTextColor(0.8, 0.8, 0.8)
    f.layoutLabel = layoutLabel

    local layoutBtn = CreateFrame("Button", nil, f)
    layoutBtn:SetSize(controlW, 22)
    layoutBtn:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yLayout)
    local lbBg = layoutBtn:CreateTexture(nil, "BACKGROUND")
    lbBg:SetAllPoints()
    lbBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    local lbBorder = layoutBtn:CreateTexture(nil, "BORDER")
    lbBorder:SetPoint("TOPLEFT", -1, 1)
    lbBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    lbBorder:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    layoutBtn.text = layoutBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    layoutBtn.text:SetPoint("CENTER")
    layoutBtn:SetScript("OnClick", function()
        local cur = AHSalesLogDB.settings.miniWidgetLayout
        local newLayout = (cur == "side") and "stack" or "side"
        AHSalesLogDB.settings.miniWidgetLayout = newLayout
        local layoutNames = {
            side = L("option_layout_side"),
            stack = L("option_layout_stack"),
        }
        layoutBtn.text:SetText(layoutNames[newLayout] or layoutNames.side)
        LayoutMiniWidget()
        UpdateMiniWidget()
    end)
    f.layoutBtn = layoutBtn

    local widgetHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    widgetHint:SetPoint("TOPLEFT", f, "TOPLEFT", controlX, yLayout - 24)
    widgetHint:SetWidth(hintW)
    widgetHint:SetJustifyH("LEFT")
    widgetHint:SetTextColor(0.5, 0.5, 0.5)
    f.widgetHint = widgetHint

    function f:ApplyLocale()
        self.languageLabel:SetText(L("option_language"))
        self.languageBtn.text:SetText(GetLanguageName(AHSalesLogDB.settings.language))
        for _, row in ipairs(self.languageRows) do
            row.text:SetText(GetLanguageName(row.lang))
        end

        self.manualDelete.label:SetText(L("option_manual_delete"))
        self.autoCleanCb.label:SetText(L("option_auto_clean_sold"))
        self.fontLabel:SetText(L("option_font"))
        self.themeLabel:SetText(L("option_theme"))
        self.reloadBtn:SetText(L("option_reload"))
        self.reloadHint:SetText(L("option_reload_hint"))
        self.miniWidgetCb.label:SetText(L("option_mini_widget"))
        self.alphaLabel:SetText(L("option_transparency"))
        self.scaleLabel:SetText(L("option_size"))
        self.layoutLabel:SetText(L("option_layout"))
        self.widgetHint:SetText(L("option_widget_hint"))

        for _, item in ipairs(self.fontItems) do
            item.text:SetText(L("option_font_example", item.entry.name))
        end
        for _, item in ipairs(self.themeItems) do
            item.text:SetText(GetThemeName(item.entry.key))
        end

        local layoutNames = {
            side = L("option_layout_side"),
            stack = L("option_layout_stack"),
        }
        self.layoutBtn.text:SetText(layoutNames[AHSalesLogDB.settings.miniWidgetLayout] or layoutNames.side)
        self.themeBtn.text:SetText(GetThemeName(AHSalesLogDB.settings.theme))
    end

    function f:RefreshValues()
        self.manualDelete:SetChecked(AHSalesLogDB.settings.allowManualDelete)
        self.autoCleanCb:SetChecked(AHSalesLogDB.settings.autoCleanSold)
        local idx = AHSalesLogDB.settings.fontIndex or 1
        self.fontBtn.text:SetText(FONT_LIST[idx].name)
        self.themeBtn.text:SetText(GetThemeName(AHSalesLogDB.settings.theme))
        self.miniWidgetCb:SetChecked(AHSalesLogDB.settings.showMiniWidget)
        self.alphaSlider:SetValue(AHSalesLogDB.settings.miniWidgetAlpha)
        self.scaleSlider:SetValue(AHSalesLogDB.settings.miniWidgetScale)
        self.languageBtn.text:SetText(GetLanguageName(AHSalesLogDB.settings.language))
        local layoutNames = {
            side = L("option_layout_side"),
            stack = L("option_layout_stack"),
        }
        self.layoutBtn.text:SetText(layoutNames[AHSalesLogDB.settings.miniWidgetLayout] or layoutNames.side)
    end

    return f
end

local function CreateMainFrame()
    local f = CreateFrame("Frame", "AHSalesLogFrame", UIParent, "BasicFrameTemplateWithInset")
    local savedSize = AHSalesLogDB.frameSize
    f:SetSize(savedSize.w, savedSize.h)
    f:SetMovable(true)
    f:SetResizable(true)
    f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, 800, 600)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:Hide()

    f.TitleText:SetText("AH Sales Log  v" .. ADDON_VERSION)

    -- Texturen fuer Theme-Wechsel sammeln + dunkle Texturen erstellen
    CollectOriginalTextures(f)
    AddDarkTextures(f)

    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        AHSalesLogDB.framePos = { point = point, x = x, y = y }
    end)

    -- Resize-Handle unten rechts
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeBtn:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        AHSalesLogDB.frameSize = { w = f:GetWidth(), h = f:GetHeight() }
        AHSalesLog_RefreshList()
    end)

    -- Tab-Buttons
    local tabTop = -28

    local tabW = 85

    local btnSold = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnSold:SetSize(tabW, TAB_H)
    btnSold:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, tabTop)
    btnSold:SetText(L("tab_sold"))
    btnSold:SetScript("OnClick", function()
        activeTab = "sold"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnSold = btnSold

    local btnListed = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnListed:SetSize(tabW, TAB_H)
    btnListed:SetPoint("LEFT", btnSold, "RIGHT", 2, 0)
    btnListed:SetText(L("tab_listed"))
    btnListed:SetScript("OnClick", function()
        activeTab = "listed"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnListed = btnListed

    local btnHistory = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnHistory:SetSize(tabW, TAB_H)
    btnHistory:SetPoint("LEFT", btnListed, "RIGHT", 2, 0)
    btnHistory:SetText(L("tab_history"))
    btnHistory:SetScript("OnClick", function()
        activeTab = "history"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnHistory = btnHistory

    local btnOptions = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnOptions:SetSize(tabW, TAB_H)
    btnOptions:SetPoint("LEFT", btnHistory, "RIGHT", 2, 0)
    btnOptions:SetText(L("tab_options"))
    btnOptions:SetScript("OnClick", function()
        activeTab = "options"
        UpdateTabStyle()
        AHSalesLog_RefreshList()
    end)
    tabBtnOptions = btnOptions

    UpdateTabStyle()

    -- Filter-Buttons für Verlauf-Tab
    local filt = CreateFrame("Frame", nil, f)
    filt:SetHeight(18)
    filt:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, tabTop - TAB_H - 1)
    filt:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD+20), tabTop - TAB_H - 1)
    filt:Hide()
    filterFrame = filt

    local filterDefs = {
        { key = "today", labelKey = "filter_today" },
        { key = "week",  labelKey = "filter_week" },
        { key = "month", labelKey = "filter_month" },
        { key = "year",  labelKey = "filter_year" },
        { key = "all",   labelKey = "filter_all" },
    }
    filt.buttons = {}
    local prevBtn = nil
    for _, def in ipairs(filterDefs) do
        local fb = CreateFrame("Button", nil, filt, "UIPanelButtonTemplate")
        fb:SetSize(55, 16)
        fb:SetText(L(def.labelKey))
        fb:GetFontString():SetFont(GameFontNormalSmall:GetFont())
        if prevBtn then
            fb:SetPoint("LEFT", prevBtn, "RIGHT", 2, 0)
        else
            fb:SetPoint("LEFT", filt, "LEFT", 0, 0)
        end
        fb.filterKey = def.key
        fb.labelKey = def.labelKey
        fb:SetScript("OnClick", function()
            historyFilter = def.key
            AHSalesLog_RefreshList()
        end)
        table.insert(filt.buttons, fb)
        prevBtn = fb
    end

    -- Spaltenüberschriften
    local headerTopBase = tabTop - TAB_H - 2
    local filterH = 20  -- Höhe der Filterleiste

    local headerBg = f:CreateTexture(nil, "BACKGROUND")
    headerBg:SetColorTexture(0, 0, 0, 0.5)
    headerBg:SetHeight(HEADER_H)
    f.headerTopBase = headerTopBase
    f.filterH = filterH

    local function MakeHeader(text, width, justify)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        if width then lbl:SetWidth(width) end
        lbl:SetJustifyH(justify or "LEFT")
        lbl:SetTextColor(0.9, 0.85, 0.3)
        lbl:SetText(text)
        return lbl
    end
    f.headerTime   = MakeHeader(L("header_time"))
    f.headerItem   = MakeHeader(L("header_item"))
    f.headerGold   = MakeHeader(ICON_GOLD,   COL_GOLD,   "RIGHT")
    f.headerSilver = MakeHeader(ICON_SILVER, COL_SILVER, "RIGHT")
    f.headerCopper = MakeHeader(ICON_COPPER, COL_COPPER, "RIGHT")
    f.headerTimer  = MakeHeader(L("header_mail"))
    f.headerBg     = headerBg

    local function LayoutHeaders()
        local isHistory = (activeTab == "history")
        local headerTop = headerTopBase - (isHistory and filterH or 0)
        local colItem = GetItemColWidth()
        local ps = 2 + COL_TS + 4 + colItem + 4

        headerBg:ClearAllPoints()
        headerBg:SetPoint("TOPLEFT",  f, "TOPLEFT",  PAD, headerTop)
        headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD+20), headerTop)

        f.headerTime:ClearAllPoints()
        f.headerTime:SetPoint("LEFT", headerBg, "LEFT", 2, 0)
        f.headerItem:ClearAllPoints()
        f.headerItem:SetPoint("LEFT", headerBg, "LEFT", 2 + COL_TS + 4, 0)
        f.headerItem:SetWidth(colItem)
        f.headerGold:ClearAllPoints()
        f.headerGold:SetPoint("LEFT",   headerBg, "LEFT", ps, 0)
        f.headerSilver:ClearAllPoints()
        f.headerSilver:SetPoint("LEFT", headerBg, "LEFT", ps + COL_GOLD + 2, 0)
        f.headerCopper:ClearAllPoints()
        f.headerCopper:SetPoint("LEFT", headerBg, "LEFT", ps + COL_GOLD + 2 + COL_SILVER + 2, 0)
        f.headerTimer:ClearAllPoints()
        f.headerTimer:SetPoint("LEFT",  headerBg, "LEFT", ps + COL_GOLD + 2 + COL_SILVER + 2 + COL_COPPER + 4, 0)

        f.scrollFrame:ClearAllPoints()
        f.scrollFrame:SetPoint("TOPLEFT",     f, "TOPLEFT",     PAD,       headerTop - HEADER_H)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 30)
    end
    f.LayoutHeaders = LayoutHeaders

    -- ScrollFrame
    local sf = CreateFrame("ScrollFrame", "AHSalesLogScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     f, "TOPLEFT",  PAD,       headerTopBase - HEADER_H)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 30)
    f.scrollFrame = sf

    LayoutHeaders()

    local sc = CreateFrame("Frame", "AHSalesLogScrollChild", sf)
    sc:SetWidth(f:GetWidth() - PAD - (PAD + 20))
    sc:SetHeight(1)
    sf:SetScrollChild(sc)
    scrollChild = sc

    -- "Leeren"-Button (nicht im Verlauf-Tab)
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 6)
    clearBtn:SetText(L("button_clear"))
    f.clearBtn = clearBtn
    StaticPopupDialogs["AHSALESLOG_CLEAR_CONFIRM"] = {
        text = L("clear_confirm_all"),
        button1 = L("popup_yes"),
        button2 = L("popup_no"),
        OnAccept = function()
            if activeTab == "sold" then
                -- Nur Eintraege entfernen deren Timer abgelaufen ist (bereits im Postfach)
                local now = time()
                local entries = AHSalesLogDB.entries
                for i = #entries, 1, -1 do
                    local soldAt = entries[i].soldAt or 0
                    if (now - soldAt) >= MAIL_DELAY then
                        table.remove(entries, i)
                    end
                end
            else
                AHSalesLogDB.pendingAuctions = {}
            end
            AHSalesLog_RefreshList()
        end,
        timeout = 0,
        whileDead = true,
    }
    clearBtn:SetScript("OnClick", function()
        if activeTab == "sold" then
            -- Zaehlen wie viele bereit sind
            local now = time()
            local readyCount = 0
            for _, entry in ipairs(AHSalesLogDB.entries) do
                if (now - (entry.soldAt or 0)) >= MAIL_DELAY then
                    readyCount = readyCount + 1
                end
            end
            if readyCount == 0 then
                print(L("msg_no_ready_entries"))
                return
            end
            StaticPopupDialogs["AHSALESLOG_CLEAR_CONFIRM"].text =
                L("clear_confirm_ready_fmt", readyCount)
        else
            StaticPopupDialogs["AHSALESLOG_CLEAR_CONFIRM"].text =
                L("clear_confirm_all")
        end
        StaticPopup_Show("AHSALESLOG_CLEAR_CONFIRM")
    end)

    local undoBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    undoBtn:SetSize(116, 22)
    undoBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    undoBtn:SetScript("OnClick", function()
        RestoreUndo()
    end)
    undoBtn:Hide()
    f.undoBtn = undoBtn

    -- Summe-Label (links neben Count)
    local sumLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sumLabel:SetPoint("LEFT", undoBtn, "RIGHT", 8, 0)
    sumLabel:SetTextColor(0.4, 1, 0.4)
    f.sumLabel = sumLabel

    local countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD+20), 10)
    countLabel:SetTextColor(0.6, 0.6, 0.6)
    f.countLabel = countLabel

    -- Options-Content als Tab-Inhalt
    optionsContent = CreateOptionsContent(f)

    AHSalesLogFrame = f
end

function ApplyLocalization()
    if not AHSalesLogFrame then return end

    if tabBtnSold then tabBtnSold:SetText(L("tab_sold")) end
    if tabBtnListed then tabBtnListed:SetText(L("tab_listed")) end
    if tabBtnHistory then tabBtnHistory:SetText(L("tab_history")) end
    if tabBtnOptions then tabBtnOptions:SetText(L("tab_options")) end

    if filterFrame and filterFrame.buttons then
        for _, fb in ipairs(filterFrame.buttons) do
            if fb.labelKey then
                fb:SetText(L(fb.labelKey))
            end
        end
    end

    if AHSalesLogFrame.headerTime then AHSalesLogFrame.headerTime:SetText(L("header_time")) end
    if AHSalesLogFrame.headerItem then AHSalesLogFrame.headerItem:SetText(L("header_item")) end
    if AHSalesLogFrame.clearBtn then AHSalesLogFrame.clearBtn:SetText(L("button_clear")) end
    UpdateUndoButton()

    local popup = StaticPopupDialogs["AHSALESLOG_CLEAR_CONFIRM"]
    if popup then
        popup.text = L("clear_confirm_all")
        popup.button1 = L("popup_yes")
        popup.button2 = L("popup_no")
    end

    if optionsContent and optionsContent.ApplyLocale then
        optionsContent:ApplyLocale()
    end

    if miniWidget and miniWidget:IsShown() then
        UpdateMiniWidget()
    end

    AHSalesLog_RefreshList()
end

-- ============================================================
-- Theme-System
-- ============================================================

local function ApplyThemeToFrame(f, isDark, colors)
    if not f then return end
    SetOriginalTexturesVisible(f, not isDark)
    SetDarkTexturesVisible(f, isDark)
    if isDark and colors then
        ApplyDarkColors(f, colors)
    end
    if f.CloseButton and f.CloseButton:GetNormalTexture() then
        f.CloseButton:GetNormalTexture():SetVertexColor(isDark and 0.8 or 1, isDark and 0.8 or 1, isDark and 0.8 or 1)
    end
    if f.TitleText then
        if isDark then
            if colors and colors.titleText then
                f.TitleText:SetTextColor(unpack(colors.titleText))
            else
                f.TitleText:SetTextColor(0.9, 0.78, 0.4)
            end
        else
            f.TitleText:SetTextColor(1, 0.82, 0)
        end
    end
end

function ApplyTheme()
    if not AHSalesLogFrame then return end
    local f = AHSalesLogFrame
    local theme = AHSalesLogDB.settings.theme
    local isDark = (theme == "dark" or theme == "cleandark" or theme == "baganator")
    local colors = THEME_COLORS[theme]

    -- Hauptfenster + Optionen
    ApplyThemeToFrame(f, isDark, colors)

    -- Header-Hintergrund
    if f.headerBg then
        if isDark and colors then
            f.headerBg:SetColorTexture(unpack(colors.headerBg))
        else
            f.headerBg:SetColorTexture(0, 0, 0, 0.5)
        end
    end

    -- Header-Text
    local hdrColor
    if isDark and colors and colors.headerText then
        hdrColor = colors.headerText
    elseif isDark then
        hdrColor = {0.85, 0.72, 0.30}
    else
        hdrColor = {0.9, 0.85, 0.3}
    end
    for _, hdr in ipairs({ f.headerTime, f.headerItem, f.headerGold, f.headerSilver, f.headerCopper, f.headerTimer }) do
        if hdr then hdr:SetTextColor(unpack(hdrColor)) end
    end

    -- Zeilen-Farben werden in RefreshList gesetzt
    if f:IsShown() then
        AHSalesLog_RefreshList()
    end
end

-- ============================================================
-- UI: Liste neu aufbauen
-- ============================================================

function AHSalesLog_RefreshList()
    local isOptions = (activeTab == "options")

    -- Options-Tab: alles andere verstecken, nur optionsContent zeigen
    if optionsContent then
        optionsContent:SetShown(isOptions)
        if isOptions and optionsContent.RefreshValues then
            optionsContent:RefreshValues()
        end
    end
    if isOptions then
        if AHSalesLogFrame then
            AHSalesLogFrame.scrollFrame:Hide()
            AHSalesLogFrame.headerBg:Hide()
            AHSalesLogFrame.headerTime:Hide()
            AHSalesLogFrame.headerItem:Hide()
            AHSalesLogFrame.headerGold:Hide()
            AHSalesLogFrame.headerSilver:Hide()
            AHSalesLogFrame.headerCopper:Hide()
            AHSalesLogFrame.headerTimer:Hide()
            AHSalesLogFrame.clearBtn:Hide()
            if AHSalesLogFrame.undoBtn then
                AHSalesLogFrame.undoBtn:Hide()
            end
            AHSalesLogFrame.sumLabel:SetText("")
            AHSalesLogFrame.countLabel:SetText("")
        end
        if filterFrame then filterFrame:Hide() end
        return
    end

    -- Normale Tabs: scrollFrame wieder zeigen
    if AHSalesLogFrame then
        AHSalesLogFrame.scrollFrame:Show()
        AHSalesLogFrame.headerBg:Show()
        AHSalesLogFrame.headerTime:Show()
        AHSalesLogFrame.headerItem:Show()
        AHSalesLogFrame.headerGold:Show()
        AHSalesLogFrame.headerSilver:Show()
        AHSalesLogFrame.headerCopper:Show()
    end

    local data
    if activeTab == "sold" then
        data = AHSalesLogDB.entries
    elseif activeTab == "history" then
        data = GetFilteredHistory()
    else
        data = AHSalesLogDB.pendingAuctions
    end

    local count = #data
    local isSold = (activeTab == "sold")
    local isHistory = (activeTab == "history")
    local colItem = GetItemColWidth()

    -- Filter-Leiste nur im Verlauf-Tab zeigen
    if filterFrame then
        if isHistory then
            filterFrame:Show()
            -- Aktiven Filter-Button hervorheben
            for _, fb in ipairs(filterFrame.buttons) do
                if fb.filterKey == historyFilter then
                    fb:SetNormalFontObject("GameFontNormal")
                else
                    fb:SetNormalFontObject("GameFontNormalSmall")
                end
            end
        else
            filterFrame:Hide()
        end
    end

    -- Leeren-Button nur im Verkauft-Tab zeigen
    if AHSalesLogFrame and AHSalesLogFrame.clearBtn then
        if isSold then
            AHSalesLogFrame.clearBtn:Show()
        else
            AHSalesLogFrame.clearBtn:Hide()
        end
    end
    UpdateUndoButton()

    -- Header-Layout aktualisieren (Fensterbreite kann sich geändert haben)
    if AHSalesLogFrame and AHSalesLogFrame.LayoutHeaders then
        AHSalesLogFrame.LayoutHeaders()
    end

    -- ScrollChild-Breite aktualisieren
    if scrollChild and AHSalesLogFrame then
        scrollChild:SetWidth(AHSalesLogFrame:GetWidth() - PAD - (PAD + 20))
    end

    -- Timer-Header im Verkauft- und Eingestellt-Tab zeigen
    local isListed = (activeTab == "listed")
    if AHSalesLogFrame and AHSalesLogFrame.headerTimer then
        if isSold then
            AHSalesLogFrame.headerTimer:SetText(L("header_mail"))
            AHSalesLogFrame.headerTimer:Show()
        elseif isListed then
            AHSalesLogFrame.headerTimer:SetText(L("header_timer"))
            AHSalesLogFrame.headerTimer:Show()
        else
            AHSalesLogFrame.headerTimer:Hide()
        end
    end

    for _, row in ipairs(rowFrames) do row:Hide() end

    scrollChild:SetHeight(math.max(count * ROW_HEIGHT + 4, 1))

    local now = time()
    local totalCopper = 0
    local readyCopper = 0

    for i, entry in ipairs(data) do
        local row = rowFrames[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)
            row:EnableMouse(true)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            local function MakeRowFS(parent, anchor, anchorPt, offsetX, width, justify)
                local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", anchor, anchorPt, offsetX, 0)
                fs:SetWidth(width)
                fs:SetJustifyH(justify)
                fs:SetWordWrap(false)
                fs:SetMaxLines(1)
                return fs
            end

            row.ts     = MakeRowFS(row, row,        "LEFT",  2, COL_TS,     "LEFT")
            row.item   = MakeRowFS(row, row.ts,     "RIGHT", 4, colItem,    "LEFT")
            row.gold   = MakeRowFS(row, row.item,   "RIGHT", 4, COL_GOLD,   "RIGHT")
            row.silver = MakeRowFS(row, row.gold,   "RIGHT", 2, COL_SILVER, "RIGHT")
            row.copper = MakeRowFS(row, row.silver, "RIGHT", 2, COL_COPPER, "RIGHT")
            row.timer  = MakeRowFS(row, row.copper, "RIGHT", 4, COL_TIMER,  "CENTER")

            -- Custom Font anwenden
            ApplyFontToString(row.ts)
            ApplyFontToString(row.item)
            ApplyFontToString(row.gold)
            ApplyFontToString(row.silver)
            ApplyFontToString(row.copper)
            ApplyFontToString(row.timer)

            row:SetScript("OnEnter", function(self)
                if self.fullItem and self.fullItem ~= "" then
                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                    local tooltipLink = ResolveItemLink(self.itemName, self.fullItemLink)
                    if tooltipLink and tooltipLink ~= "" then
                        GameTooltip:SetHyperlink(tooltipLink)
                    else
                        GameTooltip:SetText(self.fullItem, 1, 1, 1)
                    end
                    if self.fullPrice ~= "" then
                        GameTooltip:AddLine(L("tooltip_price", self.fullPrice), 0.4, 1, 0.4)
                    end
                    GameTooltip:AddLine(self.fullTime, 0.6, 0.6, 0.6)
                    if AHSalesLogDB.settings.allowManualDelete then
                        GameTooltip:AddLine(L("tooltip_delete_hint"), 1, 0.8, 0.3)
                    end
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnMouseUp", function(self, button)
                if button ~= "RightButton" then return end
                if activeTab == "history" then return end
                if not AHSalesLogDB.settings.allowManualDelete then return end
                local list = (activeTab == "sold") and AHSalesLogDB.entries or AHSalesLogDB.pendingAuctions
                if self.entryIndex and list[self.entryIndex] then
                    local removedEntry = table.remove(list, self.entryIndex)
                    if removedEntry then
                        StartUndo(activeTab == "listed" and "listed" or "sold", {
                            { index = self.entryIndex, entry = removedEntry },
                        })
                    end
                    AHSalesLog_RefreshList()
                end
            end)

            rowFrames[i] = row
        end

        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, -(i-1) * ROW_HEIGHT - 2)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -(i-1) * ROW_HEIGHT - 2)
        row.item:SetWidth(colItem)
        row:Show()

        local theme = AHSalesLogDB.settings.theme
        local colors = THEME_COLORS[theme]
        if i % 2 == 0 then
            if colors then
                row.bg:SetColorTexture(unpack(colors.rowEven))
            else
                row.bg:SetColorTexture(1, 1, 1, 0.05)
            end
        else
            if colors then
                row.bg:SetColorTexture(unpack(colors.rowOdd))
            else
                row.bg:SetColorTexture(0, 0, 0, 0)
            end
        end

        local displayTime  = entry.time or ""
        local displayItem  = entry.item or ""
        local entryCount   = entry.count or 1
        if entryCount > 1 then
            displayItem = displayItem .. " x" .. entryCount
        end
        local displayPrice = entry.priceStr or entry.price or ""
        local copper = entry.buyout or 0

        row.fullItem  = displayItem
        row.itemName  = entry.item or ""
        row.fullItemLink = entry.itemLink
        row.fullPrice = displayPrice
        row.fullTime  = displayTime
        row.entryIndex = i

        row.ts:SetText(displayTime)
        row.ts:SetTextColor(0.6, 0.6, 0.6)

        local isExpired = entry.expired
        if isExpired then
            row.item:SetText(displayItem .. L("row_expired_suffix"))
            row.item:SetTextColor(0.6, 0.6, 0.6)
        else
            row.item:SetText(displayItem)
            row.item:SetTextColor(1, 0.82, 0)
        end

        local priceColor
        if isExpired then
            priceColor = {0.5, 0.5, 0.5}
        elseif copper > 0 or displayPrice ~= "" then
            priceColor = (isSold or isHistory) and {0.4, 1, 0.4} or {1, 0.82, 0}
        else
            priceColor = {0.5, 0.5, 0.5}
        end
        local gVal, sVal, cVal = SplitCopper(copper)
        if isExpired then
            row.gold:SetText("--")
            row.gold:SetTextColor(unpack(priceColor))
            row.silver:SetText("")
            row.copper:SetText("")
        else
            row.gold:SetText(gVal > 0 and (gVal .. ICON_GOLD) or "")
            row.gold:SetTextColor(unpack(priceColor))
            row.silver:SetText(sVal > 0 and (sVal .. ICON_SILVER) or "")
            row.silver:SetTextColor(unpack(priceColor))
            row.copper:SetText(cVal > 0 and (cVal .. ICON_COPPER) or "")
            row.copper:SetTextColor(unpack(priceColor))
            if copper == 0 and displayPrice == "" then
                row.gold:SetText("--")
            end
        end

        -- Timer (Verkauft- und Eingestellt-Tab)
        if isSold then
            row.timer:Show()
            local soldAt = entry.soldAt or 0
            local remaining = MAIL_DELAY - (now - soldAt)
            row.timer:SetText(FormatTimer(remaining))
            if remaining <= 0 then
                row.timer:SetTextColor(0.4, 1, 0.4)
            else
                row.timer:SetTextColor(1, 0.6, 0.2)
            end
        elseif isListed then
            row.timer:Show()
            local posted = entry.posted or 0
            local dur = entry.duration or 172800
            local remaining = dur - (now - posted)
            row.timer:SetText(FormatTimer(remaining, L("timer_expired")))
            if remaining <= 0 then
                row.timer:SetTextColor(1, 0.3, 0.3)
            elseif remaining < 3600 then
                row.timer:SetTextColor(1, 0.6, 0.2)
            else
                row.timer:SetTextColor(0.6, 0.8, 1)
            end
        else
            row.timer:Hide()
        end

        -- Summe berechnen
        if copper > 0 and not entry.expired then
            totalCopper = totalCopper + copper
            if isSold then
                local soldAt = entry.soldAt or 0
                if (now - soldAt) >= MAIL_DELAY then
                    readyCopper = readyCopper + copper
                end
            end
        end
    end

    if AHSalesLogFrame then
        if AHSalesLogFrame.countLabel then
            AHSalesLogFrame.countLabel:SetText(L("count_entries_fmt", count))
        end
        if AHSalesLogFrame.sumLabel then
            if totalCopper > 0 then
                local sumText = L("sum_prefix") .. FormatMoneyIcons(totalCopper)
                if isSold and readyCopper > 0 and readyCopper < totalCopper then
                    sumText = sumText .. L("sum_ready_fmt", FormatMoneyIcons(readyCopper))
                elseif isSold and readyCopper > 0 and readyCopper == totalCopper then
                    sumText = sumText .. L("sum_all_ready")
                end
                AHSalesLogFrame.sumLabel:SetText(sumText)
                if isSold or isHistory then
                    AHSalesLogFrame.sumLabel:SetTextColor(0.4, 1, 0.4)
                else
                    AHSalesLogFrame.sumLabel:SetTextColor(1, 0.82, 0)
                end
            else
                AHSalesLogFrame.sumLabel:SetText("")
            end
        end
    end
end

-- ============================================================
-- Timer-Update: aktualisiert die Timer-Spalte jede Sekunde
-- ============================================================

local timerFrame = CreateFrame("Frame")
local timerElapsed = 0
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed < 1 then return end
    timerElapsed = 0

    if undoState.active then
        if GetUndoSecondsLeft() <= 0 then
            ClearUndoState()
        else
            UpdateUndoButton()
        end
    end

    if not AHSalesLogFrame or not AHSalesLogFrame:IsShown() then return end

    local now = time()

    if activeTab == "sold" then
        local entries = AHSalesLogDB.entries
        for i, entry in ipairs(entries) do
            local row = rowFrames[i]
            if row and row:IsShown() and row.timer then
                local soldAt = entry.soldAt or 0
                local remaining = MAIL_DELAY - (now - soldAt)
                row.timer:SetText(FormatTimer(remaining))
                if remaining <= 0 then
                    row.timer:SetTextColor(0.4, 1, 0.4)
                else
                    row.timer:SetTextColor(1, 0.6, 0.2)
                end
            end
        end
    elseif activeTab == "listed" then
        local pending = AHSalesLogDB.pendingAuctions
        local needRefresh = false
        for i = #pending, 1, -1 do
            local entry = pending[i]
            local dur = entry.duration or 172800
            local remaining = dur - (now - (entry.posted or 0))
            local row = rowFrames[i]
            if row and row:IsShown() and row.timer then
                row.timer:SetText(FormatTimer(remaining, L("timer_expired")))
                if remaining <= 0 then
                    row.timer:SetTextColor(1, 0.3, 0.3)
                elseif remaining < 3600 then
                    row.timer:SetTextColor(1, 0.6, 0.2)
                else
                    row.timer:SetTextColor(0.6, 0.8, 1)
                end
            end
            -- Abgelaufene Auktionen in Verlauf verschieben
            if remaining <= 0 then
                table.insert(AHSalesLogDB.history, 1, {
                    time   = entry.time,
                    item   = entry.item,
                    itemLink = entry.itemLink,
                    price  = entry.priceStr or FormatMoney(entry.buyout or 0),
                    buyout = 0,
                    soldAt = (entry.posted or 0) + dur,
                    count  = entry.count or 1,
                    expired = true,
                })
                table.remove(pending, i)
                needRefresh = true
            end
        end
        if needRefresh then
            AHSalesLog_RefreshList()
        end
    end
end)

-- ============================================================
-- Minimap-Button
-- ============================================================

local function SetMinimapPos(btn)
    local rad = math.rad(AHSalesLogDB.minimapAngle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "AHSalesLogMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    bg:SetSize(56, 56)
    bg:SetPoint("CENTER")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local badge = CreateFrame("Frame", nil, btn)
    badge:SetSize(14, 14)
    badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    badge:SetFrameLevel(btn:GetFrameLevel() + 2)

    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetColorTexture(0.8, 0.1, 0.1, 1)
    badgeBg:SetAllPoints()

    local badgeText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badgeText:SetPoint("CENTER")
    badgeText:SetTextColor(1, 1, 1)

    btn.badge     = badge
    btn.badgeText = badgeText
    badge:Hide()

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L("minimap_title"), 1, 1, 1)
        GameTooltip:AddLine(L("minimap_toggle"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("minimap_drag"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function()
        if AHSalesLogFrame:IsShown() then
            AHSalesLogFrame:Hide()
        else
            unseenCount = 0
            UpdateMinimapBadge()
            AHSalesLog_RefreshList()
            AHSalesLogFrame:Show()
            AHSalesLogFrame:Raise()
        end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function(s)
            if not s.dragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            AHSalesLogDB.minimapAngle = math.deg(math.atan2(cy/scale - my, cx/scale - mx))
            SetMinimapPos(s)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    minimapBtn = btn
    SetMinimapPos(btn)
end

-- ============================================================
-- Mini-Widget: kleines dauerhaftes Statusfenster
-- ============================================================

function FlashMiniWidget()
    if not miniWidget or not miniWidget.flashBg then return end
    local flash = miniWidget.flashBg
    flash:SetAlpha(0.6)
    flash:Show()
    local elapsed = 0
    miniWidget.flashFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local alpha = 0.6 * math.max(0, 1 - elapsed / 0.8)
        if alpha <= 0 then
            flash:Hide()
            self:SetScript("OnUpdate", nil)
        else
            flash:SetAlpha(alpha)
        end
    end)
end

function LayoutMiniWidget()
    if not miniWidget then return end
    local w = miniWidget
    local layout = AHSalesLogDB.settings.miniWidgetLayout or "side"
    local scale = AHSalesLogDB.settings.miniWidgetScale or 1.0
    w:SetScale(scale)

    w.itemText:ClearAllPoints()
    w.priceText:ClearAllPoints()

    if layout == "stack" then
        w:SetSize(150, 36)
        w.itemText:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -4)
        w.itemText:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -4)
        w.priceText:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 6, 4)
        w.priceText:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -6, 4)
        w.priceText:SetJustifyH("LEFT")
    else
        w:SetSize(210, 22)
        w.priceText:SetPoint("RIGHT", w, "RIGHT", -6, 0)
        w.priceText:SetJustifyH("RIGHT")
        w.itemText:SetPoint("LEFT", w, "LEFT", 6, 0)
        w.itemText:SetPoint("RIGHT", w.priceText, "LEFT", -4, 0)
    end
end

function UpdateMiniWidget()
    if not miniWidget then return end
    local entries = AHSalesLogDB.entries
    local lastEntry = entries[1]
    local totalSales = #entries
    local lastSeen = AHSalesLogDB.lastSeenSaleCount or 0
    local newCount = math.max(0, totalSales - lastSeen)

    if lastEntry then
        miniWidget.itemText:SetText(lastEntry.item or "?")
        if lastEntry.buyout and lastEntry.buyout > 0 then
            miniWidget.priceText:SetText(FormatMoneyIcons(lastEntry.buyout))
        else
            miniWidget.priceText:SetText("")
        end
    else
        miniWidget.itemText:SetText(L("miniwidget_empty"))
        miniWidget.priceText:SetText("")
    end

    if newCount > 0 then
        miniWidget.newBadge:Show()
        miniWidget.newText:SetText(newCount > 9 and "9+" or tostring(newCount))
    else
        miniWidget.newBadge:Hide()
    end
end

local function CreateMiniWidget()
    local w = CreateFrame("Frame", "AHSalesLogMiniWidget", UIParent)
    w:SetSize(210, 22)
    w:SetFrameStrata("MEDIUM")
    w:SetClampedToScreen(true)
    w:EnableMouse(true)

    -- Rahmen
    local border = w:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.0, 0.0, 0.0, 0.9)

    -- Hintergrund
    local bg = w:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.0, 0.0, 0.0, 0.0)

    -- "Neu"-Badge (Kreis oben rechts)
    local newBadge = CreateFrame("Frame", nil, w)
    newBadge:SetSize(20, 20)
    newBadge:SetPoint("TOPRIGHT", w, "TOPRIGHT", 8, 8)
    newBadge:SetFrameLevel(w:GetFrameLevel() + 2)
    local nbBg = newBadge:CreateTexture(nil, "BACKGROUND")
    nbBg:SetAllPoints()
    nbBg:SetColorTexture(0.85, 0.15, 0.1, 0.95)
    local newText = newBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    newText:SetPoint("CENTER")
    newText:SetTextColor(1, 1, 1)
    newBadge:Hide()
    w.newBadge = newBadge
    w.newText = newText

    -- Flash-Effekt bei neuem Verkauf
    local flashBg = w:CreateTexture(nil, "ARTWORK")
    flashBg:SetAllPoints()
    flashBg:SetColorTexture(0.4, 1, 0.4, 0.6)
    flashBg:Hide()
    w.flashBg = flashBg
    w.flashFrame = CreateFrame("Frame", nil, w)

    -- Preis
    local priceText = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceText:SetJustifyH("RIGHT")
    priceText:SetWordWrap(false)
    priceText:SetMaxLines(1)
    priceText:SetTextColor(0.4, 1, 0.4)
    w.priceText = priceText

    -- Item
    local itemText = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemText:SetJustifyH("LEFT")
    itemText:SetWordWrap(false)
    itemText:SetMaxLines(1)
    itemText:SetTextColor(1, 0.82, 0)
    w.itemText = itemText

    -- Maus-Events: STRG+Ziehen = verschieben, Klick = Hauptfenster
    w:SetMovable(true)
    w:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            self.isDragging = true
            self:StartMoving()
        else
            self.isDragging = false
        end
    end)
    w:SetScript("OnMouseUp", function(self, button)
        if self.isDragging then
            self:StopMovingOrSizing()
            local point, _, _, x, y = self:GetPoint()
            AHSalesLogDB.miniWidgetPos = { point = point, x = x, y = y }
            self.isDragging = false
            return
        end
        if button == "LeftButton" and AHSalesLogFrame then
            if AHSalesLogFrame:IsShown() then
                AHSalesLogFrame:Hide()
            else
                unseenCount = 0
                UpdateMinimapBadge()
                AHSalesLog_RefreshList()
                AHSalesLogFrame:Show()
                AHSalesLogFrame:Raise()
                AHSalesLogDB.lastSeenSaleCount = #AHSalesLogDB.entries
                UpdateMiniWidget()
            end
        end
    end)

    -- Tooltip
    w:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L("miniwidget_title"), 1, 1, 1)
        GameTooltip:AddLine(L("miniwidget_open"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("miniwidget_move"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)

    miniWidget = w
    w:Hide()
end

local function ShowMiniWidget()
    if not miniWidget then CreateMiniWidget() end
    local pos = AHSalesLogDB.miniWidgetPos
    miniWidget:ClearAllPoints()
    miniWidget:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    miniWidget:SetAlpha(AHSalesLogDB.settings.miniWidgetAlpha)
    LayoutMiniWidget()
    UpdateMiniWidget()
    miniWidget:Show()
end

local function HideMiniWidget()
    if miniWidget then miniWidget:Hide() end
end

function ToggleMiniWidget()
    if AHSalesLogDB.settings.showMiniWidget then
        ShowMiniWidget()
    else
        HideMiniWidget()
    end
end

-- ============================================================
-- Toggle
-- ============================================================

local function ToggleFrame()
    if AHSalesLogFrame:IsShown() then
        AHSalesLogFrame:Hide()
    else
        unseenCount = 0
        UpdateMinimapBadge()
        AHSalesLog_RefreshList()
        AHSalesLogFrame:Show()
        AHSalesLogFrame:Raise()
        -- Mini-Widget: als "gesehen" markieren
        AHSalesLogDB.lastSeenSaleCount = #AHSalesLogDB.entries
        if miniWidget and miniWidget:IsShown() then
            UpdateMiniWidget()
        end
    end
end

-- ============================================================
-- Addon-Initialisierung
-- ============================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MAIL_SHOW")
eventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("NEW_AUCTION_UPDATE")
eventFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        InitDB()
        HookCancelAuction()
        HookTakeInboxMoney()
        CreateMainFrame()
        CreateMinimapButton()
        ApplyLocalization()
        ApplyTheme()
        ToggleMiniWidget()

        local pos = AHSalesLogDB.framePos
        AHSalesLogFrame:ClearAllPoints()
        AHSalesLogFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", AHSalesLog_ChatFilter)

        SLASH_AHSALESLOG1 = "/ahlog"
        SLASH_AHSALESLOG2 = "/ahsaleslog"
        SlashCmdList["AHSALESLOG"] = ToggleFrame

        SLASH_AHSALESLOGTEST1 = "/ahlogtest"
        SlashCmdList["AHSALESLOGTEST"] = function()
            table.insert(AHSalesLogDB.pendingAuctions, 1, {
                item     = "Schattenpanzerhelm",
                buyout   = 53210,
                priceStr = "5g 32s 10c",
                count    = 1,
                posted   = time(),
                time     = GetTimestamp(),
                duration = 24*3600,
            })
            local priceStr, copper = FindPendingPrice("Schattenpanzerhelm")
            AddEntry("Schattenpanzerhelm", priceStr, copper)
            print(L("msg_test_entry"))
        end

        SLASH_AHSALESLOGTEST2 = "/ahlogtest2"
        SlashCmdList["AHSALESLOGTEST2"] = function()
            table.insert(AHSalesLogDB.pendingAuctions, 1, {
                item     = "Tigeraugenfell",
                buyout   = 120000,
                priceStr = "12g",
                count    = 1,
                posted   = time(),
                time     = GetTimestamp(),
                duration = 12*3600,
            })
            if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
                AHSalesLog_RefreshList()
            end
            print(L("msg_test_listed"))
        end

        SLASH_AHSALESLOGDEBUG1 = "/ahlogdebug"
        SlashCmdList["AHSALESLOGDEBUG"] = function()
            print(L("msg_debug_header"))
            print(L("debug_line_version", ADDON_VERSION))
            print(L("debug_line_ah_open", ahIsOpen and L("debug_yes") or L("debug_no")))
            print(L("debug_line_get_sell_info", GetAuctionSellItemInfo and L("debug_present") or L("debug_missing")))
            print(L("debug_line_buyout_frame", BuyoutPrice and L("debug_present") or L("debug_missing")))
            print(L("debug_line_sell_item", pendingSellName or L("debug_empty")))
            print(L("debug_line_saved_buyout", FormatMoney(pendingSellBuyout)))
            print(L("debug_line_auctionator", Auctionator and Auctionator.Selling and L("debug_detected") or L("debug_not_present")))
            print(L("debug_line_pending", #AHSalesLogDB.pendingAuctions))
            print(L("debug_line_sold", #AHSalesLogDB.entries))
            if GetAuctionSellItemInfo then
                local n = GetAuctionSellItemInfo()
                print(L("debug_line_slot_live", n or L("debug_empty")))
            end
            if BuyoutPrice and MoneyInputFrame_GetCopper then
                print(L("debug_line_buyout_live", FormatMoney(MoneyInputFrame_GetCopper(BuyoutPrice) or 0)))
            end
        end

        local atrLoaded = TryRegisterAuctionator()
        if atrLoaded then
            print(L("msg_auctionator_detected"))
        end

        print(L("msg_loaded_fmt", ADDON_VERSION))

    elseif event == "AUCTION_HOUSE_SHOW" then
        ahIsOpen = true
        pollFrame:Show()
        HookCancelAuction()
        pendingSyncRequested = true
        RequestOwnedAuctionsUpdate()
        -- Zweiter Versuch: Auctionator könnte nach uns geladen worden sein
        if not auctionatorRegistered then
            TryRegisterAuctionator()
        end
        pendingSellName  = nil
        pendingSellLink  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0

    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahIsOpen = false
        pollFrame:Hide()
        pendingSellName  = nil
        pendingSellLink  = nil
        pendingSellCount = nil
        pendingSellBuyout = 0

    elseif event == "NEW_AUCTION_UPDATE" then
        OnAuctionSlotChanged()

    elseif event == "AUCTION_OWNED_LIST_UPDATE" then
        if pendingSyncRequested then
            pendingSyncRequested = false
            ReconcilePendingWithOwnedAuctions()
        end

    elseif event == "MAIL_SHOW" then
        HookTakeInboxMoney()
        UpdateMailCache()
        -- Auto-Clean: bereite Einträge im Verkauft-Tab entfernen
        if AHSalesLogDB.settings.autoCleanSold then
            local now = time()
            local entries = AHSalesLogDB.entries
            local removed = 0
            local removedEntries = {}
            for i = #entries, 1, -1 do
                if (now - (entries[i].soldAt or 0)) >= MAIL_DELAY then
                    local removedEntry = table.remove(entries, i)
                    if removedEntry then
                        table.insert(removedEntries, { index = i, entry = removedEntry })
                    end
                    removed = removed + 1
                end
            end
            if removed > 0 then
                StartUndo("sold", removedEntries)
                print(L("msg_auto_removed_fmt", removed))
                if AHSalesLogFrame and AHSalesLogFrame:IsShown() then
                    AHSalesLog_RefreshList()
                end
            end
        end

    elseif event == "MAIL_INBOX_UPDATE" then
        UpdateMailCache()
        ScanMailbox()
    end
end)
