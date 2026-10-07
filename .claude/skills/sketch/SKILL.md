---
name: sketch
description: Make a live sketch (Artifact page) for a new screen, character or big design change in the SkyWatch game, drawn over real game screenshots with 2-3 working directions for the owner to pick. Use before building any new screen or major visual change, or when the owner says /sketch or "סקיצה".
---

# Sketch before building

Rule (owner, 7.10.2026): new screens, characters and big design changes get a sketch first;
small UI fixes go straight into the game and are shown with an in-game screenshot.

1. **Real backgrounds**: capture the actual screen with the movie writer (see /ship step 2), e.g.
   `--fresh --tutorial -1` for the base, and copy pictures from `assets/textures/pictures`,
   `assets/textures/noa`. Put everything in `tmp/<sketch-name>/img`.
2. **Write the page** in Hebrew (`dir="rtl"`), one 16:9 game frame on top using container query units
   (`cqw`) so it scales like the game, tabs to switch between **2-3 directions**, and short notes
   per direction plus open decisions below. Everything should work (type, click, switch), with the
   game's real names and numbers. Follow the artifact-design skill; a single dark look is fine.
3. Check it once in the browser pane (`python -m http.server` in the folder; add
   `<meta charset="utf-8">` while testing locally and remove it before publishing), then publish
   with the Artifact tool, passing the images as `files`.
4. Tell the owner in Hebrew what each direction is and ask which one (multiple choice). After the
   choice, build it and note the approval with the link in CLAUDE.md ("Approved <date>: ...").
