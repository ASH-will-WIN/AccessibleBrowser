"""Phase 0 placeholder for the Jac-owned product UI."""

def:pub app -> JsxElement {
    <main
        style={{
            "fontFamily": "system-ui, sans-serif",
            "maxWidth": "720px",
            "margin": "4rem auto",
            "padding": "0 2rem",
            "color": "#18202a"
        }}
    >
        <h1>AccessibleBrowser Jac layer</h1>
        <p>
            The Jac product layer is ready for Phase 1 accessibility features.
        </p>
        <div id="bridge-status" data-bridge-status="true">
            Waiting for the Electron bridge...
        </div>
    </main>
}
