---
name: noa-voice
description: Record a new or changed line for Noa, the SkyWatch tutorial officer, in her approved Gemini "Leda" voice in Hebrew and English, verified by transcription and saved as ogg. Use whenever Noa gets a new line or a line's text changes, or when the owner says /noa-voice.
---

# Record a line for Noa

1. Add or change the English line in `TutorialSteps.LINES` (or wherever the line is used) and its
   Hebrew in `scripts/core/i18n.gd`. Hebrew speaks in plural ("לחצו", "שלכם").
2. Run `python tools/voice/noa_line.py <key> "<Hebrew>" "<English>"`. It writes
   `assets/audio/noa/he_<key>.ogg` and `en_<key>.ogg`, the take whose transcription matches best.
   - When a Hebrew word is misread (abbreviations like חי"ר, names like ניב הברזל), pass
     `--spoken-he "<the line with niqqud or spelled out>"`.
   - Never add a style instruction to the text ("Say cheerfully: ..."): the voice reads it aloud.
   - The free tier gives about ten recordings per model per day; when all models are spent, say so
     and finish the rest the next day.
3. Every kept take prints its transcription. If a Hebrew take is still below about 0.9, tell the
   owner which line to listen to.
4. Re-import (`godot --headless --path . --import`) and continue with /ship.
