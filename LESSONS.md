# AHSalesLog – Lessons Learned

## TBC Classic Anniversary – Client-Infos
- Interface-Version: **20505** (nicht 20504 — falsche Version = Addon lädt nicht)
- Moderner Client (Shadowlands-Basis), daher modernere APIs verfügbar
- UTF-8 Encoding für Strings

---

## Lua Pattern Matching & UTF-8

**Problem:** Umlaute (ä, ö, ü) sind in UTF-8 **2 Bytes** — Lua's `.` matched aber nur **1 Byte**.

```lua
-- FALSCH: "K.ufer" matched NICHT "Käufer" in UTF-8
msg:match("K.ufer f.r Eure Auktion gefunden: (.+)")

-- RICHTIG: Schlüsselwort ohne Umlaute suchen
msg:match("gefunden: (.-)%s*$")
```

**Regel:** In WoW-Lua nie Umlaute im Pattern verwenden. Stattdessen einen Teil des Strings
nehmen, der keine Sonderzeichen enthält.

---

## ChatFrame_AddMessageEventFilter vs CHAT_MSG_SYSTEM

| | CHAT_MSG_SYSTEM | ChatFrame_AddMessageEventFilter |
|---|---|---|
| Itemname enthalten? | **Nein** | **Ja** |
| Feuert wie oft? | 1x | 1x **pro Chatframe** (oft 3x) |

**CHAT_MSG_SYSTEM** liefert nur "Es wurde ein Käufer für Eure Auktion gefunden" — kein Itemname.

**ChatFrame_AddMessageEventFilter** bekommt die **formatierte** Nachricht inkl. Itemname:
"Es wurde ein Käufer für Eure Auktion gefunden: Eisenerz"

Registrierung:
```lua
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", myFilterFunc)
```

Filter-Funktion gibt `false` zurück → Nachricht wird trotzdem angezeigt (nicht unterdrückt).

**Rate-Limiter nötig** um Doppeleinträge durch mehrere Chatframes zu verhindern:
```lua
local lastMsg, lastTime = nil, 0
local function MyFilter(_, _, msg)
    local now = GetTime()
    if msg ~= lastMsg or (now - lastTime) > 1.0 then
        lastMsg, lastTime = msg, now
        -- verarbeiten
    end
    return false
end
```

---

## UI-Fallstricke

### SetBackdrop
`frame:SetBackdrop({...})` funktioniert **nicht** im modernen Classic-Client → Addon bricht komplett.
Stattdessen: **`BasicFrameTemplateWithInset`** als Template verwenden.

### ScrollFrame – GetWidth() gibt 0 zurück
Wenn der ScrollFrame beim Erstellen noch `hidden` ist, gibt `sf:GetWidth()` `0` zurück.
**Fix:** Breite manuell berechnen statt `GetWidth()` zu verwenden:
```lua
sc:SetWidth(FRAME_WIDTH - PAD - (PAD + 20))  -- hardcoded
```

### SetColorTexture
Funktioniert in TBC Anniversary (moderner Client). In alten 2.4.3-Clients nicht verfügbar.

---

## Postfach-API (Mailbox)

```lua
-- Anzahl Mails
local n = GetInboxNumItems()

-- Mail-Header (Index ab 1)
-- Rückgabe: packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, ...
local _, _, sender, subject, money, _, daysLeft = GetInboxHeaderInfo(i)

-- money = Kupfer (1g = 10000, 1s = 100)
```

AH-Verkaufsmails: Sender = "Auktionshaus" (DE) / "Auction House" (EN), `money > 0`.

Event für Postfach-Daten bereit: **`MAIL_INBOX_UPDATE`** (nicht MAIL_SHOW, da Daten da noch nicht geladen).

**Dedup-Key** für gesehene Mails: `subject .. "|" .. money .. "|" .. floor(daysLeft * 100)`
(14-Minuten-Granularität reicht zur Unterscheidung)

---

## Auktions-Erstellung erkennen (Slot-Monitor)

**Problem:** `StartAuction()` und `PostAuction()` sind in TBC Classic Anniversary **nicht hookbar**
via `hooksecurefunc`. Weder `StartAuction` noch `PostAuction` existieren als globale Funktionen
zur Laufzeit (auch nicht nach `AUCTION_HOUSE_SHOW`). Das Blizzard AH-UI ist ein
Load-on-Demand Addon, aber die Posting-Funktion ist trotzdem nicht zugänglich.

**Lösung: Slot-Monitor via `NEW_AUCTION_UPDATE`**

Das Event `NEW_AUCTION_UPDATE` feuert zuverlässig wenn:
1. Ein Item in den Auktions-Sell-Slot gelegt wird
2. Der Sell-Slot geleert wird (nach Posten ODER Zurücknehmen)

Ablauf:
```lua
-- 1. Item im Slot → Name + Count merken
local name, _, count = GetAuctionSellItemInfo()
pendingSellName = name

-- 2. Buyout-Preis per Polling aus dem UI-Eingabefeld lesen (alle 0.2s)
--    BuyoutPrice ist ein MoneyInputFrame, der nach dem Posten geleert werden kann
local buyout = MoneyInputFrame_GetCopper(BuyoutPrice)

-- 3. Slot leer + kein Item am Cursor → Auktion wurde erstellt
local cursorType = GetCursorInfo()
if cursorType ~= "item" then
    -- Erfolgreich gepostet → pendingSellBuyout als Fallback nutzen
end
```

**Wichtig:**
- `BuyoutPrice` (MoneyInputFrame) kann nach dem Posten **sofort geleert** werden → daher den
  Wert per OnUpdate-Polling kontinuierlich zwischenspeichern
- `GetCursorInfo() == "item"` unterscheidet Zurücknehmen vs. erfolgreiches Posten
- `AUCTION_HOUSE_SHOW` / `AUCTION_HOUSE_CLOSED` zum Aktivieren/Deaktivieren des Pollings

**Was NICHT funktioniert:**
- `hooksecurefunc("StartAuction", ...)` — Funktion existiert nicht als Global
- `hooksecurefunc("PostAuction", ...)` — ebenfalls nicht vorhanden
- `HookScript("OnClick")` auf den Create-Button — feuert NACH dem Original-Handler,
  also nachdem `StartAuction` das Item bereits verbraucht hat (Timing-Problem)

---

## Projektverlauf

### v1 – Grundfunktion
- CHAT_MSG_SYSTEM Event + Pattern-Matching
- Problem: Raw-Event ohne Itemname, Pattern mit Umlauten schlug fehl

### v2 – SetBackdrop-Regression
- Versuch mit `SetBackdrop` für eigenes Fenster-Design
- Alles kaputt (Minimap weg, Slash-Commands tot)
- Revert auf `BasicFrameTemplateWithInset`

### v3 – Interface-Version-Fix
- 20504 → 20505 behoben (Addon lud gar nicht)

### v4 – ChatFrame_AddMessageEventFilter
- Filter empfängt formatierte Nachricht MIT Itemname ✓
- Pattern mit Umlauten schlug trotzdem fehl (UTF-8-Problem)

### v5 – UTF-8-Fix + Postfach
- Pattern auf `"gefunden: (.-)%s*$"` geändert → funktioniert ✓
- MAIL_INBOX_UPDATE für nachträgliche Preisanreicherung
- Postfach nur zum Preis-Enrichment, keine neuen Einträge vom Postfach

### v1.2–1.4 – Listungspreis-Tracking (fehlgeschlagene Ansätze)
- Versuch: `hooksecurefunc("PostAuction", ...)` → Funktion existiert nicht
- Versuch: `hooksecurefunc("StartAuction", ...)` → existiert ebenfalls nicht
- Versuch: Hook erst bei `AUCTION_HOUSE_SHOW` registrieren → StartAuction trotzdem nicht da
- Versuch: `HookScript("OnClick")` auf Create-Button → feuert nach dem Handler (zu spät)

### v1.5 – Slot-Monitor (funktioniert!)
- `NEW_AUCTION_UPDATE` + `GetAuctionSellItemInfo()` für Item-Name
- `MoneyInputFrame_GetCopper(BuyoutPrice)` per Polling für Sofortkaufpreis
- `GetCursorInfo()` zum Unterscheiden: Zurücknehmen vs. erfolgreiches Posten
- Zwei-Tab-UI: "Eingestellt" (pending) + "Verkauft" (sold)
- Item wandert bei Verkauf automatisch von einem Tab in den anderen
