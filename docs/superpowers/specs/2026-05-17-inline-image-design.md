# Inline Image Insertion — Design Spec

**Date:** 2026-05-17  
**Status:** Approved

---

## Overview

Allow users to insert image attachments inline into note content. Images render full-width in the WYSIWYG editor with an optional editable caption. The insert trigger is an image button in the format toolbar that opens a picker/uploader dialog.

---

## Decisions

| Decision | Choice |
|---|---|
| Insert trigger | Format toolbar image button (not attachment chip) |
| Image display | Full width, optional editable caption below |
| Picker behaviour | Lists existing image attachments + "Upload image" button |
| Storage approach | `attachment://attachmentId` in markdown, resolved to presigned URLs on note load |

---

## Storage Format

Images are stored in DynamoDB as standard markdown image syntax with a custom URI scheme:

```
![caption text](attachment://attachmentId)
```

Presigned S3 URLs are **never persisted**. Only the stable `attachmentId` is written to markdown. This means the stored content remains valid indefinitely regardless of URL expiry.

---

## Architecture

### Load path

1. `_loadNote()` in `EditorScreen` fetches note markdown from the API.
2. Calls `ContentPipeline.fromMarkdown(content, noteId: noteId, api: api)` — now `async`.
3. Pipeline parses markdown for `attachment://` image refs, extracts all attachment IDs.
4. Fetches presigned download URLs in parallel (`Future.wait`) via `GET /notes/{noteId}/attachments/{attachmentId}`.
5. Passes original markdown to `MarkdownToDelta`, then post-processes the delta to convert image embeds with `attachment://` URLs into `ln-image` custom embeds:
   ```json
   {"insert": {"ln-image": {"attachmentId": "abc-123", "url": "https://s3/...", "caption": "Sunrise over Hallgrímskirkja"}}}
   ```
6. `LnImageEmbed` renders each image directly from the resolved `url` — no additional API calls at render time.

### Save path

1. Auto-save debounce fires → `ContentPipeline.toMarkdown()` runs (synchronous, no signature change).
2. `toMarkdown()` detects `ln-image` embeds and serialises them as `![caption](attachment://attachmentId)`.
3. The `url` field is dropped — only `attachmentId` and `caption` are written.
4. Markdown saved to DynamoDB.

### Insert path

1. User clicks the image icon (🖼) in the format toolbar.
2. `ImagePickerDialog` opens (AlertDialog on desktop, bottom sheet on mobile).
3. Dialog lists the note's image attachments (MIME type `image/*`) as thumbnail tiles.
4. If no images exist, shows: *"No images yet"* with the Upload button prominent.
5. User either selects an existing image or uploads a new one via the existing `attachmentProvider.uploadAttachment()` flow.
6. On selection: fetch presigned URL for the chosen attachment → insert `ln-image` embed at the current cursor position.
7. Auto-save fires → markdown written to DynamoDB.

---

## Components

### `LnImageEmbed` — new
**Path:** `lib/features/notes/widgets/ln_image_embed.dart`

Custom `QuillEmbedBuilder` for the `ln-image` embed type.

- Renders a full-width image from `embed.data['url']`.
- Shows a loading spinner while the image fetches.
- Shows a broken-image placeholder with label *"Attachment not found"* on error.
- Renders an editable `TextField` below the image for the caption (placeholder: *"Add a caption…"*). In read-only mode the caption field is hidden.
- Caption changes update the embed node in the Quill document via `controller.replaceText(index, 1, updatedEmbedData, null)`, which triggers the normal auto-save debounce.

### `ImagePickerDialog` — new
**Path:** `lib/features/notes/widgets/image_picker_dialog.dart`

Modal for selecting or uploading an image to insert.

- **Input:** `noteId`
- **Output:** `Future<AttachmentItem?>` (null if dismissed)
- Filters `attachmentProvider(noteId)` to items with `mimeType.startsWith('image/')`.
- Upload button delegates to `attachmentProvider.uploadAttachment()` — same flow as `AttachmentBar`.
- After upload completes, the new image is immediately selectable in the list.
- Desktop: `AlertDialog` with a grid of thumbnail tiles.
- Mobile: `showModalBottomSheet` with a vertically scrolling list.

### `FormatToolbar` — modified
**Path:** `lib/features/notes/widgets/format_toolbar.dart`

- New required parameter: `String noteId`.
- Adds an `Icons.image_outlined` button after the existing format buttons.
- On tap: opens `ImagePickerDialog`, awaits result, fetches presigned URL, inserts `ln-image` embed at cursor.
- Button is only active when the editor has focus (same guard as existing buttons).

### `ContentPipeline` — modified
**Path:** `lib/features/notes/services/content_pipeline.dart`

- `fromMarkdown` signature changes to:
  ```dart
  static Future<Document> fromMarkdown(
    String markdown, {
    String? noteId,
    ApiClient? api,
  })
  ```
- Parses markdown for `![...](attachment://id)` patterns using a regex to extract all attachment IDs.
- Fetches presigned URLs in parallel for all found IDs, building a lookup map `{attachmentId → presignedUrl}`.
- Passes the **original** markdown (with `attachment://` URIs intact) to `MarkdownToDelta` — this produces standard image embeds with `attachment://id` as the URL.
- Post-processes the resulting delta: any image embed whose URL starts with `attachment://` is replaced by an `ln-image` embed `{attachmentId, url: <resolved>, caption: <alt text>}`.
- If `api` is null or `noteId` is null (e.g., in tests), `attachment://` embeds are left as-is and render as broken images without crashing.
- `toMarkdown()` remains synchronous. Pre-processes the delta to convert `ln-image` embeds into standard image operations (URL = `attachment://attachmentId`, alt = caption) before passing to `DeltaToMarkdown`, ensuring the serialisation works with the existing package.

### `EditorScreen` — modified
**Path:** `lib/features/notes/screens/editor_screen.dart`

- `_loadNote()` becomes `async`-awaiting `ContentPipeline.fromMarkdown()`.
- Passes `noteId` to `FormatToolbar`.
- Registers `LnImageEmbed()` in `QuillEditorConfig.embedBuilders`.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| Note has no inline images | `fromMarkdown` finds no `attachment://` refs → zero extra API calls, no load latency added |
| Presigned URL expires mid-session (after 60 min) | Image renders broken until next note reload; acceptable for v1 |
| Referenced attachment has been deleted | Presigned URL fetch returns 404 → placeholder shown: *"Attachment not found"* |
| Upload from picker fails | Existing `attachmentProvider` failed-chip state surfaces the error; picker stays open for retry |
| Note exported / opened in another client | `attachment://` is a valid (non-resolving) markdown URI; other clients see a broken image — no data loss |
| `DeltaToMarkdown` doesn't know `ln-image` | `toMarkdown()` pre-processes the delta to swap `ln-image` embeds for standard image ops before serialising |

---

## Out of Scope (v1)

- Image resizing or float alignment (left/right)
- Auto-refresh of presigned URLs mid-session
- Drag-and-drop from attachment bar into editor body
- Paste image from clipboard directly into editor
