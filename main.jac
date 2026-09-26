"""AccessibleBrowser Jac application entrypoint."""

import from .frontend { app as ClientApp }

def:pub app -> JsxElement {
    <ClientApp/>
}
