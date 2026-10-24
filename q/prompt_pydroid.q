ROLE
You are a senior Python developer who writes Android-friendly GUI code for Pydroid 3.
ENVIRONMENT / HARD CONSTRAINTS
- Target: Pydroid 3 on Android. Touch input only, no desktop, no keyboard shortcuts.
- GUI framework: [Kivy | Tkinter] (must install cleanly from Pydroid 3's Pip menu).
- Python: Pydroid 3's bundled version [3.11].
- Allowed third-party libs: [kivy, requests] — nothing needing a C compiler or NDK.
- No root, no ADB, no server of my own.
- Must run by pressing ▶ in Pydroid 3. Single file. No assets, no subfolders.
APP GOAL
Build a chatbot GUI called [APP NAME] that lets me [chat with an LLM API / chat with an offline rule-based bot].
UI REQUIREMENTS
- Layout: [scrollable chat history on top, text input + Send button pinned at the bottom].
- Style: [dark theme, user messages right-aligned, bot messages left-aligned, rounded bubbles].
- Touch-friendly: buttons >= 48dp tall, font size >= 16sp.
- Show a "typing…" indicator while waiting for a reply.
- Auto-scroll to the newest message.
- Survive rotation and Android's back gesture without crashing.
CHATBOT LOGIC
- Backend: [OpenAI-compatible REST API | my own endpoint | offline rules].
- Endpoint: [URL].
- Auth: read the API key from [a KEY = "..." constant at the top | a user input field].
- Model: [MODEL NAME].
- Keep conversation history in memory and send the full history on each call.
- System prompt: [YOUR SYSTEM PROMPT].
- Streaming: [no | yes].
RELIABILITY
- All network calls off the main thread so the UI never freezes.
- try/except around every request; show errors as a bot message, never crash.
- Request timeout of [30] seconds.
- Friendly message when there is no internet.
OUTPUT FORMAT
1. One complete single-file script, ready to paste into Pydroid 3.
2. A short comment header listing the pip packages to install.
3. A CONFIG block at the very top with every value I need to edit.
4. After the code, a 5-line note on how to run it and the top 3 things that usually go wrong.
Do not use placeholders like "# your code here" — the script must run as-is once CONFIG is filled in.