# API

The archive API for patch apps, such as Krater. JSON over HTTPS. Every request carries a Weave `client_credentials` token with the scope `stash`:

```
Authorization: Bearer <token>
```

Stash checks the token with Weave's introspection endpoint. The answers:

| Status | Body | Meaning |
|---|---|---|
| 401 | `{"error":"invalid_token"}` | no token, or Weave says it is not active |
| 403 | `{"error":"insufficient_scope"}` | the token has no `stash` scope |
| 503 | `{"error":"weave_unavailable"}` | Weave did not answer. Retry |
| 429 | `{"error":"rate_limited"}` | more than 120 requests a minute with one token. Wait `Retry-After` seconds |

## Archive a URL

```
POST /api/v1/archives
Content-Type: application/json

{
  "url": "https://github.com/someone/project",
  "note": "Ganymede submission by PWL5A1B2C3D4",
  "reference": { "patch": "ganymede", "submission": "<the patch app's own submission id>" }
}
```

- `url` is required: an `http` or `https` URL, at most 2048 characters.
- `note` is optional, at most 2000 characters. It shows on the archive page.
- `reference` is optional, a flat JSON object of strings. Stash stores it as given and shows it on the page. `reference.submission` makes the call idempotent: a second `POST` from the same app with the same `submission` and the same URL (after normalization) returns the first archive with `200`.

Answers:

| Status | Meaning |
|---|---|
| 201 | a new archive. The body is the archive (below), with `status` `queued` and no captures yet |
| 200 | the archive already existed for this `submission` and URL |
| 422 | `{"error":"invalid","details":[...]}`: the URL is not `http(s)`, or a field is too long |
| 413 | the body is larger than 16 KB |

## One archive

```
GET /api/v1/archives/arc_4k8xJm2pN9qW
```

```json
{
  "id": "arc_4k8xJm2pN9qW",
  "status": "done",
  "url": "https://github.com/someone/project",
  "normalized_url": "https://github.com/someone/project",
  "host": "github.com",
  "kind": "repo",
  "reference": { "patch": "ganymede", "submission": "krater-submission-123" },
  "note": "Ganymede submission by PWL5A1B2C3D4",
  "created_at": "2026-11-08T05:00:00Z",
  "completed_at": "2026-11-08T05:01:12Z",
  "page_url": "https://stash.patchworklabs.org/archives/arc_4k8xJm2pN9qW",
  "captures": [
    {
      "id": "cap_...", "method": "github", "status": "done", "error": null,
      "started_at": "...", "finished_at": "...",
      "artifacts": [
        { "id": "art_...", "role": "metadata", "filename": "github.json", "content_type": "application/json",
          "byte_size": 48213, "sha256": "...", "download_url": "https://stash.patchworklabs.org/artifacts/art_..." }
      ]
    },
    { "id": "cap_...", "method": "git", "status": "done", "error": null, "artifacts": [ "..." ] },
    { "id": "cap_...", "method": "page", "status": "failed", "error": "ToolFailed: Chromium: ...", "artifacts": [] }
  ]
}
```

`status` is one of `queued`, `running`, `done`, `partial` (some captures failed), `failed`. Poll until `completed_at` is set. A capture's `status` is `queued`, `running`, `done`, `failed` or `skipped`.

`download_url` needs a signed-in person: it is a Stash page URL that redirects to a short-lived storage URL. An app that needs the bytes should ask for that later; today the API gives the checksums and the sizes. Page URLs hold the id without its prefix (`/archives/4k8xJm2pN9qW`); the API accepts both forms.

An unknown id answers `404 {"error":"not_found"}`.

## The archives of a URL

```
GET /api/v1/archives?url=https://github.com/someone/project
```

```json
{ "archives": [ { "...the archive shape above..." } ] }
```

Newest first, at most 50. The URL is normalized before the lookup, so `?utm_source=` and a trailing slash do not matter.

## Capture methods

| Method | What it keeps |
|---|---|
| `page` | the rendered page as MHTML, a full-page PNG, a print PDF |
| `github` | the repository record, README, releases, last 100 commits and contributors, from the GitHub API |
| `git` | a mirror clone as a git bundle, and the list of refs |
| `document` | the document as served (`.pptx`, `.docx`, `.pdf`, a Google export) and a PDF rendition |
| `video` | the media file, yt-dlp's info JSON and the poster |
| `gallery` | a ZIP of a post's photos and sidecars, and a normalized post record |
| `file` | any other file as served |

The design doc (`design.md`) has the routing rules.
