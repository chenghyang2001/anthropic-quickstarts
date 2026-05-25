# App Specification: MeetingMind

## Project Overview

MeetingMind is a desktop application that records, transcribes, and summarizes meetings
entirely on-device. Audio captured via microphone (or imported from file) is transcribed
using OpenAI Whisper running locally, then Claude generates a structured summary: agenda
items, decisions made, and action items with owners. No audio or transcript ever leaves
the user's machine.

**Primary audience:** Knowledge workers, project managers, and remote teams who need
searchable, actionable records of meetings without cloud dependencies or subscription costs.

---

## Technology Stack

| Layer           | Technology                                    |
|-----------------|-----------------------------------------------|
| UI framework    | PyQt6 6.7                                     |
| Audio capture   | PyAudio 0.2.14                                |
| Audio/video I/O | ffmpeg-python (subprocess wrapper)            |
| Transcription   | openai-whisper (local, CPU/GPU)               |
| AI summaries    | Anthropic Claude (claude-sonnet-4-6)         |
| Database        | SQLite (via SQLAlchemy 2.0)                   |
| Export          | python-docx, fpdf2, Markdown (built-in)       |
| Search          | SQLite FTS5 full-text search                  |

---

## Core Features

### 1. Audio Recording
- Start/stop/pause recording controls in the UI toolbar
- Live audio level meter (VU meter widget, PyQt6 canvas)
- Configurable input device selection from all available microphones
- Recording saved as 16kHz mono WAV for optimal Whisper performance
- Auto-save every 5 minutes to prevent data loss

### 2. File Import
- Drag-and-drop or file picker: accepts WAV, MP3, M4A, MP4, MKV, WebM
- ffmpeg extracts audio track from video files automatically
- Progress dialog during extraction with cancel option
- Validates audio duration: warns if > 3 hours (Whisper memory limit)

### 3. Local Transcription via Whisper
- Model selection: tiny / base / small / medium (user chooses speed vs. accuracy)
- Transcription runs in background QThread (UI remains responsive)
- Progress bar shows transcription completion percentage
- Whisper returns word-level timestamps — used for clickable transcript navigation
- Language auto-detection with manual override option

### 4. AI-Powered Summarization
- Claude receives full transcript text + meeting metadata (title, participants)
- Structured output: meeting purpose, agenda items, key decisions, action items
- Action items format: `[ ] Task description — Owner: @name — Due: date`
- Summary rendered in right panel with collapsible sections
- Re-summarize button to regenerate with custom focus instructions

### 5. Speaker Diarization
- Basic speaker separation: detects speaker changes using audio energy + pause analysis
- Labels assigned automatically: Speaker 1, Speaker 2, Speaker 3
- User can rename labels via double-click in transcript (persisted to DB)
- Diarization displayed as colored blocks in the transcript timeline scrubber

### 6. Export Options
- **DOCX**: meeting header, agenda table, transcript body, action item checklist
- **PDF**: formatted via fpdf2, company logo placeholder, page numbers
- **Markdown**: Notion-compatible with checkbox syntax for action items
- **CSV**: action items only (for import into project management tools)
- Batch export: select multiple meetings from list and export all

### 7. Full-Text Search
- SQLite FTS5 index over all transcript text
- Search bar in sidebar: instant results as user types
- Results show meeting title, date, and matching excerpt with keyword highlight
- Filter by date range, participant name, or has-action-items flag

### 8. Calendar Integration
- Import `.ics` files to pre-populate meeting metadata (title, attendees, time)
- Upcoming meetings panel shows next 7 days from imported calendar
- One-click "Start recording for this meeting" from calendar entry
- No OAuth required — file-based ICS import only

---

## Database Schema

```sql
CREATE TABLE meetings (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT NOT NULL,
    recorded_at     DATETIME NOT NULL,
    duration_secs   INTEGER,
    audio_path      TEXT,               -- absolute path to WAV file
    whisper_model   TEXT,               -- 'tiny' | 'base' | 'small' | 'medium'
    language        TEXT DEFAULT 'en',
    status          TEXT DEFAULT 'pending', -- 'pending'|'transcribing'|'done'|'error'
    notes           TEXT                -- freeform pre-meeting notes
);

CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    speaker     TEXT,                   -- 'Speaker 1', renamed by user
    start_secs  REAL NOT NULL,
    end_secs    REAL NOT NULL,
    text        TEXT NOT NULL
);

CREATE TABLE action_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    owner       TEXT,
    due_date    DATE,
    completed   BOOLEAN DEFAULT 0,
    created_at  DATETIME NOT NULL
);

CREATE TABLE participants (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    email       TEXT,
    speaker_label TEXT              -- maps to transcript.speaker
);

-- FTS5 virtual table for transcript search
CREATE VIRTUAL TABLE transcripts_fts USING fts5(
    text, meeting_id UNINDEXED,
    content='transcripts', content_rowid='id'
);
```

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  Menu Bar: File | Edit | View | Export | Help                        │
├───────────────────┬─────────────────────────────────────────────────┤
│  LEFT PANEL       │  RIGHT PANEL                                     │
│  ┌─────────────┐  │  ┌──────────────────┬────────────────────────┐  │
│  │ Recording   │  │  │  TRANSCRIPT PANE │  SUMMARY PANE          │  │
│  │ Controls    │  │  │                  │                         │  │
│  │ [●REC][■]   │  │  │  [Speaker 1]     │  ## Meeting Summary    │  │
│  │ [▶Import]   │  │  │  0:00 text...    │  **Purpose:** ...      │  │
│  │             │  │  │  [Speaker 2]     │  **Decisions:**        │  │
│  │ VU Meter ▓▓ │  │  │  0:43 text...    │  - Decision 1         │  │
│  ├─────────────┤  │  │                  │                         │  │
│  │ Meeting     │  │  │  Timeline ━━━━━━━│  **Action Items:**     │  │
│  │ List        │  │  │  ▲ scrubber      │  [ ] Task — @owner    │  │
│  │ > Meeting 1 │  │  └──────────────────┴────────────────────────┘  │
│  │   Meeting 2 │  │  Status bar: Transcribing... 67%               │  │
│  │   Meeting 3 │  └─────────────────────────────────────────────────┤
│  ├─────────────┤                                                      │
│  │ Search...   │                                                      │
│  └─────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Interactions

### Flow 1: Record and Summarize a New Meeting
1. User clicks Record button; audio capture starts, VU meter animates
2. User clicks Stop; WAV file saved to `~/MeetingMind/recordings/`
3. Transcription QThread starts (Whisper model selected in settings)
4. Transcript segments appear in real-time in transcript pane as Whisper processes
5. On completion, Claude is called with full transcript; summary appears in right pane
6. Action items automatically populated in a checklist below summary

### Flow 2: Import and Process an Existing Recording
1. User drags an MP4 file onto the app window
2. Dialog prompts for meeting title and participant names
3. ffmpeg extracts audio to temp WAV; existing recording bypassed
4. Same transcription + summarization pipeline runs as Flow 1

### Flow 3: Search and Export Past Meetings
1. User types keyword in sidebar search box (e.g., "deployment deadline")
2. FTS5 returns ranked results; clicking one opens that meeting
3. User selects Export > DOCX; file-save dialog appears
4. DOCX generated with python-docx; action items appear as checkbox list

---

## Implementation Steps

1. **Project scaffold** — `src/meetingmind/`, PyQt6 MainWindow skeleton, SQLAlchemy setup
2. **Audio recording module** — PyAudio stream, WAV writer, VU meter widget (QThread)
3. **File import pipeline** — ffmpeg-python wrapper, drag-and-drop event handler
4. **Whisper transcription worker** — QThread subclass, progress signals, segment callback
5. **Claude summarization** — prompt template, structured output parser, action item extractor
6. **UI layout** — split QSplitter layout, transcript list widget, summary QTextBrowser
7. **Search & calendar** — FTS5 indexing on transcript save, ICS parser (icalendar library)
8. **Export modules** — DOCX (python-docx), PDF (fpdf2), Markdown formatter

---

## Success Criteria

### Functional
- Transcription accuracy ≥ 85% WER for clear English speech with Whisper base model
- Claude summary always includes at least one section for decisions and action items
- FTS5 search returns results within 200ms for a database of 500 meetings

### UX
- UI never freezes during transcription (all heavy work in QThreads)
- Recording start latency under 300ms from button click to audio capture
- Export to DOCX preserves action item checkboxes as actual Word checkboxes

### Technical Quality
- Audio files stored with relative DB paths (portable across machines)
- Whisper model cached in `~/.cache/meetingmind/` after first download
- All transcript text written to FTS5 index atomically with transcript row insert
- Unit tests cover Whisper segment parser and Claude response parser
