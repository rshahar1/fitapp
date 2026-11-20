# UI Contract: Sharing

| Where | Control | Result |
|---|---|---|
| Activity detail app bar (all types) | `Icons.ios_share` IconButton, tooltip "Share activity" | push `/share/activity/:id` |
| Finished workout app bar (read-only, not editing) | `Icons.ios_share`, tooltip "Share workout" | push `/share/workout/:id` |
| Finish summary sheet | secondary button "Share workout" | go Train, then push `/share/workout/:id` |
| Share preview `/share/{workout,activity}/:id` | card preview + primary button "Share image" | OS share sheet with one PNG `fitapp-<type>-<yyyy-mm-dd>.png` and caption text |

- Missing or in-progress session on the preview route: empty state "Nothing to share".
- Share failure: SnackBar "Could not share the image."
