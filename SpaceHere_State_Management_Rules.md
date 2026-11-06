

# **SpaceHere: State Management Architecture**

Strict Riverpod Guidelines & Dependency Injection Rules for AI Code Generation

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

1. ## **The State Management Mandate**

To prevent business logic from bleeding into the User Interface, the SpaceHere Flutter application MUST be built using **Riverpod (flutter\_riverpod)**. The AI agent is strictly forbidden from using setState for network requests, database queries, or complex queue management. BLoC, Provider,  
and GetX are explicitly disallowed.

2. ## **Dependency Injection Hierarchy**

The application relies on three core singleton services. These must be provided globally so they can be injected into active state notifiers and UI widgets.

3. ## **Virtual File System (VFS) Navigation State**

Folder navigation works by updating a single state provider (currentDirectoryProvider). When this ID changes, the UI automatically listens and fetches the children of that directory via an

AsyncNotifierProvider.

**UI Implementation Rule:** The UI MUST use Riverpod's .when() method to render the VFS. It must handle the data, loading, and error states explicitly to prevent blank screens.

4. ## **The Throttled Upload Queue State**

The 8-14 second randomized upload throttle runs in the background. It must be managed by an

AsyncNotifier that exposes the queue's progress without freezing the Flutter UI thread.

* **State Object:** A custom class (e.g., QueueState) containing isUploading, currentFile, and

progressPercentage.

* **Execution Rule:** The upload loop must run asynchronously. The Riverpod Notifier updates the

progressPercentage state, which the "Cosmic Minimalism" UI layer watches to draw the pulsing "weaving" animation ring.