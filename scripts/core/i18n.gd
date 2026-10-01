class_name I18n
extends RefCounted
## Tiny translation layer. Code is written with English strings as keys; t() returns the
## Hebrew version when the game runs in Hebrew. English stays the fallback for the global launch.

static var lang := "he"

const HE := {
	# Structures and drones
	"Command Tower": "מגדל פיקוד",
	"Solar Generator": "גנרטור סולארי",
	"Coin Silo": "סילו מטבעות",
	"Drone Hangar": "האנגר רחפנים",
	"Laser Tower": "מגדל לייזר",
	"Net Launcher": "משגר רשתות",
	"Jammer": "משבש",
	"Gull Nest": "קן שחפים",
	"Courier": "שליח",
	"Scout": "סייר",
	"Heavy Lifter": "מרים כבד",
	"The heart of your base. Its level caps every other building and unlocks new ones.": "לב הבסיס. הרמה שלו קובעת את הרמה המקסימלית של כל השאר ופותחת מבנים חדשים.",
	"Makes coins over time. Tap the coin above it to collect.": "מייצר מטבעות עם הזמן. לוחצים על המטבע שמעליו כדי לאסוף.",
	"Raises how many coins you can hold. Attackers loot it.": "מגדיל את כמות המטבעות שאפשר להחזיק. תוקפים בוזזים אותו.",
	"Houses your attack drones. Higher levels fit a bigger army and stronger drones.": "הבית של רחפני התקיפה. ברמה גבוהה יותר נכנס צבא גדול יותר ורחפנים חזקים יותר.",
	"Turret that locks onto the nearest drone and burns it.": "צריח שננעל על הרחפן הקרוב ושורף אותו.",
	"Fires nets that slow drones to a crawl.": "יורה רשתות שמאטות רחפנים כמעט לעצירה.",
	"Scrambles drones inside its field so they drift and slow down.": "משבש רחפנים בתוך השדה שלו, והם נסחפים ומאטים.",
	"Gulls circle the nest and slam into passing drones.": "שחפים חגים מעל הקן ומתנגשים ברחפנים שעוברים.",
	"All-rounder. Goes for whatever is closest.": "רב-תכליתי. תוקף את המבנה הקרוב ביותר.",
	"Fast and fragile. Heads straight for generators, silos and the Command Tower.": "מהיר ושביר. טס ישר לגנרטורים, לסילו ולמגדל הפיקוד.",
	"Slow and tough. Takes out defenses first, so the others survive.": "איטי וחזק. מפרק קודם את ההגנות, כדי שהאחרים ישרדו.",

	# Reasons
	"Needs Command Tower Lv %d": "דורש מגדל פיקוד ברמה %d",
	"Limit reached (%d)": "הגעת למקסימום (%d)",
	"Need %d more coins": "חסרים %d מטבעות",
	"Max level": "רמה מקסימלית",
	"Upgrade the Command Tower first": "קודם צריך לשדרג את מגדל הפיקוד",
	"Nothing here": "אין כאן כלום",
	"Needs Hangar Lv %d": "דורש האנגר ברמה %d",
	"Upgrade the Hangar first": "קודם צריך לשדרג את ההאנגר",

	# Home
	"Hangar": "האנגר",
	"Test": "בדיקה",
	"ATTACK\n%s": "התקפה\n%s",
	"Close": "סגירה",
	"Your Base  ·  Command Tower Lv %d": "הבסיס שלך  ·  מגדל פיקוד רמה %d",
	"Coins %d / %d": "מטבעות %d / %d",
	"Empty roof": "גג פנוי",
	"Pick what to build here.": "מה לבנות כאן?",
	"Build  ·  %d": "בנייה  ·  %d",
	"Upgrade to Lv %d  ·  %d coins": "שדרוג לרמה %d  ·  %d מטבעות",
	"Max level reached": "הגיע לרמה המקסימלית",
	"Remove (no refund)": "הסרה (בלי החזר)",
	"Open hangar": "פתיחת ההאנגר",
	"Now": "עכשיו",
	"Lv %d": "רמה %d",
	"Health": "חיים",
	"Health %d": "חיים %d",
	"Max level for others": "רמה מקסימלית לאחרים",
	"Coins per minute": "מטבעות לדקה",
	"Holds up to": "מחזיק עד",
	"Coin cap bonus": "תוספת קיבולת",
	"Army space": "מקום בצבא",
	"Drone max level": "רמת רחפנים מקסימלית",
	"Damage per second": "נזק לשנייה",
	"Range": "טווח",
	"Reload": "טעינה",
	"Gulls": "שחפים",
	"Damage per bump": "נזק לפגיעה",
	"%.1f m": "%.1f מ'",
	"%.1f s": "%.1f ש'",
	"Upgrading unlocks: %s": "השדרוג פותח: %s",
	"%s built": "%s נבנה",
	"Upgraded": "שודרג",
	"+%d coins": "+%d מטבעות",
	"Coin silos are full. Build or upgrade a Coin Silo.": "הסילו מלא. בנו או שדרגו סילו מטבעות.",
	"Add drones to your army in the Hangar first": "קודם צריך להוסיף רחפנים לצבא בהאנגר",
	"Next attack army: %d / %d space": "צבא להתקפה הבאה: %d / %d מקום",
	"Pick how many of each drone you take into battle. Bigger drones take more space. Upgrade the Hangar for more space.": "בוחרים כמה רחפנים מכל סוג יוצאים לקרב. רחפן גדול תופס יותר מקום. שדרוג ההאנגר מוסיף מקום.",
	"Locked": "נעול",
	"Speed %.1f": "מהירות %.1f",
	"Damage %d/s": "נזק %d לשנייה",
	"Takes %d space": "תופס %d מקום",
	"In army: %d": "בצבא: %d",
	"Upgrade  ·  %d": "שדרוג  ·  %d",
	"Unlock  ·  %d": "פתיחה  ·  %d",
	"%s Lv %d": "%s רמה %d",
	"Your Base (practice)": "הבסיס שלך (אימון)",

	# Battle
	"Tap outside the base to release drones": "לחצו מחוץ לבסיס כדי לשחרר רחפנים",
	"No drones left to release": "לא נשארו רחפנים לשחרר",
	"Too close to a building. Release drones outside the base.": "קרוב מדי למבנה. משחררים רחפנים מחוץ לבסיס.",
	"End": "סיום",
	"Loot %d": "שלל %d",
	"%d%%  ·  Stars %d/3": "%d%%  ·  כוכבים %d/3",
	"Battle over": "הקרב נגמר",
	"Stars %d / 3   ·   %d%%": "כוכבים %d / 3   ·   %d%%",
	"Practice run on your own base.\nNo coins at stake.": "אימון על הבסיס שלך.\nבלי מטבעות על הפרק.",
	"Loot banked: %d\nTotal coins: %d": "שלל שנכנס: %d\nסך הכול מטבעות: %d",
	"Retry": "שוב",
	"Home": "לבסיס",
}


static func t(text: String) -> String:
	if lang == "he":
		return HE.get(text, text)
	return text


static func rtl() -> bool:
	return lang == "he"


## Point the default UI and 3D-label font at a system font that has Hebrew glyphs
## (Segoe UI / Arial on Windows, Arial Hebrew / system font on iOS and Android).
static func setup_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Rubik", "Segoe UI", "Arial", "Arial Hebrew", "Noto Sans Hebrew", "Helvetica Neue", "sans-serif"])
	ThemeDB.fallback_font = font
