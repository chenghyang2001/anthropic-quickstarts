# App Specification: PodcastBrain — Podcast Transcription & Knowledge Extractor

## Project Overview

PodcastBrain is a Streamlit web application that converts podcast episodes and YouTube videos
into structured knowledge assets. Users provide a URL or upload an audio file; yt-dlp downloads
the audio, and OpenAI Whisper transcribes it locally without sending audio to any external API.
Claude then analyzes the transcript to generate chapter timestamps, a concise summary, key quotes,
and action items. An interactive Q&A mode lets users ask questions answered directly from the
episode transcript. The result is a permanent searchable library of episode knowledge.

---

## Technology Stack

| Layer            | Technology                                       |
|------------------|--------------------------------------------------|
| Language         | Python 3.11+                                     |
| Web Framework    | Streamlit                                        |
| Audio Download   | yt-dlp                                           |
| Transcription    | openai-whisper (local, no API key required)      |
| AI Analysis      | Anthropic Claude API (`claude-sonnet-4-6`)       |
| Database         | SQLite (via SQLAlchemy 2.x ORM)                  |
| Audio Processing | pydub (format conversion, duration)              |
| Text Search      | SQLite FTS5 (full-text search across transcripts)|
| Export           | markdown, reportlab (PDF), srt (subtitle export) |
| Dependencies     | streamlit, yt-dlp, openai-whisper, anthropic,    |
|                  | sqlalchemy, pydub, reportlab                     |

---

## Core Features

### 1. Audio Input — URL and File Upload
- URL input field: accepts YouTube, Spotify (public), direct MP3/M4A URLs
- yt-dlp downloads best-quality audio-only stream to temp folder
- File upload widget: accepts mp3, m4a, wav, ogg (max 500MB)
- Input validation: check URL reachability before starting download
- Estimated file size and duration shown before processing starts
- Cancel button: kills yt-dlp subprocess if download takes > 60s

### 2. Local Whisper Transcription
- Model selection: tiny / base / small / medium / large (user selects per speed vs quality tradeoff)
- Transcription runs in subprocess to avoid blocking Streamlit main thread
- Progress bar: estimated progress based on audio duration / expected processing time
- Whisper returns: full text + segments with start/end timestamps
- Segments stored in DB as JSON for Q&A and chapter detection
- Word-level timestamps enabled when model = medium or large (for highlight feature)
- Language auto-detection (Whisper built-in); user can override to force language

### 3. Claude AI Analysis — Chapter Detection
- Send full transcript (chunked if > 100k chars) to Claude
- Claude identifies chapter boundaries based on topic shifts
- Returns JSON: `[{title, start_seconds, end_seconds, summary_2_sentences}]`
- Chapters displayed as clickable timeline bar in Streamlit
- Fallback: if episode < 10 minutes, skip chapter detection (single chapter)
- Chapter edit mode: user can rename or merge chapters before saving

### 4. Claude AI Analysis — Summary and Insights
- Summary (3-5 paragraphs): main topics, arguments, conclusions
- Key quotes: 5-7 verbatim excerpts with timestamps
- Action items: bullet list of concrete next steps mentioned by speaker
- Guest / speaker identification: Claude infers names from transcript context
- Sentiment analysis: overall episode tone (educational / debate / interview / storytelling)
- All analysis stored as structured JSON in episodes.claude_analysis

### 5. "Ask the Episode" Q&A Mode
- Text input: user types any question about episode content
- Relevant transcript segments retrieved by keyword + Claude context window
- Claude answers using only transcript content (no hallucination outside source)
- Answer includes: response text + supporting quote + timestamp reference
- Q&A history stored per episode in qa_history table
- "Cite the transcript" toggle: forces Claude to quote exact source before answering
- Batch Q&A: run a list of questions and get all answers at once

### 6. Export Options
- Markdown notes: title, summary, chapters, key quotes, action items
- PDF with timestamps: same content, formatted A4 (reportlab)
- SRT subtitle file: Whisper segments converted to SRT timestamp format
- Plain transcript TXT: raw text only
- Export all episodes as ZIP archive
- Clipboard copy: one-click copy of summary or specific section

### 7. Episode Library with Search
- All processed episodes saved to SQLite with metadata
- Full-text search: SQLite FTS5 across all transcripts simultaneously
- Search results: episode title + matching excerpt + timestamp link
- Filter by: date range, duration, source URL domain
- Episode detail view: shows all tabs (transcript / chapters / analysis / Q&A)
- Sort by: date added, duration, episode title

### 8. Batch Processing Queue
- Queue manager: add multiple URLs or files before processing starts
- Queue table: shows status (pending / downloading / transcribing / analyzing / done)
- Sequential processing: one at a time to respect hardware limits
- Estimated total time shown based on audio duration * processing factor
- Email notification on queue complete (optional SMTP config)
- Pause/resume queue without losing progress

---

## Database Schema

```sql
CREATE TABLE episodes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT,
    source_url      TEXT,
    source_type     TEXT NOT NULL DEFAULT 'youtube',  -- youtube | upload | url
    audio_path      TEXT,                             -- local temp file path
    duration_secs   INTEGER,
    whisper_model   TEXT DEFAULT 'base',
    language        TEXT DEFAULT 'en',
    status          TEXT DEFAULT 'pending',           -- pending|downloading|transcribing|analyzing|done|error
    error_message   TEXT,
    claude_analysis TEXT,                             -- JSON: summary, quotes, actions, chapters
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at    DATETIME
);

CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id  INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    full_text   TEXT NOT NULL,
    segments    TEXT NOT NULL,                       -- JSON: [{start, end, text}]
    word_count  INTEGER,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE chapters (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id      INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    start_seconds   INTEGER NOT NULL,
    end_seconds     INTEGER,
    summary         TEXT,
    sort_order      INTEGER DEFAULT 0
);

CREATE TABLE qa_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id  INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    question    TEXT NOT NULL,
    answer      TEXT NOT NULL,
    source_ts   INTEGER,                             -- timestamp in seconds of supporting quote
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- FTS5 virtual table for full-text search
CREATE VIRTUAL TABLE transcripts_fts USING fts5(
    episode_id UNINDEXED,
    full_text,
    content='transcripts',
    content_rowid='id'
);
```

---

## Architecture / UI Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  PodcastBrain                                                    │
├───────────────────────┬──────────────────────────────────────────┤
│  SIDEBAR              │  MAIN AREA                               │
│                       │                                          │
│  🎙 PodcastBrain      │  ┌────────────────────────────────────┐  │
│                       │  │  🔗 Paste URL or upload audio      │  │
│  [+ New Episode]      │  │  ──────────────────────────────    │  │
│                       │  │  URL: [________________________]   │  │
│  📚 Library           │  │       [Process Episode]            │  │
│  ─────────────        │  └────────────────────────────────────┘  │
│  Lex Fridman #401     │                                          │
│  ✅ 2h 34m            │  ── Processing Status ──                 │
│                       │  ✅ Download complete (124 MB)           │
│  How I Built This     │  ✅ Transcription: 100% (whisper/base)   │
│  ✅ 45m               │  ⏳ Claude analysis in progress...       │
│                       │                                          │
│  My First Million     │  ── Episode: Lex Fridman #401 ──         │
│  🔄 Processing...     │  [Summary][Chapters][Transcript][Q&A]   │
│                       │                                          │
│  [🔍 Search all]      │  CHAPTERS TAB:                           │
│                       │  ──────────────────────────────────     │
│  QUEUE (1 pending)    │  0:00 ── Intro & Guest Background        │
│  ─────────────        │  12:34 ── Main Topic: AGI Timeline       │
│  Guy Raz Ep 302       │  45:20 ── Debate: Safety vs Progress     │
│  [Pause Queue]        │  1:22:10 ── Personal Stories             │
│                       │  1:55:44 ── Rapid Fire Q&A               │
└───────────────────────┴──────────────────────────────────────────┘

Q&A TAB:
┌──────────────────────────────────────────────────────────────────┐
│  Ask about this episode:                                         │
│  [What does the guest think about open source AI models?      ]  │
│                           [Ask]  [☑ Cite transcript]            │
│  ────────────────────────────────────────────────────────────    │
│  Answer: The guest argues that open source AI is essential for  │
│  safety research, citing the need for independent verification.  │
│  Source: "open models allow anyone to inspect the weights..."    │
│  📍 Timestamp: 48:22 — [Jump to section]                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Key Interactions

### Interaction 1: URL to Processed Episode
```
User pastes YouTube URL and clicks "Process Episode"
  → URL validation: httpx HEAD request to check reachability
  → Episode row inserted with status='downloading'
  → yt-dlp subprocess launched:
      yt-dlp -x --audio-format mp3 -o /tmp/pb/{episode_id}.mp3 {url}
  → Streamlit polls episode status every 3s (st.rerun + DB read)
  → On download complete → status='transcribing'
  → Whisper subprocess launched:
      whisper /tmp/pb/{id}.mp3 --model base --output_format json
  → Whisper JSON parsed: full_text + segments stored in transcripts table
  → Status='analyzing'
  → Claude called: chapter detection + summary + quotes + action items
  → claude_analysis JSON stored in episodes table
  → Status='done'
  → Episode appears in sidebar library, main area shows analysis tabs
```

### Interaction 2: Q&A Against Transcript
```
User types: "What does the guest say about consciousness?"
  → Question submitted
  → Retrieve transcript segments containing keywords: consciousness, aware, sentient
  → Select top 10 segments by keyword density (simple TF matching)
  → Build Claude prompt:
      "Answer using ONLY the transcript excerpts below.
       If the answer is not in the transcript, say 'Not discussed in this episode.'
       Question: {question}
       Transcript excerpts: {segments_text}"
  → Claude returns: answer_text + supporting_quote + timestamp
  → qa_history row inserted
  → Answer displayed with quote block and timestamp link
  → "Was this helpful?" thumbs up/down (stored in qa_history.helpful)
```

### Interaction 3: Batch Queue Processing
```
User adds 5 URLs to queue via "Add to Queue" button on URL input
  → 5 episodes inserted with status='pending'
  → Queue processor starts (background thread):
      while pending_episodes:
          ep = get_next_pending()
          process_episode(ep)  -- download → transcribe → analyze
          mark_done(ep)
  → Queue table in sidebar updates every 5s via Streamlit rerun
  → On all done:
      If SMTP configured: send email "PodcastBrain: 5 episodes processed"
  → User sees all 5 episodes in library with full analysis
```

---

## Implementation Steps

1. **Project scaffold**: Streamlit app with multi-page layout, SQLAlchemy models with
   FTS5 virtual table trigger setup, temp folder management for audio files.

2. **yt-dlp download module**: `downloader.py` — subprocess wrapper for yt-dlp with progress
   line parsing, cancel support via `subprocess.terminate()`, metadata extraction.

3. **Whisper transcription module**: `transcriber.py` — subprocess call to whisper CLI,
   JSON output parsing into segments list, progress estimation by audio duration.

4. **Claude analysis module**: `analyzer.py` — three separate Claude calls:
   (1) chapters JSON, (2) summary+quotes+actions, (3) speaker identification.
   Each call has retry logic and response schema validation.

5. **Streamlit UI — Input and Processing**: URL input form, file upload, processing status
   display using `st.status()` container with real-time step updates.

6. **Streamlit UI — Episode Viewer**: Four-tab layout (Summary / Chapters / Transcript / Q&A),
   chapter timeline using `st.progress` segments, transcript with timestamp anchors.

7. **Q&A engine**: `qa_engine.py` — keyword-based segment retrieval, Claude prompt builder
   with "cite only transcript" constraint, response parser for answer + quote + timestamp.

8. **Library, search, export**: FTS5 search with `st.text_input`, episode card grid,
   export functions for MD/PDF/SRT/TXT, batch queue manager with status table.

---

## Success Criteria

### Functional
- 1-hour audio transcribed by Whisper base model in < 8 minutes on CPU
- Claude generates 5+ chapters for episode > 30 minutes with accurate timestamps
- Q&A mode answers question correctly from transcript in > 80% of test cases
- FTS5 search returns relevant results across 100 episodes in < 500ms
- Export produces valid SRT file playable in VLC

### UX
- Processing status updates visible within 3 seconds of each stage completion
- Chapter timeline bar clickable and shows chapter summary on hover
- Q&A answer appears within 10 seconds of submitting question
- Library sidebar shows episode list without scroll lag for 200+ episodes

### Technical Quality
- Audio files cleaned up from temp folder after successful DB storage reference
- Whisper and Claude calls run in threads with Streamlit-safe state updates
- FTS5 index kept in sync via SQLite triggers on transcript insert/update/delete
- All Claude API calls have 45-second timeout and 2-retry with exponential backoff
- `ANTHROPIC_API_KEY` read from environment variable, never hardcoded
- Unit tests: segment timestamp parsing, chapter JSON validation, FTS5 query builder
