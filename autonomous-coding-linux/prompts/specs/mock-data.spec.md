# Mock Data File Specification

## Overview

Generate JSON data files that simulate real-world HookHub API responses.
Each file represents a different data scenario or endpoint response.

## File Conventions

- Filename: `<scenario>.mock.json`
- Location: `src/data/mocks/`
- Pure JSON (no TypeScript)
- Must be valid, parseable JSON
- All dates in ISO 8601 format
- All IDs as kebab-case strings

## Data Types Available

### Hook Entry
```json
{
  "id": "kebab-case-id",
  "name": "Display Name",
  "category": "UTILITY|SECURITY|WORKFLOW|MONITORING|TESTING|LEARNING|INTEGRATION|TEAM",
  "description": "1-2 sentence description",
  "githubUrl": "https://github.com/author/repo",
  "author": "github-username",
  "stars": 1234,
  "language": "Python|TypeScript|Go|JavaScript|PHP|Rust",
  "hookTypes": ["PRE_TOOL_USE", "POST_TOOL_USE", "STOP", "NOTIFICATION", "SUBAGENT_START", "SUBAGENT_STOP"],
  "featured": true,
  "downloads": 5678,
  "lastUpdated": "2025-05-01T00:00:00Z",
  "tags": ["security", "automation"],
  "version": "1.2.0",
  "license": "MIT"
}
```

### User Profile
```json
{
  "id": "user-id",
  "username": "github-handle",
  "displayName": "Full Name",
  "avatarUrl": "https://avatars.githubusercontent.com/...",
  "bio": "short bio",
  "hooksPublished": 5,
  "totalStars": 1200,
  "joinedAt": "2024-01-01T00:00:00Z"
}
```

### API Response Wrapper
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 1,
    "perPage": 20,
    "totalPages": 5
  },
  "success": true,
  "timestamp": "2025-05-26T00:00:00Z"
}
```

## Variation Guidelines

Each mock file should represent a different scenario:
- Different categories / filter states
- Different pagination pages
- Different sort orders (by stars, by recent, by downloads)
- Edge cases: empty results, single result, max results
- Minimum 10 hook entries per file, maximum 25
- All data must be realistic and HookHub-relevant (not lorem ipsum)
- Stars range: 10–20000, downloads range: 50–100000
