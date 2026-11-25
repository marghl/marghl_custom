# Ideen für Spielerstatus und Nametags

Vorläufiger Stand – noch nicht umgesetzt.

## Statusanzeige

- Automatisch erkannte Untätigkeit wird als `idle` in Gelb angezeigt.
- Der mit `/afk` gesetzte Status wird als `afk` in Rot angezeigt.
- Beide Status verschwinden automatisch bei erneuter Spieleraktivität.
- Der technische Spielername bleibt unverändert; nur die sichtbare Anzeige wird ergänzt.

## Sichtweite

- Nametags sollen nur innerhalb einer konfigurierbaren Entfernung sichtbar sein.
- Der vorgesehene Standardwert beträgt ungefähr 100 Blöcke.
- Die Sichtweite soll ausschließlich den Nametag betreffen, nicht die Sichtbarkeit oder
  Übertragung des gesamten Spielers.

## Offene technische Punkte

- Eine eigene HUD- oder Nametag-Lösung kann nötig sein, damit die Entfernung exakt
  eingehalten wird, ohne den gesamten Spieler auszublenden.
- Die Statusquelle ist `marghl_custom.player_status`; die spätere Anzeige soll diese
  verwenden und keine zweite Idle-/AFK-Erkennung einführen.
