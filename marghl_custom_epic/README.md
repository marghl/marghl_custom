# Marghl Custom Epic

Diese Mod erweitert `epic`, ohne dessen Dateien zu veraendern.

- `Epic Savegame Check block`: Bedingung fuer einen Branch. Sie ist erfolgreich,
  wenn beim aktuellen Spieler der konfigurierte Speicherstand aus `Topic` und
  `Name` existiert.
- `Epic Automatic Savegame Load block`: Laedt denselben Speicherstand ohne
  Auswahlfenster. Ein Epic-Ziel setzt die Ausfuehrung dort fort; ein anderes
  Ziel teleportiert den Spieler wie der originale Load-Block.
- `Epic Exact Inventory Check block`: Prueft, ob das gesamte Hauptinventar des
  Spielers exakt die in seinen acht Plaetzen abgelegten Gegenstaende und Mengen
  enthaelt. Zusaetzliche oder fehlende Gegenstaende lassen die Bedingung
  fehlschlagen. Die Slotpositionen sind egal und nichts wird verbraucht.
- `Epic Grow Tree block`: Erzeugt beim Ausfuehren sofort die ausgewaehlte
  Baumart. Mit `Set ground position` wird der Boden unter dem kuenftigen Stamm
  angeschlagen. Verfuegbar sind Apfel-, Dschungel-, Urwald-, Kiefern-,
  Schneekiefern-, Akazien- und Espenbaeume.
- `Epic Dig Check block`: Ueberwacht ab dem Erreichen der Bedingung den zuvor
  ausgewaehlten Node. Nur wenn der Spieler der laufenden Epic genau diesen Node
  selbst abbaut, wird der Branch fortgesetzt. Andere Spieler sowie WorldEdit
  oder ein blosses Ersetzen des Nodes zaehlen nicht.
- `Epic Dialogue Text block`: Wird zusammen mit den normalen
  `epic:dialogue`-Bloecken in die Bedingungsflaeche eines Branches gesetzt. Sein
  Text erscheint als nicht anklickbares Textfeld oberhalb der Dialogantworten.
  Der Block ist eine dauerhaft falsche Branch-Bedingung: Er ruft niemals den
  eigenen Ablaufpfad auf und beeinflusst nur die gemeinsame Dialog-Formspec.
- Normale `epic:dialogue`-Bloecke erhalten durch diese Mod ein mehrzeiliges
  Eingabefeld. Echte Zeilenumbrueche bleiben auch in den auswaehlbaren Antworten
  erhalten. Die Originaldateien von `epic` werden dabei nicht veraendert.
- `Epic Button`: Fuegt dem gemeinsamen Dialogsystem eine breite, frei
  beschriftbare Schaltflaeche hinzu. Dadurch kann sie im selben Branch zusammen
  mit `Epic Dialogue Text` verwendet werden. Ein Klick erfuellt die Bedingung
  und setzt den Ablauf hinter dem Button fort; Schliessen bricht den Epic ab.

Alle Bloecke enthalten `Epic` im sichtbaren Namen und sind deshalb im
Craftingguide mit dem Suchwort `epic` auffindbar. `Topic` und `Name` muessen
genau mit dem verwendeten `epic:save`-Block uebereinstimmen.
