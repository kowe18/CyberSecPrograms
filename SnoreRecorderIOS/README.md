# Hrkanje – iOS snimač hrkanja

SwiftUI aplikacija koja preko noći sluša mikrofon, svake ~1 s klasificira zvuk
Appleovim ugrađenim klasifikatorom (`SoundAnalysis`, klasa `snoring`) i kad je
pouzdanost ≥ 0.5 snimi isječak s vremenom. Ujutro prikaže listu snimaka
(grupiranu po noćima) za preslušavanje, dijeljenje i brisanje.

## Kako radi
- `AVAudioEngine` tap na mikrofonu → `SNAudioStreamAnalyzer` + `SNClassifySoundRequest(.version1)`, prozor 1 s.
- Uz `UIBackgroundModes: audio` snimanje radi i dok je ekran zaključan (iOS ekvivalent Android foreground servisa; gore se vidi narančasta točka mikrofona).
- Čuva se 2 s zvuka **prije** detekcije, a snimanje traje dok hrkanje ne prestane 2 s (max 120 s po isječku), pa uzastopne detekcije postaju jedan snimak umjesto hrpe 1-sekundnih.
- Snimke: `Documents/Recordings/snore_yyyyMMdd_HHmmss.m4a` (AAC) + `.json` (početak, trajanje, max pouzdanost). Vidljive su i u aplikaciji Datoteke → Na mom iPhoneu → Hrkanje.
- Prekidi (poziv, alarm) i promjena audio rute automatski ponovno pokreću slušanje.

Podesivo u `SnoreMonitor.swift`: `threshold`, `windowSeconds`, `preRollSeconds`, `hangoverSeconds`, `maxClipSeconds`.

## Instalacija na iPhone
Treba Mac s Xcodeom 15+ (iOS 17+ na mobitelu). Besplatni Apple ID je dovoljan za vlastiti uređaj.

```bash
brew install xcodegen
cd SnoreRecorderIOS
xcodegen generate
open SnoreRecorder.xcodeproj
```
U Xcodeu: target *SnoreRecorder* → *Signing & Capabilities* → odaberi svoj Team
(po potrebi promijeni bundle ID u nešto jedinstveno), spoji iPhone, ▶ Run.
Na iPhoneu uključi *Postavke → Privatnost i sigurnost → Način rada za razvojne programere*
i vjeruj developeru u *Postavke → Općenito → VPN i upravljanje uređajem*.

Bez XcodeGena: napravi novi iOS App projekt (SwiftUI) u Xcodeu, ubaci `.swift`
datoteke iz `SnoreRecorder/`, dodaj `NSMicrophoneUsageDescription` u Info i u
*Signing & Capabilities* dodaj *Background Modes → Audio*.

## Napomene
- Ostavi mobitel na punjaču – cijelu noć mikrofon + klasifikacija troše bateriju.
- Ne koristi se YAMNet: Appleov klasifikator je također treniran na AudioSet klasama, radi na Neural Engineu i nema potrebe za TFLite ovisnostima. Ako baš želiš YAMNet, može se dodati preko `TensorFlowLiteSwift` (16 kHz mono, prozori od 15 600 uzoraka, indeks klase *Snoring* = 38).
