# SmartHeart Care App

SmartHeart Care App is a **prototype mobile application** for ECG signal monitoring and AI-based signal quality assessment.  
The application is designed to be used **together with an external ECG monitoring device**.

> ⚠️ Important  
> - Local usage only (no cloud backend)  
> - Requires an external ECG monitoring device  
> - Prototype for technical and educational purposes only

---

## System Overview
The system consists of:
- A Flutter-based mobile application
- An external ECG monitoring hardware device
- An on-device AI module for ECG signal quality screening

The ECG device provides raw ECG signals to the mobile application, where the data is visualized, recorded, and evaluated in real time.

---

## Features
- Real-time ECG signal visualization
- AI-based ECG signal quality check (prototype-level)
- Session-based ECG recording
- Viewing historical ECG sessions (local storage)

---

## Supported Hardware
- External ECG Monitoring Device  
- Connection via local interface (e.g. USB / Bluetooth, depending on setup)

> ⚠️ The application does not generate ECG signals by itself.  
> A connected ECG monitoring device is required.

---

## Technology Stack
- Flutter / Dart
- AI: Logistic Regression (prototype)
- Local on-device database

---

## Getting Started

### Prerequisites
- Flutter SDK (stable version)
- Android Studio or Visual Studio Code
- Android Emulator or physical Android device
- ECG Monitoring Hardware

Verify Flutter installation:
```bash
Step 1: Clone the Repository
git clone https://github.com/<your-username>/SmartHeart-Care-App.git
cd SmartHeart-Care-App

Step 2: Install Dependencies
flutter pub get

Step 3: Connect ECG Monitoring Device
Power on the ECG monitoring device.
Attach the sensor correctly to the user.
Connect the device to the mobile phone (USB / Bluetooth).
Ensure the signal is detected before starting measurement.

Step 4: Run the Application
flutter run

Step 5: Start ECG Measurement
Open the application.
Start a new ECG recording session.
View real-time ECG signal and signal quality status.

---

## Version Control Workflow

### Daily flow (simple)
```bash
git status
git checkout -b feature/short-name
# work...
git add -A
git commit -m "describe change"
git checkout main
git merge feature/short-name
git push origin main
```

### Versioning (Semantic Versioning)
- Update version in `pubspec.yaml` (format `MAJOR.MINOR.PATCH+BUILD`)
- Tag releases when ready:
```bash
git tag -a v1.0.0 -m "release v1.0.0"
git push origin v1.0.0
```

### Changelog
- Add changes under the latest version in `CHANGELOG.md`
- Keep entries short and grouped (Added/Changed/Fixed)
