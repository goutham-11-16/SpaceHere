

# **Distributed Cloud Storage Architecture**

A Serverless, Infinite-Capacity Virtual File System leveraging MTProto

Prepared by: Esambadi Goutham Reddy Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education  
Project Application Name: SpaceHERE  
Package Name: com.gou.spacehere

Technical Specification & Implementation Plan

## **Executive Summary**

This technical specification outlines the architecture for a highly scalable, zero-cost, cross-platform cloud storage application. The system operates as a Virtual File System (VFS) that maps a seamless, folder-based user interface to a decentralized storage backbone utilizing Telegram's MTProto private channels.

By leveraging intelligent client-side processing via Flutter and Android Studio environments, local database state synchronization, and military-grade AES-256 encryption, the architecture completely eliminates the need for centralized backend server hosting. The resulting ecosystem provides an unlimited storage vault accessible natively across Android, Web, and Desktop environments.

## **System Architecture**

### **Core Technology Stack**

* **Frontend / UI Framework:** Flutter (Dart) for high-performance, unified codebase deployment across mobile, web, and desktop.

  * **Client API Bridge:** TDLib (Telegram Database Library) for native environments (Android/ Desktop) and GramJS for the Web environment, directly connecting to the MTProto protocol.

    * **Local State Management:** Isar Database (for native platforms) and IndexedDB (for Web) to cache and query virtual directory structures at high speeds.

    * **Security Layer:** Local AES-256 GCM encryption.

    ### **Hybrid Authentication Flow**

To establish an independent application ecosystem, a two-tier authentication pipeline is implemented:

1. **Application Identity (Layer 1):** Users authenticate via standard Email/OTP (e.g., Firebase/ Supabase Auth). This secures the user interface and independent profile data.

2. **Vault Linkage (Layer 2):** Users provide a secondary/dedicated Telegram phone number, verified via official MTProto OTP. This securely bridges the application session to the decentralized storage vault without requiring ongoing login prompts.

   ## **Data Processing & Chunking Engine**

Directly uploading massive files to a messaging API creates system instability and violates fair-use behaviors. The application intercepts user files and routes them through a specialized local pipeline.

### **The Upload Pipeline**

### **Dynamic Throttling & Queue Management**

To safeguard the user's API access against automated FloodWait bans, a chaotic-interval throttling mechanism is employed.

* **Instant Queue (Files \< 20MB):** Documents and photos are uploaded immediately without artificial delays.

  * **Throttled Queue (Large Media):** For gigabyte-scale files, the upload loop injects a randomized jitter delay of **8 to 14 seconds** between chunk transmissions. This mimics human pacing and prevents algorithmic flagging. Users are notified via a non-blocking background queue UI.

  ## **Database Schema & State Synchronization**

    ### **Virtual File System Mapping (Isar Schema)**

The application maintains an adjacency-list hierarchy locally to construct the illusion of folders. The following core entity maps local UI state to remote message IDs:

| Field Name | Data Type | Purpose / Behavior |
| ----- | ----- | ----- |
| id / uuid | Int / String | Global unique identifier for conflict resolution across devices. |
| parentUuid | String (Nullable) | Identifies the parent folder. Null indicates the Root directory. |
| mimeType | String | Enables rapid sorting into "Photos", "Videos", or "Documents" tabs. |
| chunkMessageIds | Array\[Int\] | The exact MTProto message IDs containing the encrypted 50MB blocks. |
| isDeleted | Boolean | Soft-delete flag to propagate deletions accurately during offline/online sync. |

### **Cross-Platform Synchronization Engine**

To avoid "split-brain" conflicts without a central database server, the application utilizes the Telegram channel's "Pinned Message" functionality as the single source of truth.

1. **Local Mutation:** A user creates a folder on their Desktop. The Isar database updates locally.

2. **State Export:** The entire local database maps to a lightweight

   which is uploaded and pinned in the private \`\[DO NOT DELETE\]\` channel.

file,

3. **Remote Fetch:** When the Android client opens, it queries the channel for the newest pinned message.

4. **Conflict Resolution:** Timestamps are compared. The incoming JSON merges over the local Isar database, ensuring instantaneous ecosystem parity.

   ## **Plan of Action (Implementation Roadmap)**

The project will be developed iteratively in four distinct phases to ensure stability at each tier of the architecture.

#### **Phase 1: Environment & Authentication Layer**

* Initialize Flutter multi-platform repository.

  * Implement Email Auth and layout the core Dashboard UI (Bottom Navigation for mobile, Sidebar for Desktop).

  * Integrate TDLib/GramJS to handle MTProto phone authentication and automatic private channel creation.

    #### **Phase 2: The Core Storage Engine**

  * Develop local file reading and memory-efficient chunking logic.

  * Implement the AES-256 encryption pipeline.

  * Construct the background upload queue with the randomized 8-14 second throttling algorithm.

    #### **Phase 3: Database & Ecosystem Sync**

  * Deploy the Isar schema for local VFS mapping.

  * Write the JSON export/import bridge.

  * Implement the pin-and-fetch state synchronization logic across devices.

    #### **Phase 4: Polish & Edge-Case Handling**

  * Handle partial upload failures, network drops, and corrupted chunks.

  * Refine UI elements (e.g., categorizing files based on MIME types).

  * Implement protective event listeners (catching if a user manually deletes a message in Telegram and reflecting it in the app).

  ## **Conclusion**

This architecture transforms a messaging protocol into a highly secure, distributed virtual file system. By shifting the processing burden to the client device and utilizing intelligent database

synchronization, the system provides a robust, unlimited-capacity ecosystem that operates completely independently of expensive backend infrastructure.