# AccessibleBrowser Decisions

## D001 — Use Electron as the Chromium host

The product is a true Chromium wrapper. Electron provides the reliable desktop window, embedded Chromium page, navigation, and browser integration needed for that goal. Jac remains the main product layer rather than being forced to implement browser-host behavior it does not clearly provide.

## D002 — Keep Jac central

Jac owns profiles, preference memory, request interpretation, adaptation planning, explanations, and most first-party product logic. Electron/Node stays limited to browser-specific operations. This makes the Jac requirement meaningful instead of cosmetic.

## D003 — Use an online OpenAI model

The product intentionally uses an online OpenAI API model for page-specific adaptation planning. API credentials are supplied through environment variables and never committed. Local preference storage does not imply that page snapshots sent to the model are local.

## D004 — Plans use an allowlist

The model returns structured, explainable actions. It does not return arbitrary JavaScript or CSS. Electron validates and applies only known action kinds so changes can be reviewed and undone.

## D005 — Store preferences locally first

The prototype is single-user and local-first. It stores approved profile settings and preference rules, not raw page contents by default. Persistence scope is explicit: page, website, or global.

## D006 — Phase 0 is foundation only

Phase 0 creates documentation, contracts, toolchain setup, collaboration rules, and a minimal bridge smoke path. The final demo page, full voice mode, complete accessibility transformations, and Simple Mode are deferred to Phase 1.

## D007 — Address-bar navigation uses the constrained browser command

Typed address-bar navigation uses the `navigate` BrowserCommand with a bounded URL argument. Electron accepts only HTTP and HTTPS destinations and rejects embedded credentials and other protocols.

## Deferred decisions

- Exact demonstration page
- Exact speech-to-text and text-to-speech implementation
- Final accessibility presets
- Advanced page restructuring behavior
- Final visual design
- Production privacy and security hardening
