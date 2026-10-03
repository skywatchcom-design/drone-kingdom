# מחקר שוק, סבב 2: הזדמנויות שנוצרו ב-2025–2026
תאריך: 30.9.2026

## שיטה (ומה השתנה מסבב 1)
- נכללו רק בעיות שנוצרו או החריפו ב-2025–2026: רגולציה חדשה, מוצרים שנסגרים, ושינויים בפלטפורמות.
- כל ראיה מופיעה עם תאריך ומקור.
- נכונות לשלם נבדקה לפי **מחירים שמתחרים כבר גובים**, לא לפי הערכה.
- ספרתי מתחרים ישירים בפועל.
- **המגבלה:** לא הייתה לי גישה לכלי נפחי חיפוש (Ahrefs או Keyword Planner). לכן ביום הראשון של התוכנית צריך לבדוק את נפחי החיפוש לפני שמתחייבים.

### קריטריוני הדירוג (1–10)
| קריטריון | מה נמדד |
|---|---|
| ביקוש | היקף הבעיה לפי נתון מספרי מ-2026 |
| פער | מספר המתחרים הישירים (10 = מעט מתחרים) |
| תזמון | האם יש דדליין או גל שמתחיל עכשיו |
| תשלום | האם מתחרים כבר גובים כסף, וכמה |
| בנייה | מהירות ועלות, בהערכה של בונה יחיד עם AI |
| הפצה | האם הקהל מתרכז בערוצים אונליין שקל להגיע אליהם |

---

## עשר ההזדמנויות

### 1. סורק ומתקן אבטחה לאפליקציות שנבנו ב-AI (Supabase/Lovable)
- **הבעיה:** אפליקציות שנבנו ב-Lovable, Bolt, v0 ו-Cursor חושפות את בסיס הנתונים, כי מחוללי הקוד לא מגדירים הרשאות גישה (RLS).
- **ראיות מ-2026:**
  - באוגוסט 2026 נסרקו 30,998 אפליקציות: ב-99% היה לפחות ממצא אבטחה אחד, ו-**57% מאפליקציות Supabase הנגישות (2,096 מתוך 3,680) אפשרו קריאת טבלאות בלי התחברות** ([vibe-eval](https://vibe-eval.com/updates/vibe-coding-security-monthly-aug-2026/)).
  - באפריל 2026 נסרקו 1,072 אפליקציות ונמצאו 6,185 פגיעויות ([Symbiotic](https://www.symbioticsec.ai/blog/we-scanned-1-072-vibe-coded-apps-98-had-security-flaws)).
  - קיימת פגיעות מתועדת (CVE-2025-48757) ב-Lovable.
- **מתחרים (6 ומעלה):**
  - Vibe App Scanner: 5$ או 14$ חד-פעמי, או 29$ לחודש.
  - vas: 19–39$ לחודש.
  - vibe-eval, safetoship, scanbee, axonbuild.
  - הסורק המובנה של Lovable 2.0, וה-Security Advisor של Supabase.
- **הפער:** רוב הכלים **מוצאים** בעיות. מעטים מייצרים **תיקון מוכן**, כמו SQL של מדיניות RLS לכל טבלה ובדיקה חוזרת אחרי ההחלה, או משתלבים בזרימת העבודה של הבונה (GitHub Action, או שרת MCP ל-Cursor ול-Claude Code).
- **סוג המוצר:** Web App, יחד עם כלי CLI בקוד פתוח ושרת MCP.
- **מודל הכנסות:** סריקה ראשונה בחינם. דוח מלא עם תיקונים ב-9$ חד-פעמי. ניטור רציף ב-19$ לחודש.
- **עלות:** כמעט 0$ (Cloudflare Workers, עם AI לפי שימוש).
- **סיכון:**
  - שוק צפוף שמתמלא מהר, והפלטפורמות משפרות את הכלים המובנים שלהן.
  - **סיכון משפטי:** מותר לסרוק רק אפליקציה שהמשתמש הוכיח שהיא בבעלותו.
- **ציונים:** ביקוש 9 · פער 3 · תזמון 8 · תשלום 8 · בנייה 7 · הפצה 9 = **44**

### 2. פליטי Microsoft Publisher (שוק באנגלית)
- **הבעיה:** Publisher יוצא משימוש ב-1 עד 13 באוקטובר 2026. גרסאות Microsoft 365 לא יפתחו יותר קבצי ‎.pub, ומיקרוסופט ממליצה בעיקר להמיר ל-PDF, שאינו ניתן לעריכה.
- **ראיות מ-2026:**
  - עשרות שאלות בפורום Microsoft Q&A, למשל "How do I convert 18 years of Publisher newsletters", "Please don't retire Publisher".
  - הודעות IT של אוניברסיטאות (UW, UMN).
  - Computerworld.
  - מדריכים לכנסיות מאוגוסט–ספטמבר 2026.
- **מתחרים (8 ומעלה):**
  - Markzware: DesignMarkz להמרה ל-Canva, ו-OmniMarkz להמרה ל-IDML.
  - Korva: 49$ חד-פעמי.
  - PublishMedia לכנסיות.
  - ממירים כלליים: Zamzar, Aspose, FreeConvert, ConvertAPI.
- **הפער:** המרה **ניתנת לעריכה** ובאיכות גבוהה, בכמויות גדולות, לפורמטים שאנשים כבר משתמשים בהם (Google Slides, Canva, Word). ממירים כלליים מאבדים את הפריסה.
- **מודל הכנסות:** 9–49$ חד-פעמי.
- **עלות:** שרת עם LibreOffice ב-5$ לחודש.
- **סיכון:** שיא הביקוש הוא **עכשיו**, ובנייה של 14 יום תתפוס רק את הזנב שלו. איכות ההמרה קשה להשגה.
- **ציונים:** 9 · 3 · 9 · 7 · 6 · 7 = **41**

### 3. ציות קל לחוק זכויות השוכרים בבריטניה (Renters' Rights Act), למשכיר העצמאי
- **הבעיה:**
  - מ-1.5.2026, העלאת שכר דירה אפשרית רק בטופס 4A ורק פעם בשנה.
  - הייתה חובה למסור לשוכרים דף מידע עד 31.5.2026. הקנס הוא עד 7,000 ליש"ט לכל שכירות, ועד 40,000 ליש"ט בעבירה חוזרת.
  - **מאגר הדירות להשכרה של ממשלת בריטניה (PRS Database) נפתח לרישום ב-15.12.2026**, בפריסה לפי אזורים.
- **ראיות:** הטפסים הממשלתיים, Propertymark, NRLA, ומדריכים רבים מ-2026.
- **מתחרים (6 ומעלה):** Lendlord (כ-8.25 ליש"ט לחודש, השיק כלי ציות באפריל 2026), Landlord Studio (15 ליש"ט), Hammock, August, LetSorted, landlordsguild.
- **הפער:** כלי **ציות בלבד** וזול (3–5 ליש"ט לחודש), בלי ניהול נכס מלא, עם הכנה לרישום במאגר.
- **סיכון:** אחריות משפטית על דיוק, ומתחרים ממומנים.
- **ציונים:** 8 · 4 · 8 · 8 · 7 · 6 = **41**

### 4. ניהול שכירות למשכיר הישראלי (מסבב 1)
- **עדכון ל-2026:** מגמה גלובלית תומכת. כלי נדל"ן קטנים הם מהקטגוריות הצומחות ביותר, ו"ניהול נכסים למשכירים קטנים" מופיע כהזדמנות בסקירות מגמות מספטמבר 2026.
- **הפער בישראל:** נמצא רק מתחרה ישיר אחד, Renta.
- **החולשה:** אין דדליין שדוחף לפעולה, ונכונות המשכירים בישראל לשלם לא הוכחה.
- **ציונים:** 6 · 8 · 4 · 5 · 8 · 7 = **38**

### 5. החזר מס "עשה זאת בעצמך" לשכירים בישראל (מסבב 1)
- **ציונים:** 8 · 5 · 4 · 6 · 6 · 8 = **37** (עונתי, וקיים סיכון רגולטורי)

### 6. Publisher בעברית (בתי ספר, בתי כנסת, עלוני שבת, רשויות)
- **ראיה:** חיפוש בעברית לא החזיר **אף מדריך** בנושא פרישת Publisher. זה פער תוכן מלא, אבל הביקוש עצמו לא הוכח.
- **הפער:** המרה נכונה של עברית מימין לשמאל (צריך לבדוק איך הממירים הקיימים מתמודדים איתה).
- **ציונים:** 4 · 9 · 8 · 5 · 5 · 6 = **37**

### 7. הוכחת כתיבה עצמית לסטודנטים שהואשמו בשימוש ב-AI
- **ראיות מ-2026:**
  - בגלאי AI יש 5–20% זיהויים שגויים בטקסטים של דוברי אנגלית כשפת אם, ועד 61% בטקסטים של מי שאנגלית היא שפה שנייה עבורם.
  - יותר מ-25 אוניברסיטאות הגבילו את השימוש בגלאים.
  - יש תביעות של סטודנטים.
- **מתחרים:** Grammarly Authorship (חינמי), GPTZero ו-Draftback.
- **ציונים:** 8 · 3 · 7 · 5 · 6 · 7 = **36**

### 8. אבחון ירידת תנועה מ-AI Overviews לאתרים קטנים
- **ראיות מ-2026:** יחס ההקלקות יורד ב-58–61% בחיפושים שבהם מופיע AI Overview.
- **מתחרים:** כלי GEO רבים.
- **ציונים:** 7 · 4 · 6 · 6 · 7 · 6 = **36**

### 9. מכסים על משלוחים לארה"ב למוכרי Etsy מחוץ לארה"ב
- **ראיות:**
  - מ-9.7.2026, Etsy מחייבת DDP (תשלום מראש של מכסים על ידי המוכר) כדי שהזמנה תהיה מוגנת.
  - מוכרים ביטלו הזמנות לארה"ב, ובקהילה של Etsy יש קריאה פומבית לכלים טובים יותר.
- **הבעיה:** **Etsy עצמה השיקה מחשבון מכסים ותוויות משלוח DDP**, ולכן הסיכון שהפלטפורמה תסגור את הפער גבוה.
- **ציונים:** 7 · 3 · 6 · 6 · 4 · 6 = **32**

### 10. חוק הנגישות האירופי (EAA) לחנויות קטנות
- **ראיות:** החוק בתוקף מיוני 2025. עסקים זעירים פטורים. **עד אמצע 2026 לא אושר אף קנס באיחוד האירופי**, ולכן הדחיפות לפעול נמוכה.
- **מתחרים:** השוק רווי.
- **ציונים:** 5 · 3 · 4 · 5 · 6 · 5 = **28**

(נבדקו ונפסלו: הגירה ממוצרים שנסגרו, כמו PopSQL, Delighted ו-Project Online, כי חלופות ממומנות מציעות הגירה חינם. וגם אימות מפתחים באנדרואיד, כי הכלל הגלובלי נכנס לתוקף רק ב-2027.)

---

## טבלת דירוג
| # | הזדמנות | ביקוש | פער | תזמון | תשלום | בנייה | הפצה | **סה"כ** |
|---|---|---|---|---|---|---|---|---|
| 1 | אבטחה לאפליקציות שנבנו ב-AI | 9 | 3 | 8 | 8 | 7 | 9 | **44** |
| 2 | Publisher באנגלית | 9 | 3 | 9 | 7 | 6 | 7 | **41** |
| 3 | חוק השכירות הבריטי | 8 | 4 | 8 | 8 | 7 | 6 | **41** |
| 4 | משכיר ישראלי | 6 | 8 | 4 | 5 | 8 | 7 | 38 |
| 5 | החזר מס DIY | 8 | 5 | 4 | 6 | 6 | 8 | 37 |
| 6 | Publisher בעברית | 4 | 9 | 8 | 5 | 5 | 6 | 37 |
| 7 | הוכחת כתיבה | 8 | 3 | 7 | 5 | 6 | 7 | 36 |
| 8 | אבחון AI Overviews | 7 | 4 | 6 | 6 | 7 | 6 | 36 |
| 9 | מכסים ל-Etsy | 7 | 3 | 6 | 6 | 4 | 6 | 32 |
| 10 | EAA | 5 | 3 | 4 | 5 | 6 | 5 | 28 |

## מקורות
- [vibe-eval – דוח אוגוסט 2026](https://vibe-eval.com/updates/vibe-coding-security-monthly-aug-2026/) · [Symbiotic – 1,072 אפליקציות](https://www.symbioticsec.ai/blog/we-scanned-1-072-vibe-coded-apps-98-had-security-flaws) · [Escape](https://escape.tech/blog/methodology-how-we-discovered-vulnerabilities-apps-built-with-vibe-coding/) · [השוואת סורקים 2026](https://safetoship.dev/blog/best-vibe-coding-security-scanners) · [Vibe App Scanner](https://vibeappscanner.com/) · [Lovable security](https://lovable.dev/blog/secure-vibe-coding)
- [Microsoft – Publisher לא ייתמך אחרי אוקטובר 2026](https://support.microsoft.com/en-us/publisher/microsoft-publisher-will-no-longer-be-supported-after-october-2026) · [Q&A – 18 שנות עלונים](https://learn.microsoft.com/en-nz/answers/questions/5850805/how-do-i-convert-18-years-of-publisher-created-new) · [Q&A – Please don't retire](https://learn.microsoft.com/en-us/answers/questions/6009271/please-dont-retire-publisher) · [Computerworld](https://www.computerworld.com/article/4224008/microsoft-is-pulling-the-plug-on-publisher-what-now.html) · [Korva](https://korva.korsund.com/blog/microsoft-publisher-alternatives/) · [Markzware](https://markzware.com/workflow-tips/microsoft-publisher-to-canva/)
- [Trowers – טפסי חוק השכירות](https://www.trowers.com/insights/2026/april/renters-rights-act-2025) · [Simmons – דדליין 31.5](https://www.simmons-simmons.com/en/publications/cmn796vpx0006ustov3cujd3j/important-deadline-31-may-2026---renters-rights-act-information-sheet) · [Goodlord – PRS Database](https://blog.goodlord.co/understanding-the-private-rented-sector-database) · [Lendlord](https://theintermediary.co.uk/2026/04/lendlord-introduces-compliance-tool-to-support-renters-rights-act-requirements/) · [השוואת תוכנות UK](https://letsorted.co.uk/guides/best-landlord-property-management-software-uk-2026)
- [Etsy DDP – Value Added Resource](https://www.valueaddedresource.net/etsy-requires-ddp-shipping-us-tariffs/) · [מחשבון המכסים של Etsy](https://www.valueaddedresource.net/etsy-tests-us-tariff-calculator/) · [קהילת Etsy](https://community.etsy.com/t5/Technical-Issues/Navigating-US-Tariffs-as-an-International-Seller-A-Workaround/td-p/149044160) · [De minimis – EY](https://www.ey.com/en_gl/technical/tax-alerts/us-suspends-duty-free-de-minimis-treatment-for-low-value-shipments)
- [זיהויים שגויים בגלאי AI 2026](https://tohuman.io/blog/ai-detection-false-positives-2026) · [AI Overviews – נתוני 2026](https://contently.com/2026/04/27/ai-overview-traffic-impact/) · [EAA – Level Access](https://www.levelaccess.com/compliance-overview/european-accessibility-act-eaa/)
- [מגמות micro-SaaS ספטמבר 2026](https://blog.mean.ceo/micro-saas-trends-september-2026/) · [BigIdeasDB – מגמות 2026](https://bigideasdb.com/micro-saas-trends-2026) · [TrustMRR](https://trustmrr.com/)
