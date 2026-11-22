# Piano Letters

Letter-note piano sheets for children, for viewing and playing along on an iPad. Open the GitHub Pages address in Safari, then Share, Add to Home Screen.

- `my-sheets.json` (optional): the file made by **Export for iPad** in the Piano Letter Sheets page. Put it here to send your own sheets to every installed copy.
- `songs/*.abc`: songs added to My sheets. Run `node tools/build-sheets.mjs` to rebuild `my-sheets.json`, then push. On the iPad: Add or update, Check for update. See CLAUDE.md.
- Everything else is built; replace the files to update the app.

## Credits

- Mozart, Haydn, Scarlatti and Joplin scores: Craig Stuart Sapp, KernScores, CC BY-NC-SA 4.0 (https://creativecommons.org/licenses/by-nc-sa/4.0). Simplified here. Non-commercial use only, same license for adaptations.
- Other scores: Mutopia Project (https://www.mutopiaproject.org), public domain or Creative Commons as named with each piece. Simplified here.
- Songs: traditional and public-domain melodies.
