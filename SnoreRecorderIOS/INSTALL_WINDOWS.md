# Instalacija na iPhone s Windowsa (bez Maca)

## 1. Preuzmi .ipa s GitHuba
1. Otvori repo na GitHubu → kartica **Actions** → **Build iOS IPA (unsigned)**.
2. Klikni zadnji zeleni (✓) run → dolje pod **Artifacts** preuzmi `SnoreRecorder-ipa`.
3. Raspakiraj zip – dobiješ `SnoreRecorder.ipa`.
   (Novi build se radi automatski na svaki push u `SnoreRecorderIOS/`, ili ručno: Actions → Run workflow.)

## 2. Pripremi
- **Sporedni Apple ID** (preporuka): napravi ga na appleid.apple.com, uključi 2FA.
- Na Windowsu instaliraj **iTunes i iCloud s apple.com** (NE iz Microsoft Storea – Sideloadly/AltServer s tom verzijom često ne rade).
- Spoji iPhone kabelom, otključaj ga i na upit "Vjeruj ovom računalu" odaberi **Vjeruj**.

## 3a. Sideloadly (najjednostavnije, obnova svakih 7 dana preko PC-a)
1. Skini Sideloadly **samo s sideloadly.io**.
2. Povuci `SnoreRecorder.ipa` u prozor, upiši sporedni Apple ID, klikni **Start**.
3. Na iPhoneu: **Postavke → Općenito → VPN i upravljanje uređajem** → tvoj Apple ID → **Vjeruj**.
4. **Postavke → Privatnost i sigurnost → Način rada za razvojne programere** → uključi, mobitel se restarta, potvrdi.
5. Nakon 7 dana app se prestane otvarati → ponovi korak 2 (snimke ostaju sačuvane).

## 3b. SideStore (obnova na samom mobitelu, bez PC-a nakon postavljanja)
Postavljanje je duže i mijenja se s verzijama, zato prati službeni vodič: **sidestore.io → Install**.
Ukratko: s Windowsa jednom instaliraš SideStore + "pairing file", na iPhoneu instaliraš
njihovu VPN aplikaciju (LocalDevVPN/StosVPN iz App Storea), zatim u SideStoreu otvoriš
`SnoreRecorder.ipa` (pošalji ga sebi na iPhone, npr. preko iClouda/Datoteka).
SideStore otvori barem jednom tjedno i klikni **Refresh** – i to je to.

## 4. Prvo pokretanje
- Dopusti mikrofon.
- Pokreni praćenje, stavi mobitel na punjač pored kreveta, zaključaj ekran.
- Ujutro otvori app → lista snimaka po noćima.

## Ako nešto ne radi
- "Unable to install" / "Integrity" → provjeri da Developer Mode je uključen i da si vjerovao developeru.
- "Maximum number of apps" → s besplatnim Apple ID-jem najviše 3 sideloadana appa; obriši neki.
- Sideloadly ne vidi iPhone → iTunes s apple.com, drugi kabel/USB port, otključan ekran.
