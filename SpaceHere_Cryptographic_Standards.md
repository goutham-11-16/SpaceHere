

# **SpaceHere: Cryptographic Standards**

Zero-Knowledge Implementation Rules, AES-256 Specifications, and Key Derivation Constraints

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

1. ## **The Zero-Knowledge Mandate**

Because SpaceHere utilizes third-party infrastructure (Telegram MTProto) for storage, **absolute Zero-Knowledge privacy is strictly enforced.** The application code must guarantee that no unencrypted byte of user data, and no portion of the user's master encryption key, ever leaves the local device.

2. ## **Core Cryptographic Primitives**

The AI Agent MUST implement the following specific cryptographic standards. Legacy algorithms (e.g., DES, AES-CBC without HMAC) are strictly prohibited.

|  Component | Standard Requirement |  Technical Justification |
| :---- | :---- | :---- |
|  **Core Cipher** | AES-256 (Advanced Encryption Standard) | Military-grade symmetric encryption. Provides computational security against brute-force attacks. |
|  **Cipher Mode** |  GCM (Galois/Counter Mode) | Provides Authenticated Encryption with Associated Data (AEAD). Ensures data cannot be maliciously modified (tamper-evident) in the Telegram channel without failing decryption. |
| **Key Derivation (KDF)** | PBKDF2 with HMAC-SHA256 | Protects the user's PIN/Password from dictionary attacks. Must be executed with exactly **100,000 iterations**. |
| **Initialization Vector (IV)** | 12-byte (96-bit) CSPRNG | Required for AES-GCM. A fresh IV must be generated for *every single file* to prevent nonce-reuse vulnerabilities. |

3. ## **Key Management & Local Storage**

The Master Key must never be hardcoded or saved in plain text within the Isar database or JSON state.

* **Derivation:** Upon user login/setup, prompt the user for a "Vault PIN" or Password. Run this string through the PBKDF2 function with a unique, securely generated 16-byte salt to generate the 256-bit Master Key.

  * **Storage:** The 256-bit Master Key and the Salt must be stored *exclusively* in the OS-level secure hardware layer.

    * Use flutter\_secure\_storage for Android/iOS/Desktop.

    * The key is loaded into RAM only during active upload/download sessions and cleared immediately afterward.

4. ## **The Encryption/Decryption Pipeline Pipeline**

The application logic must adhere to this exact sequence of operations to ensure data is secure before hitting the MTProto network layer:

