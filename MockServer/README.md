# Engineering Notebook — Mock REST Server

A tiny, dependency-free Node server that implements the backend contract the app's
`RESTBackendService` expects. Use it to exercise the real networking path locally.

## Run it

```bash
node MockServer/server.js
# Engineering Notebook mock API listening on http://localhost:3000
```

No `npm install` needed — it only uses Node's built-in `http` module.

## Point the app at it

In `Engineering Notebook/BackendService.swift`, set:

```swift
static let backendBaseURL: URL? = URL(string: "http://localhost:3000")
```

While this is `nil` (the default), the app uses the on-device `MockBackendService`
instead, so it runs fully offline with no server required.

> Running on the iOS Simulator can reach `localhost` directly. On a physical
> device, replace `localhost` with your Mac's LAN IP and ensure both are on the
> same network. Because the URL is `http`, add an App Transport Security exception
> if you target a real device.

## API contract

All bodies are JSON. Dates are ISO-8601 strings. Photos are base64-encoded JPEG
strings in the `photoData` field.

| Method | Path | Body | Returns |
| --- | --- | --- | --- |
| `GET` | `/projects` | — | `[Project]` |
| `POST` | `/projects` | `Project` | created `Project` |
| `DELETE` | `/projects/{id}` | — | `204` |
| `GET` | `/projects/{id}/entries` | — | `[Entry]` |
| `POST` | `/projects/{id}/entries` | `Entry` | created `Entry` |
| `DELETE` | `/entries/{id}` | — | `204` |

### Project

```json
{
  "id": "UUID",
  "name": "Bridge Inspection",
  "summary": "Q3 structural survey",
  "createdAt": "2026-09-11T18:00:00Z"
}
```

### Entry

```json
{
  "id": "UUID",
  "projectID": "UUID",
  "note": "Hairline crack on north abutment",
  "location": { "latitude": 37.33, "longitude": -122.03, "placeName": "Cupertino" },
  "photoData": "<base64 JPEG or null>",
  "temperature": 21.5,
  "temperatureUnit": "°C",
  "measurement": 3.2,
  "measurementUnit": "mm",
  "rating": 4,
  "createdAt": "2026-09-11T18:05:00Z"
}
```

Every field on `Entry` other than `id`, `projectID`, `note`, `temperatureUnit`,
and `createdAt` is optional/nullable.

Data is in-memory only and resets when the server restarts.
