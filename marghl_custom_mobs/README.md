# Marghl Custom Mobs

Erweitert die Mobs-Redo-Tiere, ohne deren bestehende Interaktionen zu ersetzen.

## Pferd zureiten

Ein erwachsenes, wildes `mob_horse:horse` wird mit leerer Hand bestiegen. Der
Spieler muss 15 Sekunden auf dem bockenden Pferd bleiben. Schleichen bricht den
Versuch ab. Nach einem Abwurf wird der naechste Versuch leichter. Futter heilt
ein wildes Pferd weiterhin, zaehmt es aber nicht mehr.

Nach erfolgreichem Zureiten funktionieren Sattel, Hufeisen, Schutzrune, Zucht
und magisches Lasso wie im Originalmod.

Der Eigentuemer kann mit einer `default:chest` 16 Inventarplaetze am Pferd
anbringen. Das Inventar wird anschliessend mit Schleichen und Rechtsklick bei
leerer Hand geoeffnet. Inhalt und Truhe werden beim Tod des Pferds
fallengelassen. Das Inventar bleibt beim Einfangen mit dem Lasso erhalten.

## Kuh und Warzenschwein reiten

`mobs_animal:cow` und `mobs_animal:pumba` werden weiterhin durch Fuettern
gezaehmt. Der Eigentuemer kann danach mit `mobs:saddle` einen dauerhaften Sattel
anlegen und das Tier anschliessend mit leerer Hand oder einem weiteren
Rechtsklick mit `mobs:saddle` besteigen. Beim Tod des Tiers wird der Sattel
fallengelassen.
