"""Development-only deterministic data using the production Jac contracts."""

import from .core {
    AccessibilityProfile,
    AdaptationRequest,
    ElementSummary,
    PageSnapshot
}

def fixture_page() -> PageSnapshot {
    return PageSnapshot(
        snapshotId="snapshot_fixture",
        tabId="tab_fixture",
        pageRevision=1,
        url="https://example.com/article",
        origin="https://example.com",
        title="Accessible fixture article",
        viewport={"width": 1280, "height": 820},
        scroll={"x": 0, "y": 0},
        elements=[
            ElementSummary(elementId="heading_1", role="heading", accessibleName="Article heading"),
            ElementSummary(elementId="button_1", role="button", accessibleName="Continue"),
            ElementSummary(elementId="link_1", role="link", accessibleName="Read more")
        ],
        contentSummary="A bounded fixture page with a heading, a button, and a link."
    );
}

def fixture_request(userRequest: str, mode: str = "deterministic", profile: AccessibilityProfile = AccessibilityProfile()) -> AdaptationRequest {
    page = fixture_page();
    return AdaptationRequest(
        schemaVersion=1,
        requestId="request_fixture",
        tabId=page.tabId,
        pageRevision=page.pageRevision,
        userRequest=userRequest,
        activeProfile=profile,
        page=page,
        mode=mode
    );
}

def fixture_text_scale_request() -> AdaptationRequest {
    return fixture_request("Make the text larger.");
}

def fixture_readability_request() -> AdaptationRequest {
    return fixture_request("Make the text larger, add more spacing, use high contrast, and make the buttons easier to click.");
}
