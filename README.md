# UsOnly — Couple App (Flutter + Firebase Native)

> *"just us, always."*

UsOnly is a private mobile application designed exclusively for two people in a relationship. There are no public feeds, follower counts, discover tabs, or group chats. The entire experience is dedicated to private real-time messaging, photo sharing, and shared memory archiving.

---

## 1. Project Overview & Architecture

- **Mobile Client**: Flutter (Dart) with Material 3 intimate design palette.
- **Backend Infrastructure**: Pure Firebase services only.
  - **Authentication**: Firebase Authentication (Email & Password, verification, password reset, account deletion).
  - **Database**: Cloud Firestore (NoSQL real-time document store).
  - **Media Storage**: Firebase Cloud Storage (`couples/{coupleId}/media/*` with strict 15MB limits and MIME verification).
  - **Push Notifications**: Firebase Cloud Messaging (FCM).
  - **Privileged Operations**: Firebase Cloud Functions (Node.js/TypeScript).
  - **Authorization**: Firebase Security Rules for Firestore and Cloud Storage.
- **State Management**: Riverpod (`Notifier`, `Provider`, and reactive streams).
- **Navigation & Guards**: GoRouter with authentication and pairing-aware route guards.
- **No External Servers**: Zero reliance on PHP, Laravel, Node.js REST servers, MySQL, or VPS backends.

---

## 2. Directory Structure

```
usonly/
├── lib/
│   ├── app/
│   │   ├── app.dart                   # UsOnlyApp root widget
│   │   ├── router.dart                # GoRouter route guards & ShellRoute
│   │   └── theme/
│   │       ├── app_colors.dart        # Romantic palette (rose, blush, plum, dark)
│   │       └── app_theme.dart         # Material 3 light & dark themes
│   ├── features/
│   │   ├── auth/                      # Login, Register, Forgot Password, Account Deletion
│   │   ├── pairing/                   # Single-use 6-character expiring pairing system
│   │   ├── home/                      # Couple dashboard & anniversary counter
│   │   ├── chat/                      # Real-time chat with photo messages & read receipts
│   │   ├── media/                     # Storage upload pipeline with progress feedback
│   │   ├── memories/                  # Shared memories timeline & photo attachments
│   │   └── profile/                   # Avatar, display name, security & account settings
│   ├── firebase_options.dart          # Multi-platform Firebase configuration
│   └── main.dart                      # App entrypoint & Firebase initialization
├── functions/                         # Firebase Cloud Functions (TypeScript)
│   ├── src/index.ts                   # createPairingCode, redeemPairingCode, FCM trigger
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules                    # Production Firestore security rules
├── storage.rules                      # Production Storage security rules
├── firestore.indexes.json             # Composite query indexes
└── firebase.json                      # Firebase project & Emulator Suite configuration
```

---

## 3. Required Tools & Prerequisites

1. **Flutter SDK**: 3.24+ (Dart 3.5+) installed and added to `PATH`.
2. **Node.js**: 20+ installed.
3. **Firebase CLI**:
   ```powershell
   npm install -g firebase-tools
   ```
4. **FlutterFire CLI**:
   ```powershell
   dart pub global activate flutterfire_cli
   ```
5. **Java / Android Studio**: JDK 17+ and Android SDK with Android 14+ (API 34+) platform tools.

---

## 4. Firebase Project Setup Step-by-Step

### Step 4.1: Create Firebase Project
1. Open [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and name it `usonly-app` (or your preferred name).
3. (Optional) Disable Google Analytics or link your preferred analytics property.

### Step 4.2: Enable Authentication Providers
1. In Firebase Console, navigate to **Build > Authentication**.
2. Click **Get Started**.
3. Under the **Sign-in method** tab, enable **Email/Password** and click **Save**.

### Step 4.3: Create Cloud Firestore Database
1. In Firebase Console, navigate to **Build > Firestore Database**.
2. Click **Create database**.
3. Select your preferred database location (e.g., `nam5 (us-central)` or `asia-southeast1`).
4. Choose **Start in production mode** (our security rules will be deployed in Step 5).

### Step 4.4: Enable Cloud Storage
1. Navigate to **Build > Storage**.
2. Click **Get started**.
3. Select your storage bucket location matching your Firestore region.

### Step 4.5: Configure Firebase in Flutter with FlutterFire CLI
Log in to Firebase CLI from Windows PowerShell:
```powershell
firebase login
```
Run FlutterFire CLI from the root `d:\Project\usonly` directory:
```powershell
flutterfire configure
```
Select your Firebase project from the list. Choose platforms (Android, iOS, Web). This automatically updates `android/app/google-services.json` and generates `lib/firebase_options.dart`.

### Step 4.6: Add Android SHA-1 Fingerprint
To ensure App Check and OAuth credentials operate properly on Android:
```powershell
cd android
./gradlew signingReport
cd ..
```
Copy the `SHA1` and `SHA-256` fingerprints of your `debug` signing key and paste them into your Android app settings in the Firebase Console.

---

## 5. Security Rules Deployment

Deploy the production rules directly using the Firebase CLI:

```powershell
firebase deploy --only firestore:rules,storage
```

### Security Rules Highlights
- **Couple Space Isolation**: Only users whose UIDs are in `memberUids` can read or write to `coupleSpaces/{coupleId}`, `conversations/conv_{coupleId}`, or `storage: couples/{coupleId}/media/*`.
- **Two-Person Hard Limit**: The `memberUids` array cannot exceed 2 members under any circumstance.
- **Identity Spoofing Prevention**: Messages can only be written if `request.resource.data.senderUid == request.auth.uid`.
- **Media Validation**: Cloud Storage uploads are strictly verified against allowed MIME types (`image/*`, `video/*`) and restricted to `< 15MB`.

---

## 6. Cloud Functions Deployment & Billing Considerations

Firebase Cloud Functions (2nd Gen) requires the Firebase **Blaze (Pay as you go)** plan.
> **Note on Free Tier**: The Blaze plan provides a generous free tier every month:
> - 2,000,000 Cloud Functions invocations/month free.
> - 50,000 Firestore document reads/day free.
> - 20,000 Firestore document writes/day free.
> - 5 GB Cloud Storage free.
> For private couple usage between two individuals, your typical monthly bill will remain **$0.00**.

To deploy Cloud Functions:
```powershell
cd functions
npm install
npm run build
firebase deploy --only functions
cd ..
```

---

## 7. Local Development with Firebase Emulator Suite

You can develop and run offline without calling live Firebase servers:

1. Start emulators from the project root:
   ```powershell
   firebase emulators:start
   ```
2. The Emulator UI will be accessible in your browser at `http://127.0.0.1:4000`:
   - Authentication Emulator: Port `9099`
   - Firestore Emulator: Port `8080`
   - Functions Emulator: Port `5001`
   - Storage Emulator: Port `9199`

---

## 8. Running the Application on Android

To run the Flutter app on an Android emulator or connected device:

```powershell
# Verify Flutter doctor has no blocker
flutter doctor

# Run on connected Android device
flutter run -d android
```

---

## 9. Testing & Code Quality

Run static code analysis:
```powershell
flutter analyze
```

Execute all unit and widget tests:
```powershell
flutter test
```

---

## 10. Troubleshooting

- **`FirebaseException: [core/not-initialized]`**: Ensure `WidgetsFlutterBinding.ensureInitialized()` is executed before calling `Firebase.initializeApp()`.
- **`Cloud Functions 403 Forbidden`**: Ensure your Firebase project is upgraded to the Blaze plan to enable Cloud Functions deployment. Note: `PairingRepository` has an automatic atomic Firestore transaction fallback that operates even if Functions are temporarily offline!
- **`Permission Denied in Firestore`**: Check that your user is logged in and belongs to `memberUids` of the couple space.
# UsOnly
