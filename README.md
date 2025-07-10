# FYP2_TIMETABLE PLANNER WITH CHATBOT INTEGRATION

Project Description
-------------------
A cross-platform schedule, task, and timetable management application built with Flutter. The app helps users organize their daily activities, set reminders, manage categories, and interact with a chatbot for smart scheduling.

Key Features
------------
- Add, edit, and delete tasks or schedules
- Category management (create, edit, delete categories)
- Chatbot for natural language schedule creation
- Beautiful and intuitive UI with phone frame preview (for web/desktop)
- Travel and event planning support
- User authentication (if enabled)

Technology Stack
----------------
- Flutter (UI framework)
- Dart (programming language)
- Provider (state management)
- Firebase (authentication, if enabled)
- Lottie (animations)
- Platform channels for native integration (if needed)

---

Security Notice: API Keys & Sensitive Files
------------------------------------------
**Do NOT upload your real API keys, secrets, or configuration files (such as `google-services.json`, `.env`, or any other secret files) to any public repository.**

- Always add these files to your `.gitignore` before publishing your code.
- Provide only example files (e.g., `google-services.json.example`, `.env.example`) without real credentials.
- Each user should configure their own API keys and secrets according to the documentation of the respective service (Firebase, OpenAI, etc.).
- If you accidentally commit sensitive files, remove them from git history and rotate your keys immediately.
- - **To use the chatbot feature, you must replace the GPT API key in `lib/services/gpt_service.dart` with your own OpenAI (or other GPT provider) API key.**

---

1. Prerequisites
----------------
1. **Flutter SDK**
   - Recommended version: 3.10.0 or above
   - Download: https://docs.flutter.dev/get-started/install

2. **Dart SDK**
   - Dart SDK is bundled with Flutter, no separate installation required

3. **Android Studio / VS Code / IntelliJ IDEA** (choose one)
   - For code editing, emulator, and debugging
   - Android Studio: https://developer.android.com/studio
   - VS Code: https://code.visualstudio.com/

4. **Android device or emulator** (for running Android APK)
   - You can create an emulator after installing Android Studio

5. **Xcode** (macOS only, required for iOS build)
   - Install from the App Store

---

2. Install Dependencies
----------------------
1. Open Terminal or Command Prompt/PowerShell and navigate to the project root:
   ```sh
   cd /path/to/flutter_application_3
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```

---

3. Running the Project
---------------------
1. **Run on Android device/emulator**
   ```sh
   flutter run
   ```
   Or build a debug APK:
   ```sh
   flutter build apk --debug
   ```
   APK location: build/app/outputs/flutter-apk/app-debug.apk

2. **Run on Web (browser)**
   ```sh
   flutter run -d chrome
   ```

3. **Run on Windows desktop**
   ```sh
   flutter run -d windows
   ```

4. **Run on macOS desktop** (macOS only)
   ```sh
   flutter run -d macos
   ```

5. **Run on iOS device/simulator** (macOS only)
   ```sh
   flutter run -d ios
   ```

---

4. Useful Commands
------------------
- Check environment:
  ```sh
  flutter doctor
  ```
- Clean build cache:
  ```sh
  flutter clean
  ```
- Upgrade dependencies:
  ```sh
  flutter pub upgrade
  ```

---

5. Troubleshooting
------------------
- If you encounter dependency conflicts or build failures, try running `flutter clean` then `flutter pub get`.
- Android devices must enable Developer Mode and USB Debugging.
- For iOS, you may need to trust the developer certificate. See the official Flutter documentation for details.

---

6. Reference Links
------------------
- Flutter Official: https://flutter.dev/
- Flutter Install Guide: https://docs.flutter.dev/get-started/install
- Dart Official: https://dart.dev/
- Android Studio: https://developer.android.com/studio
- VS Code: https://code.visualstudio.com/

---

For more information, please refer to the official Flutter documentation or open an issue if you have questions.
