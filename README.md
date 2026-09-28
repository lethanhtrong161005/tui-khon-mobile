# 🪙 Túi Khôn (Smart Wallet) - Standalone Flutter Mobile App

> **Comprehensive Cross-Platform (iOS & Android) Personal Finance App**  
> 100% Standalone & Local-First (No external backend required!)  
> Built with **Flutter 3.x**, **Clean Architecture**, **Riverpod State Management**, and **Local Repository Pattern**.

---

## 🚀 Key Highlights & Architectural Decisions

- **No External Backend (BE) Required**: Operates completely on-device using local repository storage, embedded Vietnamese natural language parsing rules, and reactive state management.
- **True Cross-Platform Responsiveness**:
  - **iOS**: Respects Apple Human Interface Guidelines, safe areas (Dynamic Island, top notch, bottom home indicator bar), Cupertino styling touches, and haptic feedback.
  - **Android**: Supports Material 3 dynamic styling, Android edge-to-edge transparent navigation, and camera hole-punch insets.
- **Embedded Vietnamese NLP Engine**: Parses phrases like *"50 củ"* into `50,000,000 ₫`, *"Ăn phở 65k"* into `65,000 ₫`, and classifies categories (Ăn uống, Di chuyển, Thu nhập).
- **Interactive VietQR Generator**: Automatically generates dynamic payment QR codes using standard VietQR specs (Napas247) with zero backend dependency.
- **Fully Documented in English**: Every class, function, and state controller includes comprehensive English comments explaining its purpose and behavior.

---

## 📂 Project Directory Structure

```text
flutter_tui_khon/
├── pubspec.yaml                        # Flutter package configuration & assets
├── README.md                           # Complete project guide and architecture
└── lib/
    ├── main.dart                       # App entry point with Riverpod ProviderScope
    │
    ├── core/                           # Core infrastructure & utilities
    │   ├── constants/
    │   │   ├── app_colors.dart         # Emerald (#006948), Gold (#825100), Indigo theme palette
    │   │   └── app_typography.dart     # Plus Jakarta Sans typographic scales
    │   ├── theme/
    │   │   └── app_theme.dart          # Adaptive ThemeData for Light/Dark & iOS/Android
    │   ├── network/                    # Enterprise API client & error handler
    │   │   ├── api_config.dart         # Base URLs, timeouts, endpoints dictionary
    │   │   ├── api_client.dart         # MobileApiClient with Bearer auth, retries & timeout
    │   │   └── api_exceptions.dart     # ApiException with Vietnamese UX messages
    │   ├── utils/
    │   │   ├── currency_formatter.dart # Vietnamese currency formatting (VND)
    │   │   └── responsive_helper.dart  # Screen dimension & safe-area helpers
    │   └── services/
    │       ├── local_storage_service.dart # SharedPreferences wrapper for on-device persistence
    │       └── vietnamese_nlp_service.dart# Rule-based natural language parser for slang & amounts
    │
    ├── common/                         # Shared UI components
    │   └── widgets/
    │       ├── custom_button.dart      # Reusable styled button with tactile animations
    │       ├── gradient_card.dart      # Emerald balance card with privacy toggle
    │       ├── transaction_tile.dart   # Standard transaction list item
    │       ├── vietqr_dialog.dart      # VietQR display dialog with copy & share
    │       └── app_bottom_nav.dart     # Floating bottom navigation bar
    │
    └── features/                       # Feature-based clean architecture modules
        ├── auth/                       # Initial Login Gateway Module
        │   └── presentation/
        │       └── login_screen.dart   # 1-Tap Google Sign-In, Phone & Password login
        │
        ├── home/
        │   ├── models/
        │   │   └── transaction_model.dart # Transaction & category entities
        │   ├── data/
        │   │   └── local_wallet_repository.dart # Local repository with mock seed data
        │   ├── controllers/
        │   │   └── home_controller.dart   # Manages balance, mask visibility, and transactions
        │   └── presentation/
        │       └── home_screen.dart       # Dashboard screen with balance & budget progress
        │
        ├── quick_record/
        │   ├── controllers/
        │   │   └── quick_record_controller.dart # Chat message stream & STT simulation
        │   └── presentation/
        │       └── quick_record_screen.dart # Natural language input & confirmation card
        │
        ├── split_bill/
        │   ├── models/
        │   │   └── split_bill_model.dart  # Group split session, members, and debt status
        │   ├── controllers/
        │   │   └── split_bill_controller.dart # Member settlement toggles & VietQR link
        │   └── presentation/
        │       └── split_bill_screen.dart # Split bill groups, reminders & recurring bills
        │
        ├── advisor/
        │   ├── models/
        │   │   └── advisor_report_model.dart # Category breakdown & 4-week forecast metrics
        │   └── presentation/
        │       └── advisor_screen.dart    # Donut chart & forecast bar charts
        │
        ├── pro/
            ├── controllers/
            │   └── pro_controller.dart    # Subscription plan selection & voucher logic
            └── presentation/
                ├── pro_upgrade_screen.dart# Tier selection (1-Year 40% OFF, 3-Month, 1-Month)
                └── checkout_screen.dart   # Checkout with VietQR, MoMo & 7-day trial
        │
        └── profile/
            └── presentation/
                └── profile_settings_screen.dart # User account, biometric lock, & safe logout bottom sheet
```

---

## 🛠️ How to Run on iOS and Android

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (version $\ge$ 3.16.0).
2. For iOS: macOS with Xcode 15+ and CocoaPods installed.
3. For Android: Android Studio with Android SDK 34+.

### Commands:
```bash
# 1. Navigate to the project directory
cd flutter_tui_khon

# 2. Get dependencies
flutter pub get

# 3. Run on connected iOS Simulator or Device
flutter run -d ios

# 4. Run on connected Android Emulator or Device
flutter run -d android
```

---

## 💡 State Management Architecture (Riverpod)

The app utilizes **Riverpod 2.x** with `StateNotifier` and `StateNotifierProvider`:
- **Predictable State Flow**: UI triggers actions on the controller $\rightarrow$ Controller updates repository $\rightarrow$ New immutable state is emitted $\rightarrow$ UI re-renders only affected widgets.
- **Testable**: StateNotifiers have zero dependency on BuildContext, making unit testing straightforward.
- **Zero Backend Required**: All controllers read and write to `LocalWalletRepository`, keeping all data cached on device.
