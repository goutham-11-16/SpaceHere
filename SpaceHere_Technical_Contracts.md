

# **SpaceHere: Technical Data Contracts**

JSON Schemas, Cryptographic Standards, State Management Rules, & System Error Matrices for AI Agents

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

1. ## **The Sync State JSON Schema**

This is the exact JSON structure that MUST be used to serialize the local Isar database into the

sync\_state.json file pinned to the MTProto channel. Deviating from this schema will cause fatal cross-platform synchronization failures.

2. ## **Cryptographic Implementation Standards**

For zero-knowledge privacy, the AI must implement encryption exactly according to these standards before any byte stream touches the MTProto API.

* **Algorithm:** AES-256 (Advanced Encryption Standard).

  * **Cipher Mode:** GCM (Galois/Counter Mode) to ensure both confidentiality and data authenticity.

  * **Key Derivation Function (KDF):** PBKDF2 with HMAC-SHA256. Must use exactly 100,000 iterations and a unique 16-byte salt per user session.

  * **Initialization Vector (IV):** Generate a fresh 12-byte (96-bit) cryptographically secure random number (CSPRNG) for *every* individual file. Store this Base64-encoded IV in the JSON schema.

3. ## **Flutter Architecture & State Management**

To avoid tightly coupled spaghetti code, the UI must be completely separated from the backend logic. The AI Agent must build the application using the following strict structural constraints:

* **State Management Package:** Riverpod (specifically flutter\_riverpod). Do NOT use generic

setState, BLoC, or Provider.

* **Dependency Injection:** Use Riverpod Providers to inject the SpaceRepository, DatabaseService, and TelegramService into the widget tree.

  * **Asynchronous UI:** Use Riverpod's AsyncValue (.when(data:, loading:, error:)) to natively handle all file loading and network request states.

  * **Folder Navigation:** Use a \`StateNotifier\` to track the currentParentUuid. Changing this ID triggers the database service to yield a new list of file nodes for that specific directory.

4. ## **Error Handling & API Throttling Matrix**

Telegram's API will throttle or reject bad network requests. The AI must implement the following error handlers natively within the SpaceRepository upload loop.

| Error Condition | Trigger Context | Required Code Response |
| :---- | :---- | :---- |
|  FLOOD\_WAIT\_X |  Uploading chunks too quickly. | Halt queue. Parse the X value (in seconds). Await Future.delayed(X \+ 2s buffer). Resume upload silently. |
|  NETWORK\_DROPPED |  User loses WiFi/ Mobile data. | Catch SocketException. Store the current chunkIndex locally. Pause queue. Await Connectivity stream return, then resume. |
|  CHANNEL\_DELETED | User deleted the backend Vault channel via official Telegram app. |  Catch CHANNEL\_INVALID. Trigger fatal alert in UI. Prompt user to "Re-initialize Vault" and reset the Isar sync\_state. |
|  AUTH\_KEY\_UNREGISTERED | Telegram session revoked. | Clear local session secure storage. Redirect GoRouter to login screen immediately. |

