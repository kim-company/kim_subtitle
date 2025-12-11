# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

kim_subtitle is an Elixir library for parsing and manipulating WebVTT and SRT subtitle formats. It provides a generic `Subtitle.Cue` struct used across both formats, with rich support for WebVTT tags, timing manipulation, cue formatting, and text processing.

## Development Commands

### Running Tests
```bash
# Run all tests
mix test

# Run a specific test file
mix test test/subtitle/web_vtt_test.exs

# Run a specific test (by line number)
mix test test/subtitle/web_vtt_test.exs:43
```

### Documentation
```bash
# Generate documentation
mix docs

# View documentation locally (generates docs first)
mix docs && open doc/index.html
```

### Dependencies
```bash
# Install/update dependencies
mix deps.get

# Compile project
mix compile
```

## Architecture

### Core Data Model

The library centers around the `Subtitle.Cue` struct (lib/subtitle/cue.ex), which represents a single subtitle entry:
- `from`: start time in milliseconds
- `to`: end time in milliseconds
- `text`: subtitle text (may contain WebVTT tags)
- `id`: optional cue identifier

This struct is format-agnostic and used by both WebVTT and SRT parsers.

### Format Parsers

**WebVTT Parser** (`Subtitle.WebVTT`): Handles the more complex WebVTT format including:
- Header parsing with X-TIMESTAMP-MAP support for HLS streaming
- Notes and style blocks
- Tag-aware text payloads (bold, italics, voice, class annotations)

**SRT Parser** (`Subtitle.SRT`): Handles the simpler SRT format with partial error recovery.

### Text Processing Pipeline

WebVTT text contains inline formatting tags (`<b>`, `<i>`, `<v Speaker>`, etc.). The `Subtitle.WebVTT.Payload` module:
1. Tokenizes text into tag/text tokens
2. Parses tokens into `Tag` structs with type, attribute, and text
3. Provides operations: `fragment/2` (split into words), `merge/2` (combine tags), `simplify/1` (merge adjacent same-type tags)
4. Handles entity encoding/decoding (`<`, `>`)

### Cue Manipulation

`Subtitle.Cue` provides extensive cue operations:
- **Splitting**: `split/2` breaks long cues into shorter ones based on max_length
- **Merging**: `merge/3` combines cues based on timing gaps, line count, and duration constraints
- **Alignment**: `align/2` removes temporal overlaps by shifting cue boundaries
- **Timing**: `extend/2`, `cut/2`, `duration/1` for duration control
- **Deduplication**: `tidy/1` removes duplicate cues (common in HLS segments)
- **Text extraction**: `to_paragraphs/2` and `to_records/1` convert cues to text with speaker attribution

The timing weight system (see `compute_text_timing_weight/1`) distributes cue duration across text based on character count, with punctuation weighted 9x regular characters.

### Builder Pattern

`Subtitle.Cue.Builder` provides stateful cue formatting:
- Accepts unformatted long cues, outputs properly split/merged/aligned cues
- Maintains state across multiple `put_and_get/3` calls
- Enforces constraints: max_length (character limit per line), max_lines (lines per cue), min_duration (minimum display time)
- Uses pending buffer to avoid committing final cue until more context arrives

## Key Implementation Details

### Timing Offset Handling

WebVTT files may include `X-TIMESTAMP-MAP` headers for HLS streams. The parser automatically:
1. Extracts offset from header (MPEGTS value / 90)
2. Adds offset to all cue timestamps during unmarshal
3. Subtracts offset when marshaling back

### Tag Preservation During Splitting

When splitting cues with WebVTT tags:
1. Text is unmarshaled into Tag structs preserving formatting
2. Tags are fragmented into single words
3. Words are merged back into lines respecting max_length
4. Original tag types (voice, bold, etc.) are preserved in each fragment
5. Timings are redistributed across new cues based on text weight

### Error Recovery in SRT Parser

The SRT parser handles malformed files gracefully:
- Uses regex split for flexible newline handling (handles both CRLF and LF)
- Returns `:partial` results if trailing content is unparseable
- Logs warnings but continues parsing when blocks fail
- Filters empty cues from final results

## Testing Patterns

Tests use pattern matching against expected structs. Common patterns:
- Parse/marshal round-trip tests verify format preservation
- `Subtitle.Helpers.to_ms/3` converts minutes/seconds/ms to milliseconds for test assertions
- Timing tests verify offset calculations are correct
