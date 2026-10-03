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
	"Fuel Pump": "משאבת דלק",
	"Fuel Tank": "מכל דלק",
	"Pumps fuel over time. Tap the drop above it to collect.": "שואבת דלק עם הזמן. לוחצים על הטיפה שמעליה כדי לאסוף.",
	"Raises how much fuel you can hold. Attackers loot it.": "מגדיל את כמות הדלק שאפשר להחזיק. תוקפים בוזזים אותו.",
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
	"Need %d more fuel": "חסר %d דלק",
	"Need %d more gems": "חסרים %d יהלומים",
	"All workers are busy": "כל הפועלים עסוקים",
	"All workers hired": "כל הפועלים כבר גויסו",
	"Under construction": "בבנייה",
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
	"Fuel %d / %d": "דלק %d / %d",
	"Gems %d": "יהלומים %d",
	"Workers %d/%d": "פועלים %d/%d",
	"Workers": "פועלים",
	"Free workers: %d / %d": "פועלים פנויים: %d / %d",
	"Every build or upgrade needs a free worker until it is done.": "כל בנייה או שדרוג תופסים פועל אחד עד שהם מסתיימים.",
	"Hire a worker  ·  %d gems": "גיוס פועל  ·  %d יהלומים",
	"Building": "בבנייה",
	"Upgrading to Lv %d": "משדרגים לרמה %d",
	"Finish now  ·  %d gems": "לסיים עכשיו  ·  %d יהלומים",
	"Upgrade started": "השדרוג התחיל",
	"Done!": "מוכן!",
	"%s is ready": "%s מוכן",
	"Fuel per minute": "דלק לדקה",
	"Fuel cap bonus": "תוספת קיבולת דלק",
	"+%d fuel": "+%d דלק",
	"Fuel tanks are full. Build or upgrade a Fuel Tank.": "מכלי הדלק מלאים. בנו או שדרגו מכל דלק.",
	"Coins, fuel and gems: unlimited (dev)": "מטבעות, דלק ויהלומים: ללא הגבלה (פיתוח)",
	"DEV: free ON": "פיתוח: הכול בחינם",
	"DEV: free OFF": "פיתוח: תשלום רגיל",
	"Upgrade  ·  %d fuel": "שדרוג  ·  %d דלק",
	"Unlock  ·  %d fuel": "פתיחה  ·  %d דלק",
	"Build here": "בנייה כאן",
	"Build": "בנייה",
	"Settings": "הגדרות",
	"Commander": "המפקד/ת",
	"Command Tower Lv %d": "מגדל פיקוד רמה %d",
	"Free workers %d/%d": "פועלים פנויים %d/%d",
	"ATTACK!\n%s": "התקפה!\n%s",
	"Practice on my base": "אימון על הבסיס שלי",
	"Tap a free pad for the %s": "לחצו על משבצת פנויה בשביל %s",
	"The gem shop is coming soon": "חנות היהלומים תגיע בקרוב",
	"Pick what to build here.": "מה לבנות כאן?",
	"Build  ·  %d\n%s": "בנייה  ·  %d\n%s",
	"Upgrade to Lv %d  ·  %d coins  ·  %s": "שדרוג לרמה %d  ·  %d מטבעות  ·  %s",
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
	"DEV: infinite coins ON": "פיתוח: מטבעות אינסופיים פועל",
	"DEV: infinite coins OFF": "פיתוח: מטבעות אינסופיים כבוי",
	"Coins: unlimited (dev)": "מטבעות: ללא הגבלה (פיתוח)",
	"Sound on": "סאונד פועל",
	"Sound off": "סאונד כבוי",

	# Battle
	"Tap outside the base to release drones": "לחצו מחוץ לבסיס כדי לשחרר רחפנים",
	"No drones left to release": "לא נשארו רחפנים לשחרר",
	"Too close to a building. Release drones outside the base.": "קרוב מדי למבנה. משחררים רחפנים מחוץ לבסיס.",
	"End": "סיום",
	"Loot %d coins · %d fuel": "שלל %d מטבעות · %d דלק",
	"%d%%  ·  Stars %d/3": "%d%%  ·  כוכבים %d/3",
	"Battle over": "הקרב נגמר",
	"Stars %d / 3   ·   %d%%": "כוכבים %d / 3   ·   %d%%",
	"Practice run on your own base.\nNo coins at stake.": "אימון על הבסיס שלך.\nבלי מטבעות על הפרק.",
	"Loot banked: %d coins, %d fuel": "שלל שנכנס: %d מטבעות, %d דלק",
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
