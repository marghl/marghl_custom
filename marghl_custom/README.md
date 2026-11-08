# Marghl Custom Tutorial

- `/tutorial_set_start`: Setzt den alternativen Startpunkt fuer neue Spieler.
- `/tutorial_set_spawn`: Setzt das Ziel nach Abschluss. Ohne eigenen Wert wird
  `static_spawnpoint` verwendet.
- `/tutorial_reset <Spielername>`: Setzt einen angemeldeten Spieler auf den
  Tutorialstatus zurueck.
- `marghl_custom:tutorial_exit`: Gelber Endblock mit einstellbarem Radius.

## AFK-Kick

Die Aktivitaetserkennung kommt aus `afk_api`. Standardmaessig wird ein Spieler
nach 270 Sekunden einmal gewarnt und nach 300 Sekunden Inaktivitaet getrennt.
Das Privileg `allow_afk` nimmt einen Spieler vollstaendig davon aus.

- `marghl_custom_afk_kick_time`: Inaktivitaet bis zur Trennung in Sekunden.
- `marghl_custom_afk_warning_time`: Abstand zwischen Warnung und Trennung; `0`
  deaktiviert die Warnung.

Verwaltungsbefehle sowie Platzieren, Entfernen und Konfigurieren des Endblocks
erfordern das Privileg `server`. Das Tutorial veraendert keine Spielerrechte.
# Uebersetzungen

Die sichtbaren Texte des Tutorial-Mods verwenden die Textdomain
`marghl_custom`. Neue Quelltexte werden in
`locale/marghl_custom.pot` aufgenommen; die deutsche Uebersetzung liegt in
`locale/marghl_custom.de.po`.
