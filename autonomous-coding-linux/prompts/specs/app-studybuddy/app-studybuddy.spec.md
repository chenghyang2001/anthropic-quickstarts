# App Specification: StudyBuddy — AI Spaced Repetition Learning App

## Project Overview

StudyBuddy is a desktop flashcard application that combines the SM-2 spaced repetition algorithm
with Claude AI to transform raw notes into structured learning material. Users import Markdown,
PDF, or plain text files and Claude automatically generates high-quality Q&A flashcard pairs.
During study sessions, when a user answers incorrectly, Claude provides contextual explanations
with examples to reinforce understanding. The application tracks long-term retention metrics and
exports decks in Anki-compatible format.

---

## Technology Stack

| Layer         | Technology                                   |
|---------------|----------------------------------------------|
| Language      | Python 3.11+                                 |
| GUI Framework | PyQt6                                        |
| Database      | SQLite (via SQLAlchemy 2.x ORM)              |
| AI            | Anthropic Claude API (`claude-sonnet-4-6`)   |
| PDF Parsing   | pdfplumber                                   |
| Markdown      | python-markdown2                             |
| Export        | genanki (Anki .apkg export)                  |
| Charts        | matplotlib (embedded in PyQt6 widget)        |
| Dependencies  | anthropic, sqlalchemy, pdfplumber, genanki,  |
|               | markdown2, matplotlib, PyQt6                 |

---

## Core Features

### 1. Note Import & AI Flashcard Generation
- Accept Markdown (.md), PDF, and plain text (.txt) files via drag-and-drop or file dialog
- Strip formatting and send chunked content to Claude for Q&A extraction
- Claude returns structured JSON: `[{"question": "...", "answer": "...", "type": "basic"}]`
- Cloze deletion detection: Claude identifies fill-in-the-blank opportunities automatically
- User can review, edit, or reject generated cards before saving to deck

### 2. SM-2 Spaced Repetition Scheduler
- Implement the SM-2 algorithm: interval, ease factor, repetition count per card
- Quality rating 1-5 after each review; 1-2 resets interval, 3+ advances schedule
- `next_review` date calculated per card and stored in DB
- Due cards queued at session start sorted by overdue days (most overdue first)
- New cards per day configurable (default: 20 new + all due)

### 3. Multiple Card Types
- **Basic Q/A**: front side (question) flips to back side (answer)
- **Cloze deletion**: `{{c1::answer}}` syntax renders blanked text on front
- **Image occlusion (mock)**: placeholder overlay on imported images (future-ready)
- Card type stored in DB; renderer switches layout based on type field
- Bulk card type conversion: select cards and change type with one action

### 4. Daily Study Session
- Full-screen minimalist mode: one card at a time, keyboard shortcuts (Space to flip, 1-5 to rate)
- Session summary on completion: cards reviewed, average rating, time spent
- Streak tracking: consecutive days with at least one review
- "Undo last rating" button for accidental misclicks
- Session progress bar showing cards remaining / total due

### 5. AI "Why Was I Wrong" Explanation
- After rating a card 1 or 2, "Explain My Mistake" button appears
- Sends question + user's attempt context to Claude for explanation
- Claude returns: root cause, corrected explanation, mnemonic tip, real-world example
- Explanation saved to card for future reference (viewable in card editor)
- Rate-limited: max 10 AI explanations per session to manage API cost

### 6. Deck Organization
- Hierarchical deck structure: subjects contain sub-decks (max 3 levels)
- Tags: comma-separated per card, filterable in deck view
- Deck color labels and icons for quick visual identification
- Search: full-text across card fronts and backs
- Bulk operations: move, delete, suspend cards across decks

### 7. Study Statistics
- Retention rate per deck: % cards answered 3+ in last 30 days
- Streak calendar heatmap: GitHub-style activity grid
- Cards learned over time: cumulative line chart
- Average ease factor trend: indicates if deck is getting harder or easier
- Export statistics as CSV

### 8. Anki Export
- Generate .apkg file using `genanki` library
- Map StudyBuddy card types to Anki note types (Basic, Cloze)
- Include scheduling data: interval, ease factor, due date
- Deck hierarchy preserved in Anki deck names (Parent::Child format)
- Export single deck or all decks

---

## Database Schema

```sql
CREATE TABLE decks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    parent_id   INTEGER REFERENCES decks(id),
    color       TEXT DEFAULT '#4A90E2',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

CREATE TABLE cards (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    deck_id         INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    card_type       TEXT NOT NULL DEFAULT 'basic',  -- basic | cloze | image
    tags            TEXT DEFAULT '',
    interval        INTEGER DEFAULT 1,
    ease_factor     REAL DEFAULT 2.5,
    repetitions     INTEGER DEFAULT 0,
    next_review     DATE DEFAULT (date('now')),
    ai_explanation  TEXT,
    suspended       BOOLEAN DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE study_sessions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    ended_at        DATETIME,
    cards_reviewed  INTEGER DEFAULT 0,
    avg_rating      REAL,
    deck_id         INTEGER REFERENCES decks(id)
);

CREATE TABLE card_reviews (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    card_id     INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    session_id  INTEGER REFERENCES study_sessions(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    reviewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    time_spent  INTEGER  -- seconds
);
```

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  StudyBuddy                                    [_ □ ×]      │
├──────────────┬──────────────────────────────────────────────┤
│  DECK SIDEBAR│  MAIN CONTENT AREA                           │
│              │                                              │
│  ▼ My Decks  │  [Study Now]  [Import Notes]  [Stats]        │
│    ▶ Physics │  ─────────────────────────────────────────   │
│    ▶ History │                                              │
│    ▼ Python  │   Due Today: 24 cards   New: 12 cards        │
│      Basics  │                                              │
│      OOP     │   ┌──────────────────────────────────┐       │
│              │   │         CARD FRONT               │       │
│  [+ New Deck]│   │                                  │       │
│              │   │  What is list comprehension?     │       │
│  ─────────── │   │                                  │       │
│  Tags:       │   └──────────────────────────────────┘       │
│  #python     │        [Space / Click to Flip]               │
│  #basics     │                                              │
│  #oop        │   ┌──────────────────────────────────┐       │
│              │   │         CARD BACK (flipped)      │       │
│              │   │  [answer text here]              │       │
│              │   │                                  │       │
│              │   │  [1 Again][2 Hard][3 Good]       │       │
│              │   │  [4 Easy ][5 Perfect]            │       │
│              │   └──────────────────────────────────┘       │
│              │   [Why was I wrong?]  (appears after 1-2)    │
└──────────────┴──────────────────────────────────────────────┘

STUDY MODE (Full Screen):
┌─────────────────────────────────────────────────────────────┐
│  [X Exit]                          Progress: ████░░░ 14/20  │
│                                                             │
│                                                             │
│          What is the time complexity of binary search?      │
│                                                             │
│                    ─────────────────                        │
│                    [SPACE to reveal]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Interactions

### Interaction 1: Import Notes → Generate Flashcards
```
User selects .md file
  → FileImportDialog opens
  → pdfplumber/markdown2 extracts plain text
  → Text split into 500-token chunks
  → Each chunk sent to Claude:
      Prompt: "Generate flashcard Q&A pairs from this text.
               Return JSON array: [{question, answer, type}]"
  → Claude returns JSON
  → CardPreviewDialog shows generated cards in editable table
  → User edits/deletes rows
  → User clicks "Save to Deck [Physics]"
  → Cards written to DB with next_review = today
```

### Interaction 2: Daily Study Session Flow
```
User clicks "Study Now" on deck
  → DB query: SELECT cards WHERE next_review <= today AND suspended=0
  → SM-2 scheduler sorts: overdue first, then by ease_factor ASC
  → StudyWindow opens (full screen)
  → Card front displayed
  → User presses Space → card flips (CSS-like transform)
  → User presses 1-5
  → SM-2 calculates new interval + ease_factor
  → DB updated: card.interval, card.ease_factor, card.next_review
  → card_reviews row inserted
  → If rating <= 2 → "Explain My Mistake" button visible
  → Next card shown
  → On last card → SessionSummaryDialog shown
```

### Interaction 3: AI Explanation Request
```
User clicks "Why Was I Wrong?"
  → Claude API called:
      Prompt: "Question: {front}\nCorrect Answer: {back}\n
               Explain why a student might get this wrong and
               give a helpful explanation with a real-world example."
  → Claude returns explanation text
  → ExplanationPanel slides in below card
  → Explanation stored in cards.ai_explanation
  → API call count for session incremented (max 10 enforced)
```

---

## Implementation Steps

1. **Project scaffold**: Create PyQt6 app skeleton, configure SQLAlchemy with SQLite,
   define all ORM models, run `Base.metadata.create_all()` on first launch.

2. **Deck Manager UI**: Build sidebar with QTreeWidget for hierarchical decks,
   context menu for add/rename/delete, color picker dialog.

3. **SM-2 algorithm module**: Implement `sm2.py` — pure function `calculate_next_review(card, rating)`
   returning updated interval, ease_factor, repetitions, next_review date.

4. **File import pipeline**: FileImportDialog + text extractors for .md, .pdf, .txt,
   chunking logic (500 tokens), Claude API call with retry on rate limit.

5. **Card CRUD UI**: CardListWidget (QTableWidget) with inline edit, bulk select,
   CardEditorDialog for single card detail/tag editing.

6. **Study session UI**: StudyWindow (full-screen QWidget), card flip animation via
   QPropertyAnimation on card widget geometry/opacity, rating buttons 1-5.

7. **AI explanation integration**: Claude API call on demand in study session,
   ExplanationPanel QWidget with text display, session-level call counter.

8. **Statistics dashboard**: StatsWidget with matplotlib FigureCanvas embedded,
   retention rate calculation, streak calendar, export CSV action.

---

## Success Criteria

### Functional
- Import a 10-page PDF and generate 20+ flashcards within 30 seconds
- SM-2 scheduling correctly advances intervals: day 1 → 3 → 8 → 21 for 5-rated cards
- Study session completes 50 cards with no UI freezes or data loss
- AI explanation appears within 5 seconds of clicking button
- Anki .apkg exports and imports successfully in Anki desktop app

### UX
- Card flip animation smooth at 60 fps on integrated GPU
- Full-screen study mode has zero distracting UI elements
- Keyboard-only workflow: Space flip + 1-5 rate + Enter next card
- Deck sidebar loads 1000+ cards without perceptible lag

### Technical Quality
- All DB writes wrapped in transactions; no partial saves on crash
- Claude API calls use `httpx` async with timeout 30s and 3 retries
- SM-2 unit tests cover all rating values (1-5) and edge cases (new card, lapsed card)
- SQLAlchemy models have `__repr__` and input validation on required fields
- No hardcoded API keys; key read from `ANTHROPIC_API_KEY` environment variable
