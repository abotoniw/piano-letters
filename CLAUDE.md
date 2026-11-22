# Piano Letters: adding songs

The owner adds songs by naming them in chat ("add <song>"). The iPad app picks them up when they tap
**Add or update → Check for update**, which downloads `my-sheets.json` from GitHub Pages
(`https://abotoniw.github.io/piano-letters/`). No app rebuild or Xcode step is needed.

## Workflow for "add <song>"

1. **Copyright first.** Only public-domain or traditional melodies go in this repository, because it is
   public. A melody whose composer died less than 70 years ago, or any film, TV or pop song, is out. Say so
   and do not write it out. Suggest the owner buys a licensed easy-piano arrangement instead.
2. **Find the melody in a reliable source**: Mutopia, IMSLP, abcnotation.com, The Session, or a MIDI file of
   the original. Do not rely on memory alone. Cross-check the notes against that source and name the source
   in the `S:` line.
3. **Write `songs/<slug>.abc`** with `X:1`, `T:` (title), `C:` (composer and year, or Traditional), `S:` (source),
   `M:`, `L:`, `Q:`, `K:`, and the melody. Melody only: the app adds the left-hand chords and moves the song to an
   easy key itself. Use `|: :|` and `[1 [2` for repeats.
4. **Build:** `node tools/build-sheets.mjs --shot`. This uses the app's own reader in headless Chromium, so a
   song that passes opens on the iPad. Look at `shots/repo-<slug>.png` and check the notes against the source.
5. **Commit and push to `main`** (the owner approved pushing songs directly): the `.abc` file and `my-sheets.json`.
   Do not commit `shots/`.
6. Tell the owner to wait 1–2 minutes for GitHub Pages, then tap **Add or update → Check for update**.
   The song appears under **My sheets**.

## Notes

- To fix a song, edit its `.abc` and rebuild. Its `updated` date changes, so the iPad replaces its copy.
- Deleting a `.abc` file does not remove the song from iPads that already have it. The owner deletes it in the app.
- Do not edit `index.html`, `data/` or `version.json` for a song. App changes need a new `version.json`
  (sha256 of every file) or the native app will not install them.
