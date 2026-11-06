

# **SpaceHere: Project Scaffold & Dependencies**

Strict Folder Structures, pubspec.yaml Configurations, and Routing Specifications for AI Development

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

1. ## **The Authorized Dependency Manifest (pubspec.yaml)**

The AI Agent MUST utilize the following dependencies. Inventing custom packages or using legacy state management (like Provider/GetX) is strictly prohibited.

2. ## **Required Directory Architecture**

The Flutter lib/ folder MUST be structured using a Feature-Driven Architecture. Do not place business logic inside UI widget files.

| lib/ |  |  |  |
| ----- | :---- | ----- | :---- |
| ├── | main.dart |  |  |
| ├── | core/ | \# | Global utilities and configurations |
| │ | ├── routing/ | \# | go\_router configuration files |
| │ | ├── theme/ | \# | Cosmic Minimalism color palettes & text styles |
| │ | └── exceptions/ | \# | Custom error classes (e.g., FloodWaitException) |
| │ |  |  |  |
| ├── | features/ | \# | Feature-based UI and State |
| │ | ├── auth/ | \# | Email/Telegram OTP login screens |
| │ | ├── dashboard/ | \# | Bento-box layout, space health metrics |
| │ | ├── storage/ | \# | VFS Navigation, folder logic, upload queues |
| │ | └── settings/ | \# | Key management, clear cache, logout |
| │ |  |  |  |
| ├── | services/ | \# | Pure business logic and third-party APIs |
| │ | ├── database/ | \# | isar\_service.dart |
| │ | ├── network/ | \# | telegram\_service.dart |
| │ | ├── crypto/ | \# | aes\_encryption\_service.dart |
| │ | └── repository/ | \# | space\_repository.dart (Orchestrator) |
| │ |  |  |  |
| └── | models/ | \# | Data classes |
|  | ├── space\_node.dart | \# | The Isar collection schema |
|  | └── sync\_state.dart | \# | JSON serialization logic |

3. ## **Navigation & Routing (GoRouter)**

Do NOT use Navigator.push(). The application MUST use GoRouter for safe, deep-linkable URL mapping across mobile and web.

| Route Path | Widget Target | Navigation Guard Rules |
| :---- | :---- | :---- |
|  /login |  AuthScreen() | If Master Key exists in secure storage, redirect to /dashboard. |
| / telegram\_otp |  TelegramVerificationScreen() | Requires passing the phone number as an extra object. |
| /dashboard | DashboardScreen() | Root app view. Cannot pop back to login. |
| / folder/:uuid |  FolderViewScreen() | Passes the parent UUID in the path parameters to load specific children. |

4. ## **Native Initialization Safety Protocol**

The AI Agent MUST initialize Isar and the native TDLib C++ bindings before runApp() is called. Failure to do so will result in an immediate runtime crash on Android and Desktop.  
