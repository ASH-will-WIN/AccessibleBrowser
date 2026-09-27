# Deterministic accessibility action specification

The local fixture at `demo/accessible-demo.html` is intentionally small and awkward. Start it with `npm run demo`, then open `http://127.0.0.1:4173/` in the active Electron page. These specifications use the canonical action `type` names from `CONTRACTS.md`.

Every action is reversible. Electron captures the inserted CSS keys or focus state before mutation, applies only to the current `pageRevision`, returns one undo token for the transaction, and invalidates that token after navigation or another page revision. A missing or stale target rejects the whole transaction and must not claim a partial success. Jac explains the proposed change and the UI previews it before approval. Preference saving is separate from apply and requires explicit approval.

| Action type | Parameters | Expected visual result | Scope behavior |
| --- | --- | --- | --- |
| `set_text_scale` | `{ "scale": number }`, 1.0–2.5 | Text and controls become proportionally easier to read. | Page by default; website/global only after explicit approval. |
| `set_spacing` | `{ "lineHeight"?: number, "letterSpacing"?: number }`; line height 1.0–2.5, letter spacing 0–0.2 | Paragraphs and letters have more breathing room. | Same page/website/global precedence rules. |
| `set_contrast` | `{ "level": "high" \| "soft" }` | Foreground/background contrast becomes stronger or softer through a bounded CSS rule. | Never saves automatically. |
| `set_color_filter` | `{ "filter": "grayscale" \| "warm" \| "cool" \| "invert" }` | Page colors change using the selected bounded filter. | Explicit preference approval required. |
| `reduce_motion` | `{ "enabled": boolean }` | The moving `.notice` stops animating when enabled. | Page revision is checked before apply. |
| `enlarge_targets` | `{ "enabled": boolean }` | Buttons, links, and form controls receive larger hit areas. | Page revision is checked before apply. |
| `focus_elements` | `{}` plus non-empty `targetElementIds` | Selected controls receive a visible focus treatment; prior focus/style is captured. | Missing IDs reject safely; no best-effort mutation. |
| `reading_mode` | `{ "enabled": boolean }` | The article is emphasized and the distracting sidebar/popup is hidden or restored. | Page scope unless the user explicitly approves another scope. |

For every action, the plan must include an explanation, a reversible flag, the request/plan `pageRevision`, and the exact target IDs when targeting elements. Plans are rejected for unknown action types, extra parameters, arbitrary JavaScript/CSS, stale revisions, invalid ranges, or unsafe target IDs. The browser applies no action silently: preview, user approval, apply, undo, and preference save are distinct states.

## Deterministic fallback and unavailable provider

When no API key is present, Jac's deterministic planner can produce a bounded plan for the supported requests. If the online provider is unavailable or returns malformed data, the UI shows an actionable unavailable/rejected state and keeps deterministic controls available; it never presents a fabricated model plan. The renderer does not receive the API key.
