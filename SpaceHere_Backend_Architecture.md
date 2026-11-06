

# **SpaceHere: Backend Architecture**

Serverless DB Synchronization, MTProto Chunking Pipeline, & Conflict Resolution Engines

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

The SpaceHere application entirely bypasses traditional hosted backend servers (such as AWS EC2 or Node.js instances). By shifting the backend logic directly into the client-side Dart code, the application relies on a Thick-Client architecture. Data routing, encryption, and storage are offloaded to the Telegram MTProto network, operating via private channels.

2. ## **The Dual-State Storage Matrix**

To ensure high-performance UI rendering without network lag, the architecture relies on two distinct database states that constantly synchronize.

1. ### **The Local Cache (Isar / IndexedDB)**

This is the primary database the user interacts with. It is a local relational database running on the user's device.

* **Native (Android/Windows):** Powered by Isar Database.

  * **Web/Browser:** Powered by IndexedDB.

    * **Function:** It stores the Virtual File System (VFS) map, allowing instant folder navigation, file searching, and sorting without waiting for API requests.

  2. **The Remote Truth (sync\_state.json)**

Because there is no central SQL server, the application uses a flat JSON file to maintain state across devices.

* Whenever a user creates a folder or uploads a file, the local Isar database serializes its entire layout into a highly compressed JSON string.

  * This

#### **Message**.

is encrypted and uploaded to the private MTProto channel as a **Pinned**

* This pinned message acts as the single source of truth for the user's entire account.

Handling offline edits across multiple devices (e.g., modifying files on a PC while the Android phone is offline) requires a sophisticated merge strategy. SpaceHere uses a Last-Write-Wins (LWW) Element Set concept.

Files are never uploaded natively. They pass through a specialized Dart pipeline that guarantees security and bypasses API payload limits.

1. ### **Upload & Fragmentation**

   * **Stream Parsing:** The application reads the raw file as a byte stream.

     * **Encryption:** The stream is encrypted using AES-256 GCM. The key is derived locally; the server never sees it.

     * **Chunking:** The encrypted blob is cut into 50MB fragments.

     * **MTProto Transmission:** Each fragment is sent to the private channel. Telegram returns a

specific	(e.g., ID: 1042).

* **Mapping:** The local database saves an array:	.

  2. ### **Asynchronous Reassembly**

     When a user requests a file download, the backend engine reverses the process. It pulls the array, downloads the raw blocks concurrently via MTProto, decrypts them using

the saved Initialization Vector (IV), and concatenates them sequentially back into the original file.

5. ## **Codebase Abstraction Architecture**

To keep the Flutter project maintainable, the backend logic is strictly separated into three service layers:

* **Repository Layer (	):** The orchestrator. It manages the queue,

triggers the chunking engine, and dictates when the database should export the sync state.

* **Database Service (	):** Handles purely local operations—creating Isar

instances, running queries to fetch folder contents, and marking entities as soft-deleted.

* **Network Service (	):** A wrapper around TDLib (Native) and GramJS

(Web). It strictly handles OTP verification, channel creation, and raw byte transmission to the MTProto servers.