# Appwrite Delete Functions

This project provides two Dart Appwrite Function entrypoints for deleting documents:

- `main.dart` (`delete_all_collections`): deletes all documents from every collection in a database.
- `main_selected.dart` (`delete_selected_collections`): deletes all documents from the provided `collectionIds` request payload.

## Required environment variables

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_API_KEY`
- `APPWRITE_DATABASE_ID`

Optional:

- `LOG_LEVEL` (`DEBUG`, `INFO`, `WARN`, `ERROR`) - defaults to `INFO`

## Request payload (selected mode)

```json
{
  "collectionIds": ["collectionA", "collectionB"]
}
```

## Behavior

- Logs are structured and emitted to stdout (project runtime) and Appwrite function logs.
- Responses include totals and per-collection results.
- Missing required env vars fail fast with a structured error response.