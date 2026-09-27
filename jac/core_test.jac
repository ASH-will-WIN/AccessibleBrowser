"""Focused Jac-core verification for the Phase 1 service boundary."""

import from .core {
    AccessibilityProfile,
    AdaptationPlan,
    BrowserCommand,
    ElementSummary,
    PlanAction,
    validate_browser_command,
    validate_plan,
    explain_plan
}
import from .fixtures {
    fixture_page,
    fixture_readability_request,
    fixture_text_scale_request
}
import from .persistence {
    applicable_preferences,
    load_store,
    make_rule,
    new_store,
    save_preference
}
import from .provider { bounded_payload, create_adaptation_plan }

test "text scale request returns a valid allowlisted plan" {
    result = create_adaptation_plan(fixture_text_scale_request());
    assert result.ok;
    assert result.plan is not None;
    assert result.plan.actions[0].type == "set_text_scale";
    assert result.plan.actions[0].parameters["scale"] == 1.25;
}

test "combined readability request returns typed actions and explanation" {
    result = create_adaptation_plan(fixture_readability_request());
    assert result.ok;
    assert result.plan is not None;
    assert len(result.plan.actions) == 4;
    explanation = explain_plan(result.plan);
    assert explanation.reversible;
    assert len(explanation.affectedParts) == 4;
}

test "unknown model action is rejected before bridge handoff" {
    request = fixture_text_scale_request();
    invalid = AdaptationPlan(
        schemaVersion=1,
        planId="plan_invalid",
        requestId=request.requestId,
        tabId=request.tabId,
        pageRevision=request.pageRevision,
        summary="invalid",
        actions=[PlanAction(
            actionId="action_invalid",
            type="run_javascript",
            parameters={"code": "document.body"},
            reason="invalid",
            reversible=True
        )],
        confidence="low",
        warnings=[],
        suggestedScope="page",
        status="ready"
    );
    result = validate_plan(invalid, request);
    assert not result.ok;
    assert result.error is not None;
    assert result.error.code == "UNSUPPORTED_ACTION";
}

test "executable requests are rejected before planning" {
    request = fixture_text_scale_request();
    request.userRequest = "Run arbitrary JavaScript on the page";
    result = create_adaptation_plan(request);
    assert not result.ok;
    assert result.error is not None;
    assert result.error.code == "INVALID_PLAN";
}

test "scope precedence is global then website then page" {
    store = new_store("/tmp/accessible-browser-jac-precedence.json");
    save_preference(store, make_rule("textScale", 1.1, "global", "setup"), True);
    save_preference(store, make_rule("textScale", 1.25, "website", "voice", "https://example.com"), True);
    save_preference(store, make_rule("textScale", 1.5, "page", "manual", "https://example.com", "https://example.com/article"), True);
    rules = applicable_preferences(store, "https://example.com", "https://example.com/article");
    assert len(rules) == 1;
    assert rules[0].value == 1.5;
}

test "just for now and declined remember choices are not persisted" {
    store = new_store("/tmp/accessible-browser-jac-declined.json");
    temporary = make_rule("textScale", 1.25, "none", "voice");
    declined = save_preference(store, temporary, False);
    assert not declined.ok;
    assert len(store.rules) == 0;
}

test "approved preferences survive a local store reload" {
    path = "/tmp/accessible-browser-jac-reload.json";
    store = new_store(path);
    save_preference(store, make_rule("contrast", "high", "global", "manual"), True);
    reloaded = new_store(path);
    load_store(reloaded);
    assert len(reloaded.rules) == 1;
    assert reloaded.rules[0].setting == "contrast";
}

test "browser commands are constrained before forwarding" {
    command = BrowserCommand(
        schemaVersion=1,
        requestId="request_command",
        tabId="tab_fixture",
        kind="scroll",
        arguments={"deltaY": 10},
        requiresConfirmation=False
    );
    accepted = validate_browser_command(command);
    assert accepted.ok;
    command.arguments["deltaY"] = 5000;
    rejected = validate_browser_command(command);
    assert not rejected.ok;
    assert rejected.error is not None;
    assert rejected.error.code == "INVALID_PARAMETERS";
}

test "missing LLM configuration falls back to deterministic planning" {
    request = fixture_text_scale_request();
    request.mode = "llm";
    result = create_adaptation_plan(request);
    assert result.ok;
    assert result.plan is not None;
    assert result.plan.actions[0].type == "set_text_scale";
}

test "bounded model payload omits textbox values" {
    request = fixture_text_scale_request();
    request.page.elements.append(ElementSummary(
        elementId="password_1",
        role="textbox",
        accessibleName="Password",
        text="do-not-send"
    ));
    payload = bounded_payload(request);
    elements = payload["page"]["elements"] as list[dict[str, any]];
    assert elements[3]["text"] == "";
}

test "active profile can already represent no-op settings" {
    profile = AccessibilityProfile(textScale=1.25);
    request = fixture_text_scale_request();
    request.activeProfile = profile;
    result = create_adaptation_plan(request);
    assert result.ok;
    assert result.plan is not None;
    assert result.plan.status == "noOp";
}
