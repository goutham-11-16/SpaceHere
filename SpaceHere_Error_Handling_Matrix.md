

# **SpaceHere: Error Handling Matrix**

System Response Protocols for MTProto Network Exceptions and Device Connectivity Issues

### **Prepared by: Esambadi Goutham Reddy**

Computer Science Engineering (AI & ML) Kalasalingam Academy of Research and Education

1. ## **Overview**

Because SpaceHere leverages a third-party messaging API (MTProto) for file storage, it is subjected to strict rate limits and network volatility. The AI coding agent MUST implement robust error catching within

the

and resumed.

to ensure the application never crashes and file queues can be safely paused

2. ## **The Throttling & Exception Matrix**

The following table outlines the exact exception triggers and the mandatory programmatic responses required in the Flutter/Dart codebase.

|  Error Condition | Trigger Context |  Required Code Response |
| :---- | :---- | :---- |
|  FLOOD\_WAIT\_X | Uploading chunks too quickly triggers Telegram's anti-spam API limits. |  Halt queue. Parse the X value (in seconds) from the exception string. Await Future.delayed(Duration(seconds: X \+ 2)) for a safety buffer. Resume the upload silently without alerting the user. |
|  NETWORK\_DROPPED | User loses WiFi or Mobile data connection mid-upload. | Catch SocketException . Store the current chunkIndex and active file ID locally. Pause the upload queue. Subscribe to the Connectivity stream and await a network return, then resume exactly from the saved index. |
|  CHANNEL\_DELETED | User manually deleted the backend Vault channel via the official Telegram client app. |  Catch CHANNEL\_INVALID or CHANNEL\_PRIVATE . Trigger a fatal alert dialog in the UI. Prompt user to "Re-initialize Vault" which will recreate the channel and reset the Isar sync\_state.json logic. |
|  AUTH\_KEY\_UNREGISTERED | Telegram session was revoked from another device. |  Catch unauthorized exception. Clear the local session from flutter\_secure\_storage . Redirect the GoRouter to the Login onboarding screen immediately. |

3. ## **Implementation Rules**

All network calls to TDLib or GramJS must be wrapped in generic \`try/catch\` blocks that route to a centralized exception parser. UI Notifiers must be updated based on the parsed state (e.g., updating the queue UI to say "Waiting for Network..." during a \`SocketException\`).