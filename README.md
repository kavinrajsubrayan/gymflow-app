# 🏋️ GymFlow

**GymFlow** is a modern gym management mobile application built with Flutter that revolutionizes the way gym members interact with their fitness facility.

## ✨ Features

### 🎯 Core Functionality
- **Equipment Booking System**: Reserve gym equipment in advance to avoid waiting times
- **Real-time Equipment Status**: Check equipment availability in real-time
- **My Bookings**: View and manage all your equipment reservations
- **AI Fitness Assistant**: Get personalized workout recommendations powered by AI
- **User Authentication**: Secure sign-up and login with Firebase Authentication
- **Profile Management**: Update and manage your personal information

### 🛠️ Technical Features
- **Firebase Integration**: 
  - Firestore for real-time database
  - Firebase Authentication for secure user management
  - Cloud storage for user data
- **Real-time Updates**: Live equipment status tracking
- **Cross-platform**: Runs on Android and iOS
- **Modern UI**: Clean, intuitive interface built with Flutter

## 📱 Screenshots

*(Add screenshots of your app here)*

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / Xcode
- Firebase account

### Installation

1. **Clone the repository**
```bash
   git clone https://github.com/kavinrajsubrayan/gymflow-app.git
   cd gymflow-app
```

2. **Install dependencies**
```bash
   flutter pub get
```

3. **Set up Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android/iOS apps to your Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories

4. **Configure environment variables**
   - Create a `.env` file in the root directory
   - Add your API keys and configuration

5. **Run the app**
```bash
   flutter run
```

## 🏗️ Project Structure
```
lib/
├── models/              # Data models
│   ├── equipment.dart
│   └── equipment_booking.dart
├── screens/             # UI screens
│   ├── welcome_screen.dart
│   ├── signin_screen.dart
│   ├── signup_screen.dart
│   ├── home_screen.dart
│   ├── book_equipment_screen.dart
│   ├── my_bookings_screen.dart
│   ├── profile_screen.dart
│   └── ai_fitness_assistant_screen.dart
├── services/            # Business logic & API calls
│   ├── booking_service.dart
│   ├── equipment_service.dart
│   ├── equipment_status_service.dart
│   ├── real_time_equipment_service.dart
│   └── ai_service.dart
├── widgets/             # Reusable widgets
│   └── equipment_status_widget.dart
└── utils/               # Helper functions
    ├── firestore_debug_helper.dart
    ├── fix_equipment_status.dart
    ├── gym_occupancy_service.dart
    └── test_booking_time.dart
```

## 🔧 Built With

- **[Flutter](https://flutter.dev/)** - UI framework
- **[Firebase](https://firebase.google.com/)** - Backend services
  - Firestore - Database
  - Authentication - User management
- **[Dart](https://dart.dev/)** - Programming language

## 📦 Dependencies

Key packages used in this project:
- `firebase_core` - Firebase SDK
- `cloud_firestore` - Firestore database
- `firebase_auth` - Authentication
- `http` - API calls for AI assistant
- *(Check `pubspec.yaml` for complete list)*

## 🎯 Future Enhancements

- [ ] Push notifications for booking reminders
- [ ] QR code scanning for equipment check-in
- [ ] Workout tracking and analytics
- [ ] Social features (friend challenges, leaderboards)
- [ ] Payment integration for memberships
- [ ] Multi-gym support
- [ ] Dark mode

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Kavinraj Subrayan**
- GitHub: [@kavinrajsubrayan](https://github.com/kavinrajsubrayan)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- All contributors and testers

---

**Made with ❤️ and Flutter**
