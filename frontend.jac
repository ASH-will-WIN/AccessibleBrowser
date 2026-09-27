"""Jac-owned accessibility experience for the first Phase 1 flow.

The development adapter below deliberately returns the same JSON-compatible
shapes described in CONTRACTS.md as the future Jac planner and Electron bridge.
It never returns executable DOM code or arbitrary CSS.
"""

obj PreferenceRule {
    has setting: str = "",
        value: str = "",
        scope: str = "page",
        source: str = "manual",
        explicitlyApproved: bool = False,
        createdAt: str = "2026-09-27T00:00:00Z",
        updatedAt: str = "2026-09-27T00:00:00Z";
}

obj AccessibilityProfile {
    has textScale: float = 1.0,
        spacing: str = "standard",
        contrast: str = "standard",
        colorFilter: str = "none",
        reduceMotion: bool = False,
        enlargeTargets: bool = False,
        readingFont: str = "system",
        voiceEnabled: bool = False;

    def summary() -> str {
        reading = "standard text" if self.textScale == 1.0 else "larger text";
        spacing_text = "standard spacing" if self.spacing == "standard" else "more spacing";
        contrast_text = "standard contrast" if self.contrast == "standard" else "high contrast";
        filter_text = "no color filter" if self.colorFilter == "none" else "soft color filter";
        motion_text = "reduced motion" if self.reduceMotion else "normal motion";
        target_text = "larger click targets" if self.enlargeTargets else "standard click targets";
        font_text = "reading font" if self.readingFont == "reading" else "system font";
        return reading + ", " + spacing_text + ", " + contrast_text + ", " + filter_text + ", " + motion_text + ", " + target_text + ", " + font_text;
    }
}

obj PageContext {
    has snapshotId: str = "snapshot_1",
        tabId: str = "tab_1",
        pageRevision: int = 1,
        title: str = "Example article",
        origin: str = "https://example.test";
}

obj AdaptationRequest {
    has schemaVersion: int = 1,
        requestId: str = "dev-request-001",
        tabId: str = "tab_1",
        pageRevision: int = 1,
        userRequest: str = "",
        activeProfile: AccessibilityProfile = AccessibilityProfile(),
        page: PageContext = PageContext(),
        applicableRules: list[PreferenceRule] = [],
        mode: str = "llm";
}

obj PlanAction {
    has actionId: str = "",
        kind: str = "",
        label: str = "",
        reason: str = "",
        target: str = "current page",
        parameters: dict[str, str] = {},
        reversible: bool = True;
}

obj AdaptationPlan {
    has schemaVersion: int = 1,
        planId: str = "",
        requestId: str = "",
        tabId: str = "tab_1",
        pageRevision: int = 1,
        summary: str = "",
        actions: list[PlanAction] = [],
        confidence: str = "medium",
        warnings: list[str] = [],
        suggestedScope: str = "page",
        status: str = "ready";
}

obj AdapterResponse {
    has status: str = "ready",
        plan: AdaptationPlan = AdaptationPlan(),
        errorCode: str = "",
        errorMessage: str = "",
        retryable: bool = False;
}

obj BrowserCommand {
    has schemaVersion: int = 1,
        requestId: str = "dev-command-001",
        tabId: str = "tab_1",
        kind: str = "read_page",
        arguments: dict[str, str] = {},
        requiresConfirmation: bool = False;
}

obj AccessibilityAdapter {
    has mode: str = "development",
        source: str = "typed development fixture";

    def request_plan(request: AdaptationRequest) -> AdapterResponse {
        user_request = request.userRequest;
        actions: list[PlanAction] = [];
        summary = "A small, reversible reading improvement for " + request.page.title + ".";
        lower_request = user_request.lower();

        if "offline" in lower_request or "unavailable" in lower_request {
            return AdapterResponse(status="error", errorCode="LLM_UNAVAILABLE", errorMessage="The online planner is unavailable. Use a deterministic control or retry.", retryable=True);
        }
        if "stale" in lower_request or "refresh" in lower_request {
            return AdapterResponse(status="error", errorCode="STALE_PAGE_REVISION", errorMessage="This page changed while the request was being prepared. Refresh the page and retry.", retryable=True);
        }
        if "unsafe" in lower_request or "javascript" in lower_request or "arbitrary css" in lower_request {
            rejected_plan = AdaptationPlan(
                planId="dev-rejected-plan-001",
                requestId=request.requestId,
                tabId=request.tabId,
                pageRevision=request.pageRevision,
                summary="Request rejected safely.",
                confidence="low",
                warnings=["Only allowlisted, reversible actions are accepted. No arbitrary JavaScript or CSS was generated."],
                suggestedScope="none",
                status="rejected"
            );
            return AdapterResponse(status="rejected", plan=rejected_plan, errorCode="INVALID_PLAN", errorMessage="The request asks for an action outside the allowlist.");
        }

        if "simple" in lower_request or "reading" in lower_request or "read" in lower_request {
            actions = [
                PlanAction(actionId="dev-action-1", kind="reading_mode", label="Reading mode", reason="Emphasize the main article content and reduce distractions.", parameters={"mode": "article"}),
                PlanAction(actionId="dev-action-2", kind="set_text_scale", label="Larger text", reason="Make article text easier to scan.", parameters={"scale": "1.15"}),
                PlanAction(actionId="dev-action-3", kind="set_spacing", label="More spacing", reason="Give lines and paragraphs more breathing room.", parameters={"spacing": "more"})
            ];
            summary = "Make " + request.page.title + " easier to read with a modest reading view.";
        } else {
            actions = [
                PlanAction(actionId="dev-action-1", kind="set_text_scale", label="Larger text", reason="Increase text scale on the current page.", parameters={"scale": "1.15"}),
                PlanAction(actionId="dev-action-2", kind="focus_elements", label="Clearer focus", reason="Make keyboard focus easier to see.", parameters={"style": "high-visibility"})
            ];
        }

        plan = AdaptationPlan(
            planId="dev-plan-001",
            requestId=request.requestId,
            tabId=request.tabId,
            pageRevision=request.pageRevision,
            summary=summary,
            actions=actions,
            confidence="medium",
            warnings=["Development fixture preview. The real Jac planner and Electron validator will replace this adapter."],
            suggestedScope="page",
            status="ready"
        );
        return AdapterResponse(status="ready", plan=plan);
    }

    def apply_plan(plan: AdaptationPlan) -> dict[str, str] {
        if plan.status != "ready" {
            return {"status": "rejected", "code": "INVALID_PLAN", "message": "This plan is not ready to apply."};
        }
        return {
            "status": "completed",
            "undoToken": "dev-undo-001",
            "changed": plan.summary
        };
    }

    def undo_plan(undo_token: str) -> dict[str, str] {
        return {
            "status": "completed",
            "undoToken": undo_token,
            "changed": "The last development adaptation was undone."
        };
    }

    def approve_preference(scope: str, profile: AccessibilityProfile) -> PreferenceRule {
        return PreferenceRule(
            setting="accessibilityProfile",
            value=profile.summary(),
            scope=scope,
            source="manual",
            explicitlyApproved=True,
            createdAt="2026-09-27T00:00:00Z",
            updatedAt="2026-09-27T00:00:00Z"
        );
    }
}

glob adapter: AccessibilityAdapter = AccessibilityAdapter();

def:pub app -> JsxElement {
    has request_text: str = "",
        active_preset: str = "Easier reading",
        profile: AccessibilityProfile = AccessibilityProfile(),
        selected_scope: str = "page",
        request_state: str = "idle",
        request_state_detail: str = "Ready for a request.",
        plan_ready: bool = False,
        reviewed_plan: AdaptationPlan = AdaptationPlan(),
        plan_summary: str = "",
        plan_confidence: str = "",
        plan_warning: str = "",
        plan_actions: list[str] = [],
        plan_action_count: int = 0,
        rejection_message: str = "",
        error_code: str = "",
        can_undo: bool = False,
        undo_token: str = "",
        last_change: str = "No adaptation applied yet.",
        show_preference_prompt: bool = False,
        preference_message: str = "No approved saved rule for this page.",
        saved_scope: str = "",
        simple_mode: bool = False,
        focus_highlight: bool = False,
        voice_state: str = "off",
        voice_command: str = "",
        voice_message: str = "Voice mode is off.",
        voice_command_shape: str = "No command sent yet.",
        bridge_status: str = "Bridge status: development adapter active",
        submit_timer: float = 0.0;

    can with entry {
        saved_rule = localStorage.getItem("accessible-browser-dev-rule");
        if saved_rule {
            saved_parts = saved_rule.split("|");
            loaded_scope = saved_parts[0];
            if loaded_scope.startswith("page:") { loaded_scope = "page"; }
            if loaded_scope.startswith("website:") { loaded_scope = "website"; }
            if loaded_scope.startswith("global:") { loaded_scope = "global"; }
            saved_scope = loaded_scope;
            preference_message = "An approved " + loaded_scope + " rule is being considered for this page.";
        }
    }

    def scope_label() -> str {
        if selected_scope == "website" { return "this website"; }
        if selected_scope == "global" { return "all websites"; }
        return "this page";
    }

    def set_profile_preset(preset: str) {
        active_preset = preset;
        if preset == "Low vision" {
            profile = AccessibilityProfile(textScale=1.25, contrast="high", enlargeTargets=True);
        } elif preset == "Reduced motion" {
            profile = AccessibilityProfile(reduceMotion=True);
        } elif preset == "Easier clicking" {
            profile = AccessibilityProfile(enlargeTargets=True, spacing="more");
        } elif preset == "Custom" {
            active_preset = "Custom";
        } else {
            profile = AccessibilityProfile(textScale=1.15, spacing="more", readingFont="system");
        }
        last_change = "Profile ready: " + active_preset + ".";
    }

    def apply_deterministic_change(change: str) {
        if change == "larger_text" {
            profile.textScale = 1.15 if profile.textScale == 1.0 else 1.0;
        } elif change == "spacing" {
            profile.spacing = "standard" if profile.spacing == "more" else "more";
        } elif change == "contrast" {
            profile.contrast = "standard" if profile.contrast == "high" else "high";
        } elif change == "motion" {
            profile.reduceMotion = not profile.reduceMotion;
        } elif change == "targets" {
            profile.enlargeTargets = not profile.enlargeTargets;
        } elif change == "color_filter" {
            profile.colorFilter = "none" if profile.colorFilter == "soft" else "soft";
        } elif change == "reading_font" {
            profile.readingFont = "system" if profile.readingFont == "reading" else "reading";
        } elif change == "focus" {
            focus_highlight = not focus_highlight;
        }
        active_preset = "Custom";
        request_state = "applied";
        request_state_detail = "Applied to " + scope_label() + ".";
        last_change = "Changed " + change.replace("_", " ") + " for " + scope_label() + ". This deterministic path does not need the online planner.";
        can_undo = True;
        undo_token = "dev-setting-undo";
        show_preference_prompt = True;
    }

    def submit_request() {
        if request_text.strip() == "" {
            request_state = "failed";
            request_state_detail = "Tell me what you want to change first.";
            return;
        }
        request_state = "understanding";
        request_state_detail = "Jac is considering your profile and the current page.";
        plan_ready = False;
        show_preference_prompt = False;
        if submit_timer {
            clearTimeout(submit_timer);
        }
        submit_timer = setTimeout(lambda {
            request = AdaptationRequest(userRequest=request_text, activeProfile=profile, page=PageContext());
            response = adapter.request_plan(request);
            error_code = response.errorCode;
            if response.status == "error" {
                plan_ready = False;
                request_state = "llm unavailable" if response.errorCode == "LLM_UNAVAILABLE" else ("stale" if response.errorCode == "STALE_PAGE_REVISION" else "failed");
                request_state_detail = response.errorMessage;
                rejection_message = "";
            } elif response.status == "rejected" or response.plan.status == "rejected" {
                reviewed_plan = response.plan;
                plan_ready = False;
                rejection_message = response.errorMessage;
                request_state = "rejected";
                request_state_detail = "The request was rejected safely. Nothing changed on the page.";
            } else {
                reviewed_plan = response.plan;
                plan_summary = response.plan.summary;
                plan_confidence = response.plan.confidence;
                plan_warning = response.plan.warnings[0] if len(response.plan.warnings) > 0 else "";
                plan_action_count = len(response.plan.actions);
                plan_actions = [action.label + ": " + action.reason for action in response.plan.actions];
                rejection_message = "";
                plan_ready = True;
                request_state = "preview";
                request_state_detail = "Preview ready. Nothing has changed on the page yet.";
            }
        }, 350);
    }

    def cancel_plan() {
        plan_ready = False;
        request_state = "idle";
        request_state_detail = "Preview cancelled. You can revise the request.";
    }

    def apply_plan() {
        if not plan_ready {
            return;
        }
        request_state = "applying";
        request_state_detail = "Checking the plan and applying it safely...";
        result = adapter.apply_plan(reviewed_plan);
        if result["status"] == "completed" {
            request_state = "applied";
            request_state_detail = "Completed on the current page.";
            last_change = plan_summary;
            can_undo = True;
            undo_token = result["undoToken"];
            show_preference_prompt = True;
            plan_ready = False;
            error_code = "";
        } elif result["code"] == "STALE_PAGE_REVISION" {
            request_state = "stale";
            error_code = result["code"];
            request_state_detail = "The page changed before applying. Refresh the page and retry the request.";
        } elif result["code"] == "LLM_UNAVAILABLE" {
            request_state = "llm unavailable";
            error_code = result["code"];
            request_state_detail = "The online planner is unavailable. Deterministic controls still work.";
        } elif result["status"] == "rejected" {
            request_state = "rejected";
            error_code = result["code"];
            rejection_message = result["message"];
            request_state_detail = "The plan was rejected before any page change.";
        } else {
            request_state = "failed";
            error_code = result["code"];
            request_state_detail = result["message"];
        }
    }

    def undo_last_change() {
        if not can_undo {
            return;
        }
        result = adapter.undo_plan(undo_token);
        if result["status"] == "completed" {
            can_undo = False;
            request_state = "undone";
            request_state_detail = "The last adaptation was undone.";
            last_change = result["changed"];
            show_preference_prompt = False;
        } else {
            request_state = "failed";
            request_state_detail = "Undo was not confirmed. Please refresh and retry.";
        }
    }

    def save_preference(scope: str) {
        if scope == "none" {
            show_preference_prompt = False;
            preference_message = "This change will not be saved.";
            return;
        }
        rule = adapter.approve_preference(scope, profile);
        saved_scope = rule.scope;
        localStorage.setItem("accessible-browser-dev-rule", rule.scope + "|" + rule.value + "|" + rule.createdAt);
        preference_message = "Approved for " + ("this page" if scope == "page" else ("this website" if scope == "website" else "all websites")) + ".";
        show_preference_prompt = False;
    }

    def toggle_simple_mode() {
        simple_mode = not simple_mode;
        if simple_mode {
            profile.reduceMotion = True;
            request_state = "applied";
            request_state_detail = "Simple Mode is on for this page.";
            last_change = "Reading mode is emphasizing the article and reducing distractions.";
            can_undo = True;
            undo_token = "dev-simple-mode-undo";
        } else {
            request_state = "undone";
            request_state_detail = "Returned to the normal page view.";
            last_change = "Simple Mode is off.";
            can_undo = False;
        }
    }

    def start_voice() {
        if voice_state == "off" or voice_state == "paused after silence" or voice_state == "unavailable" {
            voice_state = "activating";
            voice_message = "Starting voice mode. No microphone input is being faked.";
            setTimeout(lambda {
                voice_state = "listening";
                voice_message = "Listening for a constrained browser command.";
            }, 300);
        } else {
            voice_state = "off";
            voice_message = "Voice mode is off.";
        }
    }

    def stop_voice() {
        voice_state = "off";
        voice_message = "Voice mode is off.";
    }

    def run_voice_command() {
        if voice_command.strip() == "" {
            voice_message = "Type one of the listed commands to use the development adapter.";
            return;
        }
        if voice_command.lower() == "voice unavailable" {
            voice_state = "unavailable";
            voice_message = "Voice provider unavailable. You can keep using keyboard and text controls.";
            voice_command_shape = "No BrowserCommand sent because the voice provider is unavailable.";
            return;
        }
        voice_state = "processing";
        voice_message = "Checking the command against the allowlist...";
        setTimeout(lambda {
            allowed = ["new tab", "close tab", "switch tab", "back", "forward", "reload", "scroll", "zoom", "search", "read page", "stop reading"];
            if voice_command.lower() in allowed {
                command_kind = voice_command.lower().replace(" ", "_");
                command = BrowserCommand(kind=command_kind, arguments={"source": "development text-command adapter"}, requiresConfirmation=command_kind == "close_tab");
                voice_state = "speaking/confirming";
                voice_message = "Development adapter accepted: " + voice_command.lower() + ".";
                voice_command_shape = "BrowserCommand: " + command.kind + " · requestId " + command.requestId + " · confirmation " + ("required" if command.requiresConfirmation else "not required");
                setTimeout(lambda {
                    voice_state = "paused after silence";
                    voice_message = "Paused after silence. Start voice mode to continue.";
                }, 800);
            } else {
                voice_state = "error";
                voice_message = "That command is not in the constrained browser vocabulary.";
            }
        }, 300);
    }

    page_styles: str = """
        body { margin: 0; background: #f4f7f9; color: #17212b; font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
        button, input { font: inherit; }
        button { cursor: pointer; border: 0; border-radius: 10px; padding: 11px 14px; color: #17212b; background: #e9eef3; font-weight: 750; }
        button:hover { filter: brightness(0.97); }
        button:focus-visible, input:focus-visible { outline: 3px solid #155eef; outline-offset: 3px; }
        .experience-shell { max-width: 1120px; margin: 0 auto; padding: 36px 24px 56px; }
        .topbar, .card-heading, .page-context, .request-row, .scope-row, .button-row, .voice-controls { display: flex; align-items: center; gap: 16px; }
        .topbar, .page-context, .card-heading { justify-content: space-between; }
        .topbar { align-items: flex-start; gap: 28px; margin-bottom: 24px; }
        .eyebrow, .section-kicker { margin: 0 0 8px; color: #155eef; font-size: .78rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
        h1, h2, h3, p { margin-top: 0; }
        h1 { max-width: 720px; margin-bottom: 12px; font-size: clamp(2rem, 5vw, 3.5rem); line-height: 1.04; letter-spacing: -.04em; }
        h2 { margin-bottom: 0; font-size: 1.2rem; }
        h3 { margin-bottom: 8px; }
        .lede { max-width: 680px; margin-bottom: 0; color: #536273; font-size: 1.05rem; line-height: 1.55; }
        .adapter-badge, .state-pill, .confidence, .small-label { border-radius: 999px; padding: 7px 11px; background: #e8f0ff; color: #1249a0; font-size: .78rem; font-weight: 750; white-space: nowrap; }
        .status-dot { display: inline-block; width: 8px; height: 8px; margin-right: 6px; border-radius: 50%; background: #14804a; }
        .page-context, .request-card, .panel, .plan-card, .result-card { border: 1px solid #d6e0e8; border-radius: 18px; background: #fff; box-shadow: 0 12px 30px rgba(23, 33, 43, .06); }
        .warning-card { margin-bottom: 18px; border: 1px solid #e3a008; border-radius: 18px; padding: 24px; background: #fff8e1; color: #654b00; }
        .page-context, .request-card, .plan-card, .result-card { padding: 24px; }
        .page-context, .request-card, .plan-card, .result-card { margin-bottom: 18px; }
        .page-context h2 { margin-bottom: 5px; }
        .page-context p:last-child, .bridge-status, .context-note, .affected-target, .saved-rule, .footer-note, .command-list { margin-bottom: 0; color: #536273; font-size: .9rem; }
        .bridge-status { max-width: 340px; text-align: right; }
        .request-card label, .voice-controls + label { display: block; margin-bottom: 8px; font-weight: 700; }
        .request-row { align-items: stretch; }
        input { min-width: 0; flex: 1; border: 2px solid #b7c5d2; border-radius: 10px; padding: 13px 14px; color: #17212b; background: #fff; }
        input::placeholder { color: #647487; }
        .primary-button { color: #fff; background: #155eef; }
        .secondary-button { border: 1px solid #9fb0c0; background: #fff; }
        .text-button { padding: 4px 0; color: #155eef; background: transparent; text-decoration: underline; }
        .status-copy { margin: 14px 0 8px; font-weight: 700; }
        .content-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin-bottom: 18px; }
        .panel { padding: 22px; }
        .scope-row { flex-wrap: wrap; margin: 20px 0 12px; color: #536273; font-size: .9rem; font-weight: 700; }
        .scope-button { border: 1px solid #b7c5d2; padding: 8px 10px; background: #fff; font-size: .85rem; }
        .scope-button.selected, .preset-button.chosen { border-color: #155eef; color: #1249a0; background: #e8f0ff; }
        .control-list, .preset-list { display: grid; gap: 9px; }
        .setting-row, .preset-button { display: flex; align-items: center; justify-content: space-between; gap: 14px; width: 100%; border: 1px solid #d6e0e8; padding: 13px 14px; background: #fbfcfd; text-align: left; }
        .setting-row:hover, .preset-button:hover { border-color: #6e8eac; background: #f4f8fc; }
        .setting-row strong, .preset-button strong { display: block; margin-bottom: 4px; }
        .setting-row small, .preset-button small { display: block; color: #536273; font-weight: 500; }
        .toggle-state { min-width: 38px; color: #1249a0; font-size: .82rem; text-align: right; }
        .profile-summary { margin: 16px 0 0; color: #536273; font-size: .9rem; line-height: 1.45; }
        .plan-card { border-color: #8cb4ff; background: #f8fbff; }
        .plan-card > p, .result-card > p, .simple-mode-card > p, .panel > p { line-height: 1.5; }
        .affected-target { margin: 12px 0; }
        .action-list { margin: 0 0 14px; padding-left: 22px; line-height: 1.55; }
        .warning, .mode-note { border-left: 4px solid #e3a008; padding: 10px 12px; background: #fff8e1; color: #654b00; line-height: 1.45; }
        .preference-prompt { margin-top: 18px; border-top: 1px solid #d6e0e8; padding-top: 18px; }
        .preference-prompt p { color: #536273; }
        .button-row { flex-wrap: wrap; }
        .simple-mode-card .primary-button { margin-top: 4px; }
        .voice-controls { margin-bottom: 16px; }
        .command-list { margin-top: 10px; line-height: 1.5; }
        .footer-note { padding: 14px 2px; text-align: center; }
        @media (max-width: 760px) {
            .experience-shell { padding: 24px 16px 42px; }
            .topbar, .page-context, .card-heading { align-items: flex-start; flex-direction: column; }
            .bridge-status { text-align: left; }
            .content-grid { grid-template-columns: 1fr; }
            .request-row { align-items: stretch; flex-direction: column; }
        }
    """;

    <main className="experience-shell">
        <style>{page_styles}</style>
        <header className="topbar">
            <div>
                <p className="eyebrow">AccessibleBrowser · Jac experience</p>
                <h1>How should this page work better for you?</h1>
                <p className="lede">Choose a setting or describe what you need. You review every change before it reaches the page.</p>
            </div>
            <div className="adapter-badge" role="status" aria-live="polite">
                <span className="status-dot"></span>
                {adapter.source}
            </div>
        </header>

        <section className="page-context" aria-labelledby="page-context-title">
            <div>
                <p className="section-kicker">Current page</p>
                <h2 id="page-context-title">Example article</h2>
                <p>Ready on tab 1 · revision 1 · article-like page</p>
            </div>
            <p className="bridge-status" role="status" aria-live="polite">{bridge_status}</p>
        </section>

        <section className="request-card" aria-labelledby="request-title">
            <div className="card-heading">
                <div>
                    <p className="section-kicker">Ask Jac</p>
                    <h2 id="request-title">Describe a change in your own words</h2>
                </div>
                <span className="state-pill">{request_state}</span>
            </div>
            <label for="request-field">What would you like to change?</label>
            <div className="request-row">
                <input
                    id="request-field"
                    value={request_text}
                    placeholder="Make this page easier to read"
                    onChange={lambda (e: ChangeEvent) { request_text = e.target.value; }}
                />
                <button className="primary-button" onClick={submit_request}>Understand request</button>
            </div>
            <p className="status-copy" role="status" aria-live="polite">{request_state_detail}</p>
            <p className="context-note">Jac context: {active_preset} profile · {profile.summary()} · current page snapshot available.</p>
            <p className="context-note">Development state demos: type “offline”, “stale”, or “unsafe” to inspect unavailable, stale, and rejected responses.</p>
        </section>

        <div className="content-grid">
            <section className="panel" aria-labelledby="profile-title">
                <div className="card-heading">
                    <div>
                        <p className="section-kicker">Your profile</p>
                        <h2 id="profile-title">Quick controls</h2>
                    </div>
                    <span className="small-label">Applies to {scope_label()}</span>
                </div>
                <div className="scope-row" role="group" aria-label="Where should changes apply?">
                    <span>Apply to</span>
                    <button className={"scope-button " + ("selected" if selected_scope == "page" else "")} onClick={lambda { selected_scope = "page"; }}>This page</button>
                    <button className={"scope-button " + ("selected" if selected_scope == "website" else "")} onClick={lambda { selected_scope = "website"; }}>This website</button>
                    <button className={"scope-button " + ("selected" if selected_scope == "global" else "")} onClick={lambda { selected_scope = "global"; }}>All websites</button>
                </div>
                <div className="control-list">
                    <button className="setting-row" aria-pressed={profile.textScale != 1.0} onClick={lambda { apply_deterministic_change("larger_text"); }}>
                        <span><strong>Larger text</strong><small>Increase text scale</small></span>
                        <span className="toggle-state">{"On" if profile.textScale != 1.0 else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.spacing == "more"} onClick={lambda { apply_deterministic_change("spacing"); }}>
                        <span><strong>More spacing</strong><small>Separate lines and paragraphs</small></span>
                        <span className="toggle-state">{"On" if profile.spacing == "more" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.contrast == "high"} onClick={lambda { apply_deterministic_change("contrast"); }}>
                        <span><strong>High contrast</strong><small>Increase visual contrast</small></span>
                        <span className="toggle-state">{"On" if profile.contrast == "high" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.reduceMotion} onClick={lambda { apply_deterministic_change("motion"); }}>
                        <span><strong>Reduced motion</strong><small>Limit animated movement</small></span>
                        <span className="toggle-state">{"On" if profile.reduceMotion else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.enlargeTargets} onClick={lambda { apply_deterministic_change("targets"); }}>
                        <span><strong>Larger click targets</strong><small>Make controls easier to activate</small></span>
                        <span className="toggle-state">{"On" if profile.enlargeTargets else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.colorFilter != "none"} onClick={lambda { apply_deterministic_change("color_filter"); }}>
                        <span><strong>Color filter</strong><small>Use a soft reading tint</small></span>
                        <span className="toggle-state">{"On" if profile.colorFilter != "none" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={profile.readingFont == "reading"} onClick={lambda { apply_deterministic_change("reading_font"); }}>
                        <span><strong>Reading font</strong><small>Use a more readable font choice</small></span>
                        <span className="toggle-state">{"On" if profile.readingFont == "reading" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={focus_highlight} onClick={lambda { apply_deterministic_change("focus"); }}>
                        <span><strong>Focus highlights</strong><small>Make keyboard focus easier to see</small></span>
                        <span className="toggle-state">{"On" if focus_highlight else "Off"}</span>
                    </button>
                </div>
                <p className="profile-summary"><strong>{active_preset}</strong> · {profile.summary()}</p>
            </section>

            <section className="panel" aria-labelledby="preset-title">
                <div className="card-heading">
                    <div>
                        <p className="section-kicker">Starting points</p>
                        <h2 id="preset-title">Profile presets</h2>
                    </div>
                </div>
                <div className="preset-list">
                    <button className={"preset-button " + ("chosen" if active_preset == "Easier reading" else "")} onClick={lambda { set_profile_preset("Easier reading"); }}><strong>Easier reading</strong><small>Larger text and more spacing</small></button>
                    <button className={"preset-button " + ("chosen" if active_preset == "Low vision" else "")} onClick={lambda { set_profile_preset("Low vision"); }}><strong>Low vision</strong><small>Larger text, contrast, and targets</small></button>
                    <button className={"preset-button " + ("chosen" if active_preset == "Reduced motion" else "")} onClick={lambda { set_profile_preset("Reduced motion"); }}><strong>Reduced motion</strong><small>Limit animated movement</small></button>
                    <button className={"preset-button " + ("chosen" if active_preset == "Easier clicking" else "")} onClick={lambda { set_profile_preset("Easier clicking"); }}><strong>Easier clicking</strong><small>Larger targets and more spacing</small></button>
                    <button className={"preset-button " + ("chosen" if active_preset == "Custom" else "")} onClick={lambda { set_profile_preset("Custom"); }}><strong>Custom</strong><small>Adjust individual settings</small></button>
                </div>
            </section>
        </div>

        {plan_ready and <section className="plan-card" aria-labelledby="plan-title">
            <div className="card-heading">
                <div>
                    <p className="section-kicker">Review before applying</p>
                    <h2 id="plan-title">What will change?</h2>
                </div>
                <span className="confidence">Confidence: {plan_confidence}</span>
            </div>
            <p>{plan_summary}</p>
            <p className="affected-target">Affected target: current page · tab 1 · revision 1 · {plan_action_count} reversible action(s)</p>
            <ul className="action-list">{[<li key={index}>{action}</li> for (index, action) in enumerate(plan_actions)]}</ul>
            <p className="warning" role="note">{plan_warning}</p>
            <div className="button-row"><button className="primary-button" onClick={apply_plan}>Apply this plan</button><button className="secondary-button" onClick={cancel_plan}>Cancel</button></div>
        </section>}

        {(request_state == "rejected" or request_state == "llm unavailable" or request_state == "stale" or request_state == "failed") and <section className="warning-card" role="alert" aria-labelledby="request-problem-title">
            <p className="section-kicker">Request status</p>
            <h2 id="request-problem-title">{request_state}</h2>
            <p>{request_state_detail}</p>
            {rejection_message and <p className="warning">{rejection_message}</p>}
            {error_code and <p className="affected-target">Contract code: {error_code}</p>}
            <p className="context-note">No page mutation was attempted. You can revise the request or use a deterministic control.</p>
        </section>}

        <section className="result-card" aria-labelledby="result-title">
            <div className="card-heading">
                <div>
                    <p className="section-kicker">Change history</p>
                    <h2 id="result-title">What changed?</h2>
                </div>
                <span className="state-pill">{request_state}</span>
            </div>
            <p>{last_change}</p>
            {can_undo and <button className="secondary-button" onClick={undo_last_change}>Undo last adaptation</button>}
            {show_preference_prompt and <div className="preference-prompt" role="group" aria-labelledby="remember-title">
                <h3 id="remember-title">Remember this change?</h3>
                <p>Saving needs your approval. Just for now is never saved automatically.</p>
                <div className="button-row"><button className="scope-button" onClick={lambda { save_preference("page"); }}>Just for this page</button><button className="scope-button" onClick={lambda { save_preference("website"); }}>For this website</button><button className="scope-button" onClick={lambda { save_preference("global"); }}>For all websites</button><button className="text-button" onClick={lambda { save_preference("none"); }}>No thanks</button></div>
            </div>}
            <p className="saved-rule" role="status" aria-live="polite">{preference_message}</p>
            {saved_scope and <p className="saved-rule">Saved rule scope considered on reload: {saved_scope}.</p>}
        </section>

        <div className="content-grid">
            <section className="panel simple-mode-card" aria-labelledby="simple-title">
                <div className="card-heading"><div><p className="section-kicker">Focused reading</p><h2 id="simple-title">Simple Mode</h2></div><span className="state-pill">{"on" if simple_mode else "off"}</span></div>
                <p>Reduce distracting regions, emphasize article content, improve scale and spacing, and limit motion on normal article-like pages.</p>
                {simple_mode and <p className="mode-note">Simple Mode is emphasizing the main article and making headings and links easier to scan.</p>}
                <button className="primary-button" onClick={toggle_simple_mode}>{"Return to normal page" if simple_mode else "Turn on Simple Mode"}</button>
            </section>

            <section className="panel" aria-labelledby="voice-title">
                <div className="card-heading"><div><p className="section-kicker">Visible voice state</p><h2 id="voice-title">Voice mode</h2></div><span className="state-pill">{voice_state}</span></div>
                <p role="status" aria-live="polite">{voice_message}</p>
                <div className="voice-controls"><button className="primary-button" onClick={start_voice}>{"Exit voice mode" if voice_state != "off" else "Start voice mode"}</button><button className="secondary-button" onClick={stop_voice}>Stop</button></div>
                <label for="voice-command">Development text-command adapter</label>
                <div className="request-row"><input id="voice-command" value={voice_command} placeholder="read page" onChange={lambda (e: ChangeEvent) { voice_command = e.target.value; }} /><button className="secondary-button" onClick={run_voice_command}>Send command</button></div>
                <p className="command-list" role="status" aria-live="polite">{voice_command_shape}</p>
                <p className="command-list">Allowed: new tab · close tab · switch tab · back · forward · reload · scroll · zoom · search · read page · stop reading</p>
                <p className="context-note">Development state demo: type “voice unavailable” to show the provider-unavailable state.</p>
            </section>
        </div>

        <footer className="footer-note">Your page content is not saved by this fixture. Approved preference rules are local-first and scoped explicitly.</footer>
    </main>
}
