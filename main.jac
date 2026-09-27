"""AccessibleBrowser Jac application entrypoint."""

import from .frontend { app as ClientApp }
import from .jac.api {
    create_adaptation_plan,
    create_adaptation_request,
    explain_adaptation_plan,
    forward_browser_command,
    get_active_profile,
    get_applicable_preferences,
    propose_persistence,
    record_apply_result,
    save_approved_preference,
    update_active_profile
}

def:pub app -> JsxElement {
    <ClientApp/>
}
