# The landing page

Plain HTML, no build step. `.github/workflows/pages.yml` publishes this folder
at the site root and the Flutter build under `play/`, so
`https://3shmawi.github.io/waraya/` is the introduction and
`https://3shmawi.github.io/waraya/play/` is the game.

Everything it needs is in here, including its own copy of Cairo and its own
copy of the screenshot. That is deliberate: a static page reaching into a
Flutter build's internal asset layout breaks the first time that layout
changes, and opening `index.html` straight off disk should look right.

The OFL requires the licence to travel with the font, which is why
`fonts/Cairo-LICENSE.txt` is here as well as in `assets/`. `test/app/fonts_test.dart`
pins the same rule for the bundled copy.
