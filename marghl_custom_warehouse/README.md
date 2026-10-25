# Marghl Custom Warehouse

Die Mod erzeugt beim normalen Mapgen ueber die gesamte Weltbreite eine leere
Lagerhausschicht:

- Bedrock-Boden bei `Y = -30000`
- 1000 Nodes leerer Raum von `Y = -29999` bis einschliesslich `Y = -29000`
- Bedrock-Decke bei `Y = -28999`
- automatische einmalige Generierung und Migration der 80 x 1001 x 80 Nodes
  grossen Ursprungssaeule um `(0, -29999, 0)`
- durchgehend hellblaue Skybox ohne Sonne, Mond, Sterne, Wolken oder
  Tag-Nacht-Wechsel
- ein dauerhaftes dreidimensionales Raster aus unsichtbaren, bebaubaren
  Lichtquellen mit standardmaessig 6 Nodes Abstand; dazwischen liegt echte Luft

## Einstellung

- `warehouse_light_level`: Lichtstaerke der unsichtbaren Lichtnodes von `0` bis
  `14`, standardmaessig `14`. Sie kann beispielsweise mit
  `/set warehouse_light_level 10` gesetzt werden. Die neue Lichtstaerke wird
  nach einem Serverneustart wirksam. Anschliessend muss in bereits erzeugten
  Bereichen `/warehouse_fix_lighting` ausgefuehrt werden.

## Befehl

- `/warehouse_fix_lighting`: Entfernt das bisherige Lichtraster im aktuellen
  Mapgen-Chunk, setzt dort in freier Luft das dichtere Raster neu und berechnet
  die Beleuchtung. Bauten werden nicht ersetzt. Erfordert `server`.

Die Regeln gelten fuer neu generierte Weltbereiche. Bereits vorhandene
Mapblocks werden nicht nachtraeglich geleert.
Die abschliessende Warehouse-Bereinigung wird erst nach dem Laden aller Mods
registriert. Dadurch werden auch Fluessigkeiten, Loot-Truhen und andere
Strukturen entfernt, die andere Mapgen-Mods zuvor in einen neu erzeugten
Warehouse-Chunk gesetzt haben.
Bei der Erzeugung wird absichtlich kein Fluessigkeits-Update ausgefuehrt, damit
Wasser- oder Lava-Nodes nicht erneut in den geleerten Bereich fliessen.
Alle Nodes aus der Gruppe `liquid` werden innerhalb des Warehouse beim Laden
eines Mapblocks sowie einmal pro Sekunde in aktiven Bereichen durch Luft
ersetzt. Das gilt fuer Quellen und fliessende Varianten.
