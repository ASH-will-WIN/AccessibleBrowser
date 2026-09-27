"""Jac-owned accessibility experience for the first live Phase 1 flow.

Planning, validation, page mutation, undo, and persistence stay behind the
typed Jac/Electron facades. The only development-only fallback left here is
the text command adapter for voice state demonstrations.
"""

import from .jac.core { AccessibilityProfile, BrowserCommand }

def profile_summary(profile: AccessibilityProfile) -> str {
    reading = "standard text" if profile.textScale == 1.0 else "larger text";
    spacing_text = "standard spacing" if profile.spacing == "normal" else "more spacing";
    contrast_text = "standard contrast" if profile.contrast == "normal" else "high contrast";
    filter_text = "no color filter" if profile.colorFilter == "none" else "a color filter";
    motion_text = "reduced motion" if profile.reduceMotion else "normal motion";
    target_text = "larger click targets" if profile.enlargeTargets else "standard click targets";
    font_text = "reading font" if profile.readingFont != "default" else "default font";
    return reading + ", " + spacing_text + ", " + contrast_text + ", " + filter_text + ", " + motion_text + ", " + target_text + ", " + font_text;
}

def profile_from_wire(data: any) -> AccessibilityProfile {
    return AccessibilityProfile(
        textScale=data.get("textScale", 1.0) as float,
        spacing=data.get("spacing", "normal") as str,
        contrast=data.get("contrast", "normal") as str,
        colorFilter=data.get("colorFilter", "none") as str,
        reduceMotion=data.get("reduceMotion", False) as bool,
        enlargeTargets=data.get("enlargeTargets", False) as bool,
        readingFont=data.get("readingFont", "default") as str,
        voiceEnabled=data.get("voiceEnabled", False) as bool
    );
}

def:pub app -> JsxElement {
    has request_text: str = "",
        active_preset: str = "Easier reading",
        profile: AccessibilityProfile = AccessibilityProfile(),
        selected_scope: str = "page",
        request_state: str = "idle",
        request_state_detail: str = "Ready for a request.",
        plan_ready: bool = False,
        reviewed_wire_plan: dict[str, any] = {},
        pending_profile: AccessibilityProfile = AccessibilityProfile(),
        has_pending_profile: bool = False,
        current_page: dict[str, any] = {},
        page_title: str = "Loading current page…",
        page_url: str = "",
        page_tab_id: str = "",
        page_revision: int = 0,
        page_origin: str = "",
        plan_summary: str = "",
        plan_explanation: str = "",
        plan_confidence: str = "",
        plan_warning: str = "",
        plan_actions: list[str] = [],
        plan_action_count: int = 0,
        rejection_message: str = "",
        error_code: str = "",
        can_undo: bool = False,
        undo_token: str = "",
        profile_before_apply: AccessibilityProfile = AccessibilityProfile(),
        has_profile_before_apply: bool = False,
        simple_mode_before_apply: bool = False,
        focus_highlight_before_apply: bool = False,
        last_change: str = "No adaptation applied yet.",
        show_preference_prompt: bool = False,
        preference_message: str = "No approved saved rule for this page.",
        persistence_message: str = "",
        saved_scope: str = "",
        simple_mode: bool = False,
        focus_highlight: bool = False,
        voice_state: str = "unavailable",
        voice_command: str = "",
        voice_message: str = "Voice provider unavailable. Keyboard and text controls are available.",
        voice_command_shape: str = "No command sent yet.",
        development_adapter_enabled: bool = False,
        bridge_status: str = "Connecting Jac planner and Electron page host…",
        last_planning_mode: str = "llm",
        stale_retry_count: int = 0,
        auto_apply_saved: bool = False,
        submit_timer: float = 0.0;

    bridge: any = window as any;

    async can with entry {
        try {
            bridge.browser.onPageChanged(lambda (message: any) {
                if message {
                    # Keep the experience window's visible context synchronized
                    # with the active Chromium page. The old handler updated
                    # only the revision, so the panel could keep displaying a
                    # previous page (for example, Google) while applying to the
                    # current page.
                    page_tab_id = message.tabId;
                    if message.title { page_title = message.title; }
                    if message.url { page_url = message.url; }
                }
                if message and message.pageRevision != page_revision {
                    page_revision = message.pageRevision;
                    current_page = {};
                    can_undo = False;
                    if plan_ready {
                        plan_ready = False;
                        request_state = "stale";
                        error_code = "STALE_PAGE_REVISION";
                        request_state_detail = "The page changed before the preview was applied. Refresh the snapshot and retry.";
                    }
                    bridge_status = "Live page changed · preview and undo are no longer current";
                    if message.reason == "navigation" or message.reason == "loaded" {
                        auto_apply_saved = True;
                        request_state = "understanding";
                        request_state_detail = "Checking your approved accessibility preferences for this page...";
                        if submit_timer { clearTimeout(submit_timer); }
                        submit_timer = setTimeout(lambda { request_plan("apply saved accessibility preferences", "deterministic"); }, 100);
                    }
                }
            });
        } except Exception { }
        try {
            snapshot: any = await bridge.browser.getActivePageSnapshot();
            if snapshot and snapshot.status == "rejected" {
                bridge_status = "Bridge rejected the page snapshot: " + snapshot.error.message;
                request_state = "failed";
                request_state_detail = "The live page snapshot was rejected. No page change was attempted.";
            } elif snapshot {
                current_page = snapshot;
                page_title = snapshot.title if snapshot.title else snapshot.url;
                page_url = snapshot.url;
                page_tab_id = snapshot.tabId;
                page_revision = snapshot.pageRevision;
                page_origin = snapshot.origin;
                bridge_status = "Bridge connected · Jac planner · live Chromium page";
                browser_state: any = await bridge.browser.getBrowserState();
                development_adapter_enabled = browser_state.developmentFixtureEnabled if browser_state else False;
                active_profile: any = await bridge.accessibleBrowser.jac.getActiveProfile();
                if active_profile { profile = profile_from_wire(active_profile); }
                rules: any = await bridge.accessibleBrowser.jac.getApplicablePreferences(snapshot.origin, snapshot.url);
                if rules and len(rules) > 0 {
                    saved_scope = rules[0].scope;
                    preference_message = "Applying your approved " + rules[0].scope + " accessibility preferences.";
                    auto_apply_saved = True;
                    request_state = "understanding";
                    request_state_detail = "Jac is applying your approved accessibility preferences...";
                    await request_plan("apply saved accessibility preferences", "deterministic");
                }
            }
        } except Exception as error {
            bridge_status = "Bridge unavailable: " + str(error);
            request_state = "unavailable";
            request_state_detail = "The Jac planner is unavailable. Deterministic controls remain available.";
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
            profile = AccessibilityProfile(enlargeTargets=True, spacing="comfortable");
        } elif preset == "Custom" {
            active_preset = "Custom";
        } else {
            profile = AccessibilityProfile(textScale=1.15, spacing="comfortable", readingFont="default");
        }
        last_change = "Profile ready: " + active_preset + ".";
    }

    def profile_for_change(change: str, source: AccessibilityProfile = profile) -> AccessibilityProfile {
        next_profile = AccessibilityProfile(
            textScale=source.textScale,
            spacing=source.spacing,
            contrast=source.contrast,
            colorFilter=source.colorFilter,
            reduceMotion=source.reduceMotion,
            enlargeTargets=source.enlargeTargets,
            readingFont=source.readingFont,
            voiceEnabled=source.voiceEnabled
        );
        if change == "larger_text" {
            next_profile.textScale = 1.25 if source.textScale == 1.0 else 1.0;
        } elif change == "spacing" {
            next_profile.spacing = "normal" if source.spacing == "comfortable" else "comfortable";
        } elif change == "contrast" {
            next_profile.contrast = "normal" if source.contrast == "high" else "high";
        } elif change == "motion" {
            next_profile.reduceMotion = not source.reduceMotion;
        } elif change == "targets" {
            next_profile.enlargeTargets = not source.enlargeTargets;
        } elif change == "color_filter" {
            next_profile.colorFilter = "none" if source.colorFilter == "grayscale" else "grayscale";
        } elif change == "reading_font" {
            next_profile.readingFont = "default" if source.readingFont != "default" else "reading";
        }
        return next_profile;
    }

    def deterministic_request(change: str) -> str {
        if change == "larger_text" { return "Restore standard text size" if profile.textScale != 1.0 else "Make the text larger"; }
        if change == "spacing" { return "Restore standard spacing" if profile.spacing == "comfortable" else "Add more spacing between lines"; }
        if change == "contrast" { return "Restore standard contrast" if profile.contrast == "high" else "Increase contrast"; }
        if change == "motion" { return "Restore normal motion" if profile.reduceMotion else "Reduce motion"; }
        if change == "targets" { return "Restore standard click targets" if profile.enlargeTargets else "Make the buttons easier to click"; }
        if change == "color_filter" {
            return "Remove the color filter" if profile.colorFilter != "none" else "Apply a grayscale color filter";
        }
        if change == "reading_font" {
            return "Restore the default font" if profile.readingFont != "default" else "Use a more readable font";
        }
        if change == "focus" { return "Highlight elements for keyboard focus"; }
        return "Use a more readable font";
    }

    def toggle_quick_action(change: str) {
        base_profile = pending_profile if has_pending_profile else profile;
        pending_profile = profile_for_change(change, base_profile);
        has_pending_profile = True;
        active_preset = "Custom";
        request_state = "ready";
        request_state_detail = "Quick actions selected. Apply them together when ready.";
    }

    def quick_action_request() -> str {
        changes: list[str] = [];
        if pending_profile.textScale != profile.textScale { changes.append("make the text larger" if pending_profile.textScale != 1.0 else "restore standard text size"); }
        if pending_profile.spacing != profile.spacing { changes.append("add more spacing" if pending_profile.spacing == "comfortable" else "restore standard spacing"); }
        if pending_profile.contrast != profile.contrast { changes.append("increase contrast" if pending_profile.contrast == "high" else "restore standard contrast"); }
        if pending_profile.reduceMotion != profile.reduceMotion { changes.append("reduce motion" if pending_profile.reduceMotion else "restore normal motion"); }
        if pending_profile.enlargeTargets != profile.enlargeTargets { changes.append("make the buttons easier to click" if pending_profile.enlargeTargets else "restore standard click targets"); }
        if pending_profile.colorFilter != profile.colorFilter { changes.append("apply a grayscale color filter" if pending_profile.colorFilter != "none" else "remove the color filter"); }
        if pending_profile.readingFont != profile.readingFont { changes.append("use a more readable font" if pending_profile.readingFont == "reading" else "restore the default font"); }
        return " and ".join(changes);
    }

    def apply_quick_actions() {
        if not has_pending_profile { return; }
        request_text = quick_action_request();
        if request_text.strip() == "" { has_pending_profile = False; return; }
        request_state = "understanding";
        request_state_detail = "Jac is preparing one combined deterministic change...";
        plan_ready = False;
        show_preference_prompt = False;
        stale_retry_count = 0;
        if submit_timer { clearTimeout(submit_timer); }
        submit_timer = setTimeout(lambda { request_plan(request_text, "deterministic"); }, 100);
    }

    async def request_plan(request_value: str, planning_mode: str) {
        try {
            last_planning_mode = planning_mode;
            snapshot: any = await bridge.browser.getActivePageSnapshot();
            if not snapshot or snapshot.status == "rejected" {
                request_state = "failed";
                error_code = snapshot.error.code if snapshot and snapshot.error else "PAGE_SNAPSHOT_UNAVAILABLE";
                request_state_detail = "The live page snapshot was unavailable. No page change was attempted.";
                return;
            }
            current_page = snapshot;
            page_title = snapshot.title if snapshot.title else snapshot.url;
            page_url = snapshot.url;
            page_tab_id = snapshot.tabId;
            page_revision = snapshot.pageRevision;
            page_origin = snapshot.origin;
            request_payload = {
                "requestId": "ui-request-" + str(Date.now()),
                "userRequest": request_value,
                "tabId": snapshot.tabId,
                "pageRevision": snapshot.pageRevision,
                # Send the profile that is currently active on the page. The
                # pending profile is the desired post-apply UI state; sending
                # it here makes Jac think the requested change is already
                # active and incorrectly produces NO_OP.
                "profile": profile,
                "page": snapshot,
                "mode": planning_mode
            };
            adaptation_request: any = await bridge.accessibleBrowser.jac.createAdaptationRequest(request_payload);
            plan_result: any = await bridge.accessibleBrowser.jac.createAdaptationPlan(adaptation_request);
            if not plan_result or not plan_result.ok {
                plan_error: any = plan_result.error if plan_result and plan_result.error else {"code": "PLAN_UNAVAILABLE", "message": "Jac could not create a plan."};
                error_code = plan_error.code as str;
                rejection_message = plan_error.message as str;
                request_state = "rejected" if plan_error.code == "INVALID_PLAN" else ("llm unavailable" if plan_error.code == "LLM_UNAVAILABLE" else ("stale" if plan_error.code == "STALE_PAGE_REVISION" else "failed"));
                request_state_detail = plan_error.message as str;
                return;
            }
            wire_plan = plan_result.plan;
            plan_summary = wire_plan.summary if wire_plan.summary else "Jac did not identify a supported accessibility change.";
            plan_warning = "; ".join(wire_plan.warnings) if len(wire_plan.warnings) > 0 else "Try a specific request such as larger text, more spacing, higher contrast, reduced motion, larger click targets, a color filter, reading font, or reading mode.";
            if wire_plan.status != "ready" or len(wire_plan.actions) == 0 {
                if auto_apply_saved {
                    auto_apply_saved = False;
                    request_state = "idle";
                    request_state_detail = "Your approved accessibility preferences are already active.";
                    error_code = "";
                    rejection_message = "";
                    return;
                }
                error_code = "NO_OP";
                rejection_message = plan_summary;
                request_state = "rejected";
                request_state_detail = plan_summary + " " + plan_warning;
                return;
            }
            clean_actions: list[dict[str, any]] = [{
                "actionId": action.actionId,
                "type": action.type,
                "parameters": action.parameters,
                "reason": action.reason,
                "reversible": action.reversible,
                "targetElementIds": action.targetElementIds if action.targetElementIds else []
            } for action in wire_plan.actions];
            reviewed_wire_plan = {
                "schemaVersion": wire_plan.schemaVersion,
                "planId": wire_plan.planId,
                "requestId": wire_plan.requestId,
                "tabId": wire_plan.tabId,
                "pageRevision": wire_plan.pageRevision,
                "summary": wire_plan.summary,
                "actions": clean_actions,
                "confidence": wire_plan.confidence,
                "warnings": wire_plan.warnings,
                "suggestedScope": wire_plan.suggestedScope,
                "status": wire_plan.status
            };
            explanation: any = await bridge.accessibleBrowser.jac.explainAdaptationPlan(wire_plan);
            plan_summary = wire_plan.summary;
            plan_explanation = explanation.whatWillChange if explanation and explanation.whatWillChange else wire_plan.summary;
            plan_confidence = wire_plan.confidence;
            plan_warning = "; ".join(wire_plan.warnings) if len(wire_plan.warnings) > 0 else "Every action is allowlisted and reversible.";
            plan_action_count = len(wire_plan.actions);
            plan_actions = [action.type.replace("_", " ") + ": " + action.reason for action in wire_plan.actions];
            rejection_message = "";
            error_code = "";
            plan_ready = True;
            if auto_apply_saved {
                await apply_plan();
                return;
            }
            request_state = "preview";
            request_state_detail = "Preview ready. Nothing has changed on the page yet.";
        } except Exception as error {
            error_code = "JAC_UNAVAILABLE";
            request_state = "llm unavailable";
            request_state_detail = "The Jac planner could not be reached: " + str(error);
        }
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
        if submit_timer { clearTimeout(submit_timer); }
        has_pending_profile = False;
        stale_retry_count = 0;
        submit_timer = setTimeout(lambda { request_plan(request_text, "llm"); }, 100);
    }

    def cancel_plan() {
        plan_ready = False;
        request_state = "idle";
        request_state_detail = "Preview cancelled. You can revise the request.";
    }

    async def apply_plan() {
        if not plan_ready {
            return;
        }
        request_state = "applying";
        request_state_detail = "Checking the plan and applying it safely...";
        try {
            result: any = await bridge.browser.applyAdaptationPlan(reviewed_wire_plan);
        } except Exception as error {
            request_state = "failed";
            error_code = "APPLY_FAILED";
            request_state_detail = "The page host could not apply the plan: " + str(error);
            return;
        }
        if result["status"] == "completed" {
            request_state = "applied";
            request_state_detail = "Electron confirmed the change on the current page.";
            last_change = plan_explanation;
            can_undo = True;
            undo_token = result["undoToken"];
            show_preference_prompt = not auto_apply_saved;
            auto_apply_saved = False;
            plan_ready = False;
            error_code = "";
            simple_mode_before_apply = simple_mode;
            focus_highlight_before_apply = focus_highlight;
            if "simplify this page" in request_text.lower() or "simple mode" in request_text.lower() { simple_mode = True; }
            if "focus" in request_text.lower() or "highlight" in request_text.lower() { focus_highlight = True; }
            if has_pending_profile {
                profile_before_apply = profile;
                has_profile_before_apply = True;
                profile = pending_profile;
                has_pending_profile = False;
            }
            # Persist the settings represented by any successfully applied
            # plan, including multi-action LLM plans. The page mutation is
            # still owned by Electron; this only updates Jac's in-memory
            # profile so explicit preference saving remembers what the user
            # actually approved and applied.
            for action in reviewed_wire_plan["actions"] {
                action_type = action["type"];
                parameters = action["parameters"];
                if action_type == "set_text_scale" { profile.textScale = parameters["scale"]; }
                if action_type == "set_spacing" { profile.spacing = "comfortable" if parameters.get("lineHeight", 1.0) > 1.0 else "normal"; }
                if action_type == "set_contrast" { profile.contrast = parameters["level"]; }
                if action_type == "set_color_filter" { profile.colorFilter = parameters["filter"]; }
                if action_type == "set_reading_font" { profile.readingFont = parameters["font"]; }
                if action_type == "reduce_motion" { profile.reduceMotion = parameters["enabled"]; }
                if action_type == "enlarge_targets" { profile.enlargeTargets = parameters["enabled"]; }
            }
            try {
                await bridge.accessibleBrowser.jac.recordApplyResult({
                    "requestId": reviewed_wire_plan["requestId"],
                    "planId": reviewed_wire_plan["planId"],
                    "result": result["result"],
                    "undoToken": result["undoToken"]
                });
            } except Exception { }
            try {
                proposal: any = await bridge.accessibleBrowser.jac.proposePersistence(reviewed_wire_plan);
                persistence_message = proposal.message if proposal and proposal.message else "Applying a plan never saves it automatically.";
                preference_message = persistence_message;
            } except Exception {
                persistence_message = "Choose a scope only if you want Jac to remember this change.";
                preference_message = persistence_message;
            }
        } elif result["error"] and result["error"]["code"] == "STALE_PAGE_REVISION" {
            if stale_retry_count < 1 {
                stale_retry_count += 1;
                plan_ready = False;
                error_code = "";
                request_state = "understanding";
                request_state_detail = "The page changed while the planner was working. Refreshing the snapshot and preparing a new preview...";
                await request_plan(request_text, last_planning_mode);
            } else {
                request_state = "stale";
                error_code = result["error"]["code"];
                request_state_detail = "The page changed again before applying. Review the current page and retry.";
            }
        } elif result["status"] == "rejected" {
            request_state = "rejected";
            error_code = result["error"]["code"] if result["error"] else "INVALID_PLAN";
            rejection_message = result["error"]["message"] if result["error"] else "The page host rejected the plan.";
            request_state_detail = "The plan was rejected before any page change.";
        } else {
            request_state = "failed";
            error_code = result["error"]["code"] if result["error"] else "APPLY_FAILED";
            request_state_detail = result["error"]["message"] if result["error"] else "The page host did not confirm the adaptation.";
        }
    }

    async def undo_last_change() {
        if not can_undo {
            return;
        }
        try {
            result: any = await bridge.browser.undoAdaptation(undo_token);
        } except Exception as error {
            request_state = "failed";
            request_state_detail = "Undo failed: " + str(error);
            return;
        }
        if result["status"] == "completed" {
            can_undo = False;
            request_state = "undone";
            request_state_detail = "The last adaptation was undone.";
            last_change = result["result"];
            show_preference_prompt = False;
            if has_profile_before_apply {
                profile = profile_before_apply;
                has_profile_before_apply = False;
            }
            simple_mode = simple_mode_before_apply;
            focus_highlight = focus_highlight_before_apply;
        } elif result["error"] and result["error"]["code"] == "UNDO_FAILED" {
            can_undo = False;
            request_state = "stale";
            error_code = "UNDO_FAILED";
            request_state_detail = "The page changed, so this undo token is no longer valid. Refresh and retry the adaptation.";
        } else {
            request_state = "failed";
            request_state_detail = "Undo was not confirmed. Please refresh and retry.";
        }
    }

    async def save_preference(scope: str) {
        if scope == "none" {
            show_preference_prompt = False;
            preference_message = "This change will not be saved.";
            return;
        }
        try {
            timestamp = new(Date).toISOString();
            origin_value = page_origin if scope != "global" else "";
            page_value = page_url if scope == "page" else "";
            settings = [
                {"setting": "textScale", "value": profile.textScale},
                {"setting": "spacing", "value": profile.spacing},
                {"setting": "contrast", "value": profile.contrast},
                {"setting": "colorFilter", "value": profile.colorFilter},
                {"setting": "reduceMotion", "value": profile.reduceMotion},
                {"setting": "enlargeTargets", "value": profile.enlargeTargets},
                {"setting": "readingFont", "value": profile.readingFont}
            ];
            all_saved = True;
            for setting in settings {
                rule = {
                    "setting": setting["setting"],
                    "value": setting["value"],
                    "scope": scope,
                    "source": "manual",
                    "explicitlyApproved": True,
                    "createdAt": timestamp,
                    "updatedAt": timestamp,
                    "origin": origin_value,
                    "pageUrl": page_value
                };
                result: any = await bridge.accessibleBrowser.jac.saveApprovedPreference(rule, True);
                if not result or not result.ok { all_saved = False; }
            }
            if all_saved {
                saved_scope = scope;
                preference_message = "Approved for " + ("this page" if scope == "page" else ("this website" if scope == "website" else "all websites")) + ".";
                show_preference_prompt = False;
            } else {
                preference_message = "The preference was not saved: Jac rejected one or more profile settings.";
            }
        } except Exception as error {
            preference_message = "The preference was not saved: " + str(error);
        }
    }

    async def toggle_simple_mode() {
        if simple_mode {
            await undo_last_change();
            if request_state == "undone" { simple_mode = False; }
            return;
        }
        pending_profile = profile_for_change("motion");
        pending_profile.reduceMotion = True;
        has_pending_profile = True;
        request_text = "Simplify this page with reading mode and reduced motion";
        request_state = "understanding";
        request_state_detail = "Jac is preparing a Simple Mode preview. Nothing has changed on the page yet.";
        plan_ready = False;
        show_preference_prompt = False;
        stale_retry_count = 0;
        await request_plan(request_text, "deterministic");
    }

    def start_voice() {
        voice_state = "unavailable";
        voice_message = "Voice provider unavailable. Use keyboard or the development text-command adapter.";
    }

    def stop_voice() {
        voice_state = "off";
        voice_message = "Voice mode is off.";
    }

    def voice_arguments(command_kind: str) -> dict[str, any] {
        if command_kind == "scroll" { return {"deltaY": 500}; }
        if command_kind == "zoom" { return {"factor": 1.1}; }
        if command_kind == "search" { return {"searchType": "page", "query": "article"}; }
        if command_kind == "switch_tab" { return {"tabId": page_tab_id}; }
        return {};
    }

    async def run_voice_command() {
        if not development_adapter_enabled {
            voice_state = "unavailable";
            voice_message = "Voice provider unavailable, and the development text adapter is disabled outside development mode.";
            return;
        }
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
        allowed = ["new tab", "close tab", "switch tab", "back", "forward", "reload", "scroll", "zoom", "search", "read page", "stop reading"];
        if voice_command.lower() not in allowed {
            voice_state = "error";
            voice_message = "That command is not in the constrained browser vocabulary.";
            return;
        }
        command_kind = voice_command.lower().replace(" ", "_");
        command = BrowserCommand(
            schemaVersion=1,
            requestId="voice-command-" + str(Date.now()),
            tabId=page_tab_id,
            kind=command_kind,
            arguments=voice_arguments(command_kind),
            requiresConfirmation=command_kind == "close_tab"
        );
        try {
            result: any = await bridge.browser.executeBrowserCommand(command);
            if result and (result.status == "completed" or result.status == "accepted") {
                voice_state = "speaking/confirming";
                voice_message = "Development text-command adapter sent a constrained browser command. No microphone input was used.";
                voice_command_shape = "BrowserCommand: " + command.kind + " · requestId " + command.requestId + " · confirmation " + ("required" if command.requiresConfirmation else "not required");
            } else {
                voice_state = "error";
                voice_message = result.error.message if result and result.error else "The browser command was not accepted.";
            }
        } except Exception as error {
            voice_state = "error";
            voice_message = "The development command adapter failed: " + str(error);
        }
    }

    page_styles: str = """
        :root { color-scheme: dark; }
        body { margin: 0; background: #202124; color: #f1f3f4; font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
        button, input { font: inherit; }
        button { cursor: pointer; border: 1px solid #4a4d52; border-radius: 10px; padding: 11px 14px; color: #f1f3f4; background: #303134; font-weight: 750; transition: background .16s ease, border-color .16s ease, transform .16s ease; }
        button:hover { border-color: #6e7781; background: #3c4043; transform: translateY(-1px); }
        button:focus-visible, input:focus-visible { outline: 3px solid #8ab4f8; outline-offset: 3px; }
        .experience-shell { max-width: 1180px; margin: 0 auto; padding: 32px 24px 56px; }
        .topbar, .card-heading, .page-context, .request-row, .scope-row, .button-row, .voice-controls { display: flex; align-items: center; gap: 16px; }
        .topbar, .page-context, .card-heading { justify-content: space-between; }
        .topbar { align-items: flex-start; gap: 28px; margin-bottom: 24px; }
        .eyebrow, .section-kicker { margin: 0 0 8px; color: #8ab4f8; font-size: .78rem; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
        h1, h2, h3, p { margin-top: 0; }
        h1 { max-width: 720px; margin-bottom: 12px; font-size: clamp(1.8rem, 4vw, 2.8rem); line-height: 1.08; letter-spacing: -.035em; }
        h2 { margin-bottom: 0; font-size: 1.2rem; }
        h3 { margin-bottom: 8px; }
        .lede { max-width: 680px; margin-bottom: 0; color: #bdc1c6; font-size: 1.02rem; line-height: 1.55; }
        .adapter-badge, .state-pill, .confidence, .small-label { border-radius: 999px; padding: 7px 11px; background: #293b5a; color: #a8c7fa; font-size: .78rem; font-weight: 750; white-space: nowrap; }
        .status-dot { display: inline-block; width: 8px; height: 8px; margin-right: 6px; border-radius: 50%; background: #81c995; box-shadow: 0 0 10px rgba(129, 201, 149, .55); }
        .page-context, .request-card, .panel, .plan-card, .result-card { border: 1px solid #3c4043; border-radius: 16px; background: #292a2d; box-shadow: 0 14px 34px rgba(0, 0, 0, .22); }
        .warning-card { margin-bottom: 18px; border: 1px solid #80621d; border-radius: 16px; padding: 24px; background: #332d1e; color: #f8d486; }
        .page-context, .request-card, .plan-card, .result-card { padding: 24px; }
        .page-context, .request-card, .plan-card, .result-card { margin-bottom: 18px; }
        .page-context h2 { margin-bottom: 5px; }
        .page-context p:last-child, .bridge-status, .context-note, .affected-target, .saved-rule, .footer-note, .command-list { margin-bottom: 0; color: #bdc1c6; font-size: .9rem; }
        .bridge-status { max-width: 340px; text-align: right; }
        .request-card label, .voice-controls + label { display: block; margin-bottom: 8px; font-weight: 700; }
        .request-row { align-items: stretch; }
        input { min-width: 0; flex: 1; border: 1px solid #5f6368; border-radius: 10px; padding: 13px 14px; color: #f1f3f4; background: #202124; }
        input::placeholder { color: #9aa0a6; }
        .primary-button { border-color: #8ab4f8; color: #202124; background: #8ab4f8; }
        .primary-button:hover { border-color: #aecbfa; background: #aecbfa; }
        .secondary-button { border: 1px solid #5f6368; background: #303134; }
        .text-button { padding: 4px 0; color: #8ab4f8; background: transparent; text-decoration: underline; }
        .status-copy { margin: 14px 0 8px; font-weight: 700; }
        .content-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; margin-bottom: 18px; }
        .panel { padding: 22px; }
        .scope-row { flex-wrap: wrap; margin: 20px 0 12px; color: #bdc1c6; font-size: .9rem; font-weight: 700; }
        .scope-button { border: 1px solid #5f6368; padding: 8px 10px; background: #303134; font-size: .85rem; }
        .scope-button.selected, .preset-button.chosen { border-color: #8ab4f8; color: #a8c7fa; background: #293b5a; }
        .control-list, .preset-list { display: grid; gap: 9px; }
        .setting-row, .preset-button { display: flex; align-items: center; justify-content: space-between; gap: 14px; width: 100%; border: 1px solid #3c4043; padding: 13px 14px; background: #303134; text-align: left; }
        .setting-row:hover, .preset-button:hover { border-color: #6f8fc8; background: #293b5a; }
        .setting-row strong, .preset-button strong { display: block; margin-bottom: 4px; }
        .setting-row small, .preset-button small { display: block; color: #bdc1c6; font-weight: 500; }
        .toggle-state { min-width: 38px; color: #a8c7fa; font-size: .82rem; text-align: right; }
        .profile-summary { margin: 16px 0 0; color: #bdc1c6; font-size: .9rem; line-height: 1.45; }
        .plan-card { border-color: #5878ae; background: #232f43; }
        .plan-card > p, .result-card > p, .simple-mode-card > p, .panel > p { line-height: 1.5; }
        .affected-target { margin: 12px 0; }
        .action-list { margin: 0 0 14px; padding-left: 22px; line-height: 1.55; }
        .warning, .mode-note { border-left: 4px solid #e3a008; padding: 10px 12px; background: #332d1e; color: #f8d486; line-height: 1.45; }
        .preference-prompt { margin-top: 18px; border-top: 1px solid #3c4043; padding-top: 18px; }
        .preference-prompt p { color: #bdc1c6; }
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
                <p className="eyebrow">Accessa · Jac experience</p>
                <h1>How should this page work better for you?</h1>
                <p className="lede">Choose a setting or describe what you need. You review every change before it reaches the page.</p>
            </div>
            <div className="adapter-badge" role="status" aria-live="polite">
                <span className="status-dot"></span>
                Jac planner · typed Electron bridge
            </div>
        </header>

        <section className="page-context" aria-labelledby="page-context-title">
            <div>
                <p className="section-kicker">Current page</p>
                <h2 id="page-context-title">{page_title}</h2>
                <p>Ready on tab {page_tab_id} · revision {page_revision} · live Chromium snapshot</p>
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
            <p className="context-note">Jac context: {active_preset} profile · {profile_summary(profile)} · current page snapshot available.</p>
            <p className="context-note">The request is sent to Jac with the current profile and live page snapshot. The preview is validated again by Electron before any page mutation.</p>
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
                    <button className="setting-row" aria-pressed={(pending_profile.textScale if has_pending_profile else profile.textScale) != 1.0} onClick={lambda { toggle_quick_action("larger_text"); }}>
                        <span><strong>Larger text</strong><small>Increase text scale</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.textScale if has_pending_profile else profile.textScale) != 1.0 else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.spacing if has_pending_profile else profile.spacing) == "comfortable"} onClick={lambda { toggle_quick_action("spacing"); }}>
                        <span><strong>More spacing</strong><small>Separate lines and paragraphs</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.spacing if has_pending_profile else profile.spacing) == "comfortable" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.contrast if has_pending_profile else profile.contrast) == "high"} onClick={lambda { toggle_quick_action("contrast"); }}>
                        <span><strong>High contrast</strong><small>Increase visual contrast</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.contrast if has_pending_profile else profile.contrast) == "high" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.reduceMotion if has_pending_profile else profile.reduceMotion)} onClick={lambda { toggle_quick_action("motion"); }}>
                        <span><strong>Reduced motion</strong><small>Limit animated movement</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.reduceMotion if has_pending_profile else profile.reduceMotion) else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.enlargeTargets if has_pending_profile else profile.enlargeTargets)} onClick={lambda { toggle_quick_action("targets"); }}>
                        <span><strong>Larger click targets</strong><small>Make controls easier to activate</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.enlargeTargets if has_pending_profile else profile.enlargeTargets) else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.colorFilter if has_pending_profile else profile.colorFilter) != "none"} onClick={lambda { toggle_quick_action("color_filter"); }}>
                        <span><strong>Color filter</strong><small>Use a soft reading tint</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.colorFilter if has_pending_profile else profile.colorFilter) != "none" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={(pending_profile.readingFont if has_pending_profile else profile.readingFont) == "reading"} onClick={lambda { toggle_quick_action("reading_font"); }}>
                        <span><strong>Reading font</strong><small>Use a more readable font choice</small></span>
                        <span className="toggle-state">{"On" if (pending_profile.readingFont if has_pending_profile else profile.readingFont) == "reading" else "Off"}</span>
                    </button>
                    <button className="setting-row" aria-pressed={focus_highlight} onClick={lambda { apply_deterministic_change("focus"); }}>
                        <span><strong>Focus highlights</strong><small>Make keyboard focus easier to see</small></span>
                        <span className="toggle-state">{"On" if focus_highlight else "Off"}</span>
                    </button>
                </div>
                {has_pending_profile and <div className="button-row quick-actions-apply"><button className="primary-button" onClick={apply_quick_actions}>Apply quick actions</button><button className="text-button" onClick={lambda { has_pending_profile = False; request_state_detail = "Quick actions cleared."; }}>Clear</button></div>}
                <p className="profile-summary"><strong>{active_preset}</strong> · {profile_summary(profile)}</p>
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
            <p className="context-note">{plan_explanation}</p>
            <p className="affected-target">Affected target: current page · tab {page_tab_id} · revision {page_revision} · {plan_action_count} reversible action(s)</p>
            <ul className="action-list">{[<li key={index}>{action}</li> for (index, action) in enumerate(plan_actions)]}</ul>
            <p className="warning" role="note">{plan_warning}</p>
            <div className="button-row"><button className="primary-button" onClick={apply_plan}>Apply this plan</button><button className="secondary-button" onClick={cancel_plan}>Cancel</button></div>
        </section>}

        {(request_state == "rejected" or request_state == "llm unavailable" or request_state == "unavailable" or request_state == "stale" or request_state == "failed") and <section className="warning-card" role="alert" aria-labelledby="request-problem-title">
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
                {development_adapter_enabled and <div>
                    <label for="voice-command">Development text-command adapter (no microphone input)</label>
                    <div className="request-row"><input id="voice-command" value={voice_command} placeholder="read page" onChange={lambda (e: ChangeEvent) { voice_command = e.target.value; }} /><button className="secondary-button" onClick={run_voice_command}>Send command</button></div>
                    <p className="command-list" role="status" aria-live="polite">{voice_command_shape}</p>
                    <p className="command-list">Allowed: new tab · close tab · switch tab · back · forward · reload · scroll · zoom · search · read page · stop reading</p>
                    <p className="context-note">Voice input is unavailable until a provider is connected. This development adapter sends only the constrained BrowserCommand shape through the typed bridge.</p>
                </div>}
                {not development_adapter_enabled and <p className="context-note">Voice input is unavailable, and the development text adapter is disabled outside development mode.</p>}
            </section>
        </div>

        <footer className="footer-note">Page content is used for the live snapshot only. Approved preference rules are stored locally by Jac and scoped explicitly.</footer>
    </main>
}
