# levels/

Levels being written, as JSON, one per file. The bench reads this folder:

```sh
flutter run -t lib/main_lab.dart --dart-define=WARAYA_LEVELS=levels/
```

The folder button on the bench reads it again without restarting, and the
cloud button sends the level on screen to be judged and published
(docs/phase-8-server.md).

`try-the-upload.json` is "stand on yourself" under a new id — a level the
gate passes, for trying the upload end to end. To see the upload refused,
delete the last move of its `solution`, press the folder button, and send it
again.

The shipped campaign is not here: it is written in Dart, in
`lib/level/levels.dart`, where the compiler checks it.
