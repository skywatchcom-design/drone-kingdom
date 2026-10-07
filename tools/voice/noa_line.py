"""Records one of Noa's lines in her Gemini voice (Leda), in Hebrew and English, checks every take
by transcribing it, keeps the closest one and writes assets/audio/noa/<lang>_<key>.ogg.

    python tools/voice/noa_line.py <key> "<Hebrew line>" "<English line>" [--spoken-he "<text to say>"]

--spoken-he is what the voice reads when the written Hebrew trips it (abbreviations such as חי"ר,
names that need niqqud). The key is read from tmp/gemini_key.txt. The free tier allows about ten
recordings per model per day, so the script moves to the next model when one runs out.
Never put a style instruction in the text: the voice reads it aloud (and the Hebrew then comes out
with an English accent). The language is set with languageCode instead.
"""
import base64, difflib, json, os, re, subprocess, sys, time, urllib.error, urllib.request, wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KEY = open(os.path.join(ROOT, "tmp", "gemini_key.txt"), encoding="utf-8-sig").read().strip()
TTS_MODELS = ["gemini-3.1-flash-tts-preview", "gemini-2.5-flash-preview-tts", "gemini-2.5-pro-preview-tts"]
STT_MODELS = ["gemini-3.7-flash", "gemini-3.5-flash-lite", "gemini-3.5-flash", "gemini-3.1-flash-lite"]
VOICE = "Leda"
OUT = os.path.join(ROOT, "assets", "audio", "noa")
TMP = os.path.join(ROOT, "tmp", "voice")
spent = set()


def _post(model, body):
    req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(body).encode(), headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=180))


def speak(text, lang, path):
    """Writes a wav of `text`; False when every model is out of quota."""
    body = {"contents": [{"parts": [{"text": text}]}], "generationConfig": {"responseModalities": ["AUDIO"],
        "speechConfig": {"languageCode": lang, "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": VOICE}}}}}
    for model in TTS_MODELS:
        if model in spent:
            continue
        try:
            d = _post(model, body)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                spent.add(model)
            print("  tts", model, e.code)
            continue
        pcm = base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
        with wave.open(path, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(pcm)
        return True
    return False


def hear(path):
    data = base64.b64encode(open(path, "rb").read()).decode()
    body = {"contents": [{"parts": [{"text": "Transcribe this audio exactly, nothing else."},
        {"inline_data": {"mime_type": "audio/wav", "data": data}}]}]}
    for i in range(8):
        try:
            return _post(STT_MODELS[i % len(STT_MODELS)], body)["candidates"][0]["content"]["parts"][0]["text"].strip()
        except Exception:
            time.sleep(5)
    return ""


def words(t):
    return re.sub(r"[^\w ]", "", t.lower()).split()


def record(key, lang, written, spoken):
    best = (-1.0, None, "")
    for attempt in range(3):
        wav = os.path.join(TMP, f"{lang}_{key}_{attempt}.wav")
        if not speak(spoken, "he-IL" if lang == "he" else "en-US", wav):
            print("  all voice models are out of quota for today")
            break
        heard = hear(wav)
        score = difflib.SequenceMatcher(None, words(written), words(heard)).ratio()
        print(f"  {lang} take {attempt}: {score:.2f}  {heard}")
        if score > best[0]:
            best = (score, wav, heard)
        if score >= 0.95:
            break
        time.sleep(5)
    if best[1] is None:
        return False
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", best[1], "-af",
        "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
        "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, f"{lang}_{key}.ogg")], check=True)
    print(f"  kept {lang}_{key}.ogg (match {best[0]:.2f})")
    return True


def main():
    args = sys.argv[1:]
    spoken_he = None
    if "--spoken-he" in args:
        i = args.index("--spoken-he")
        spoken_he = args[i + 1]
        del args[i:i + 2]
    key, he, en = args
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    record(key, "he", he, spoken_he or he)
    record(key, "en", en, en)


if __name__ == "__main__":
    main()
