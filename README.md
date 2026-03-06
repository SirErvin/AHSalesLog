# AH Sales Log

Ein World of Warcraft Addon für **TBC Classic Anniversary**, das Auktionshaus-Verkäufe automatisch protokolliert.

## Features

### Verkäufe tracken
- Erkennt Verkäufe automatisch über den System-Chat
- Zeigt Item, Preis und Zeitstempel
- Countdown-Timer bis die Goldmail im Postfach ankommt
- Summe aller verkauften Items, inkl. separater Anzeige wie viel bereits abholbereit ist

### Eingestellt-Tab
- Zeigt alle aktuell laufenden Auktionen
- Erkennt automatisch die gewählte Laufzeit (12h / 24h / 48h)
- Live-Countdown bis die Auktion ausläuft
- Abgelaufene Auktionen werden automatisch in den Verlauf verschoben

### Verlauf
- Dauerhafter Log aller Verkäufe und abgelaufenen Auktionen
- Filterbar nach: Heute, Woche, Monat, Jahr, Alles
- Abgelaufene Auktionen werden grau mit "(abgelaufen)" markiert

### Mini-Widget
- Kleines dauerhaftes Fenster das den letzten Verkauf anzeigt
- Roter Badge für ungesehene Verkäufe
- Grüner Flash-Effekt bei neuem Verkauf
- STRG + Ziehen zum Verschieben
- Anpassbar: Größe, Transparenz, Layout (nebeneinander oder übereinander)

### Optionen
- **Design:** Classic, Dunkel, Clean Dark, Modern
- **Schriftart:** Standard, Friz QT, Arial, Morpheus, Skurri
- **Sprache:** Deutsch / English
- **Rechtsklick-Löschen:** Einzelne Einträge per Rechtsklick entfernen
- **Auto-Leeren:** Verkauft-Tab wird automatisch geleert wenn man das Postfach öffnet
- **Undo:** Gelöschte Einträge können innerhalb von 10 Sekunden wiederhergestellt werden

### Auctionator-Kompatibilität
Wird Auctionator erkannt, übernimmt das Addon dessen Events für präzisere Auktionserkennung — keine Doppeleinträge.

## Befehle

| Befehl | Funktion |
|---|---|
| `/ahlog` | Fenster öffnen / schließen |
| `/ahsaleslog` | Fenster öffnen / schließen |
| `/ahlogtest` | Testeintrag hinzufügen |
| `/ahlogdebug` | Debug-Informationen ausgeben |

## Installation

1. Ordner `AHSalesLog` in `World of Warcraft/_anniversary_/Interface/AddOns/` kopieren
2. Spiel starten oder `/reload` ausführen

## Interface-Version

`20505` — TBC Classic Anniversary

## Autor

Niklas Hiller (SirErvin)
