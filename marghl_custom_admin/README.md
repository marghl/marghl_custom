# Marghl Custom Admin

- `/nodecount`: Zeigt die Anzahl registrierter Nodes und aller registrierten
  Items. Der Befehl erfordert das Privileg `server`.
- `/notice <Spieler> [Farbe|#RRGGBB] <Nachricht>`: Sendet eine private Nachricht
  ohne Absender oder Praefix. Die Farbe ist optional. Unterstuetzt werden
  `white`, `lightgray`, `gray`, `darkgray`, `black`, `red`, `orange`, `yellow`,
  `green`, `cyan`, `blue`, `violet`, `purple`, `magenta` und `pink`, ausserdem
  beliebige Hexfarben. Beispiele: `/notice Anna red Achtung!` und
  `/notice Anna #55AAFF Willkommen`. Ohne
  erkannten Farbnamen bleibt die bisherige ungefaerbte Verwendung erhalten.
  Der Befehl erfordert das Privileg `server`.
- `/servermsg <Nachricht>`: Sendet die Nachricht mit dem Praefix `[server]` an
  alle verbundenen Spieler. Der Befehl erfordert das Privileg `server`.
