# Rickbo — Design System (DESIGN.md)

> Brand: **Bharosa + Modern.** Deep blue + cyan, friendly-rounded, Hindi-first.
> Flutter project mein reference karo. Goal: brand jaisa lage, premium + attractive,
> par non-literate banda bhi chala le. Safety is the message; the color carries it.
> Visual reference: see DESIGN-mockup.html (open in a browser).

---

## 0. Brand thesis
Rickbo bechta hai **safety + certainty**, sasta nahi. Isliye color **deep blue** — transport
mein log blue ko bharosemand + safe maante hain (banks, insurance, safe-ride). Cyan = "live/
active" energy. Green = "हाँ/online/safe". Friendly-rounded shapes = approachable, gaon-friendly.
Boldness ek jagah: the blue hero + the driver's glowing offer screen. Baaki sab shaant.

---

## 1. Color tokens
```
// Primary
blue        #1D4ED8   primary — buttons, brand, action
blueDark    #0B3A7A   gradient end, pressed
blueDeep    #0B2447   darkest — driver screen bg, ink

// Accent
cyan        #06B6D4   live ride, active, highlights (lighter #5FE0FF for driver fare glow)
green       #16A34A   success base
greenBright #22C55E   हाँ / चालू / online
red         #E5484D   ना / बंद / SOS
gold        #FFB020   stars/ratings, tiny joy accents (use rarely)

// Neutrals
ink         #0B2447   primary text (deep blue-black, not pure black)
muted       #6B86A8   secondary text
bg          #EFF5FF   app background (cool blue-white)
card        #FFFFFF   surfaces
line        #DCE7F7   hairline borders

// Tints (chip/icon backgrounds)
tintBlue #DCE9FF · tintGreen #E4FBEF · tintCyan #E6F4FF · tintGold #FFF1D6
```
**Rule:** Boldness only on blue (+ cyan on the driver screen). Red ONLY for ना/SOS, never decoration.

---

## 2. Typography
- **Display:** `Baloo 2` (600–800). Rounded, friendly, renders beautifully in Devanagari.
  Use for headings, fares, buttons, brand.
- **Body/UI:** `Hind` (400–700). Clean, readable Hindi.
- **Fare is always the largest element** on any screen (tabular, bold).
- Simple Hindi, sentence case: "रिक्शा बुलाओ", not "रिक्शा बुकिंग करें".

**Type scale**
```
Display XL  34/800  (greeting "कहाँ चलें?")
Display L   24/700  (card titles, "रिक्शा बुलाओ")
Fare big    32–62/700 (₹ amounts; driver offer up to 62)
Body L      18/600
Body        16/500
Caption     13/600  (never below 13)
```

---

## 3. Shape, spacing, elevation
- Radius: buttons 16–18, cards 18–22, hero 26, bottom sheet 30 (top), driver offer 28.
- Touch targets >= 56px. Body text >= 16. Generous padding (20px screen gutters).
- Shadows: soft, **blue-tinted**, never harsh black. e.g. 0 14px 30px rgba(29,78,216,.30).
- Icons: filled, rounded, large. Every action = icon + Hindi word.
- One screen = one job = one primary button.

---

## 4. Components
- **Primary button:** blue->blueDark gradient, white Baloo text, radius 16, blue shadow.
  Pressed: blueDark, shadow shrinks, light haptic.
- **Hero card (home):** blue gradient, big Baloo title, faint rickshaw watermark bottom-right,
  white pill "अभी बुक करो ->".
- **Trust strip:** 3 small pills under hero — वेरिफाइड ड्राइवर / लाइव लोकेशन / SOS मदद.
  Quiet (tinted bg), but always on home. This is the brand's safety promise, visible upfront.
- **Quick chips:** white card, tinted rounded icon + label (स्टेशन/अस्पताल/बाज़ार/कोर्ट).
- **Mode card (fare):** two cards side by side; selected = blue border + #F0F6FF fill + blue
  shadow; "सस्ता" green tag on Share. Fare is the biggest text.
- **Bottom nav:** white, 3 items (होम/सफ़र/मेरा), active = blue.
- **Driver online switch:** LED-style — off grey, on greenBright with glow.

---

## 5. Signature element — driver offer + live "रिक्शा आ रही है" card
**Driver offer screen** (the moment that defines the app): blueDeep background, "ऑनलाइन"
green pill, a raised card with destination, a HUGE cyan rupee fare (#5FE0FF), distance, a cyan
shrinking 20s timer, and two big buttons — ना (muted red) / हाँ (green gradient). A Hindi
voice plays: "सवारी है — स्टेशन — Rs 25". Dark + cyan glow = premium, easy on night eyes.

**User live card** (rickshaw arriving): small animated e-rickshaw moving on a light map, a
white card with round driver photo, rickshaw number in number-plate style, big rupee fare, ETA
"बस 4 मिनट में" with a gentle cyan pulse, OTP in 4 big rounded boxes.

Spend premium feel here; keep everything else quiet.

---

## 6. Screens (layout)

### User — Home
Blue logo + "Rickbo" header, "बाहर" right. Greeting "नमस्ते / कहाँ चलें?". Blue hero
"रिक्शा बुलाओ". Trust strip (3 pills). "जल्दी जाने की जगहें" + 4 quick chips. Bottom nav.

### User — Fare confirm (bottom sheet over map)
Light map with route. Sheet: destination row, two mode cards (साझा Rs 15 / पूरी Rs 25),
full-width blue "बुक करें ->".

### Driver — incoming offer
Per Section 5. Big buttons, big fare, voice, timer. No typing.

### SOS
Round red floating button during a ride -> full-screen red "मदद चाहिए?" -> [हाँ, अभी] with a
3s cancel to prevent misfire.

---

## 7. Motion (minimal, characterful)
- App open: logo settles once (~600ms).
- Booking confirm: blue ripple -> green tick "बुक हो गया" + light haptic.
- Searching: soft cyan radar pulse around the rickshaw.
- Driver हाँ/ना: spring bounce + voice prompt.
- Respect reduced-motion. Over-animation = AI feel; avoid.

---

## 8. Empty / error / weak-network (polish = premium)
- No rickshaw: "अभी कोई रिक्शा खाली नहीं — थोड़ी देर में फिर देखें" + retry. No apology.
- Slow net: warm toast "नेटवर्क धीमा है, इंतज़ार करें…". Never crash, never show raw API/HTML.
- First open: "पहली सवारी बुक करो — स्टेशन सिर्फ Rs 15 से!" — empty screen as an invitation.

---

## 9. Flutter theme starter
```dart
const blue=Color(0xFF1D4ED8), blueDark=Color(0xFF0B3A7A), blueDeep=Color(0xFF0B2447);
const cyan=Color(0xFF06B6D4), green=Color(0xFF22C55E), red=Color(0xFFE5484D);
const ink=Color(0xFF0B2447), muted=Color(0xFF6B86A8), bg=Color(0xFFEFF5FF),
      card=Color(0xFFFFFFFF), line=Color(0xFFDCE7F7), gold=Color(0xFFFFB020);
// Fonts: GoogleFonts.baloo2 (display/buttons/fare), GoogleFonts.hind (body)
// Buttons radius 16, cards 20, min height 56, blue-tinted shadows.
```

## 10. One-line rule
> Blue carries the bharosa, cyan carries the life. Spend boldness on the hero + the driver
> offer; keep everything else quiet, big, rounded, Hindi. Premium AND usable by anyone.
