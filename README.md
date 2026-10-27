# Marghl Custom

Dieses Modpack buendelt kleine, lokale Erweiterungen, ohne die einzelnen
Funktionsbereiche miteinander zu vermischen.

## Enthaltene Mods

- `marghl_custom`: Tutorial fuer neue Spieler. Der bisherige Modname und der
  Node `marghl_custom:tutorial_exit` bleiben erhalten, damit vorhandene Bloecke
  und gespeicherte Positionen weiter funktionieren.
- `marghl_custom_weather`: Schaltet das Wetter in ausgewaehlten Areas aus.
- `marghl_custom_admin`: Administrative Diagnosebefehle.
- `marghl_custom_warehouse`: Weltweite leere Lagerhausschicht mit Bedrock-Boden
  bei `Y = -30000`.
- `marghl_custom_epic`: Epic-Bedingung und automatische Ladeaktion fuer
  benannte Speicherstaende.
- `marghl_custom_override`: Sammelt serverweite Anpassungen vorhandener Mods.
  Aktuell entfernt er die Rezepte und Guide-Eintraege fuer den
  Cottages-Amboss und -Hammer, ohne vorhandene Exemplare zu loeschen.

Alle Befehle und die genaue Bedienung stehen in den README-Dateien der
jeweiligen Untermods.

## Uebersetzungsstatus auflisten

`tools/list_translation_status.sh` durchsucht einen Mod-Ordner und gibt eine
tabulatorgetrennte Liste auf stdout aus. Dadurch kann die Ausgabe direkt in
Textdateien umgeleitet oder mit `awk` nach Status gefiltert werden.

## Git-Updates pruefen

`tools/check_mod_updates.sh` prueft jedes direkte Paketverzeichnis im
Mod-Ordner. Es gibt nur Pakete mit verfuegbarem Update (`Update`) und Pakete
ohne Git-Metadaten (`kein git`) aus. Aktuelle Git-Repositories erzeugen keine
Ausgabe. Abruf- und Konfigurationsfehler werden getrennt nach stderr
geschrieben.

## Inaktive Welt-Mods auflisten

`tools/list_inactive_world_mods.sh` vergleicht die installierten Mods mit
`world.mt`. Fuer jeden fehlenden, leeren oder deaktivierten `load_mod_*`-Eintrag
gibt es ausschliesslich den vollstaendigen Pfad des betreffenden Mods aus.
