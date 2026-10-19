pragma Singleton
import QtQuick

// Colours, sizes and formatting shared by every view.
QtObject {
    readonly property color background: "#000000"
    readonly property color surface: "#111113"
    readonly property color surfaceRaised: "#1b1b1f"
    readonly property color hover: "#26262b"
    readonly property color border: "#2a2a30"
    readonly property color text: "#ececef"
    readonly property color textDim: "#a0a0a8"
    readonly property color textFaint: "#66666e"
    readonly property color accent: "#2d8cff"
    readonly property color success: "#3fb950"
    readonly property color warning: "#e3a52f"
    readonly property color danger: "#ff5c5c"
    readonly property color videoClip: "#24467e"
    readonly property color audioClip: "#0f3a24"
    readonly property color waveform: "#3ddc84"
    readonly property int radius: 6
    readonly property string mono: Qt.platform.os === "windows" ? "Consolas"
                                  : Qt.platform.os === "osx" ? "Menlo" : "monospace"

    // Seconds as HH:MM:SS:FF when the frame rate is known, else HH:MM:SS.mmm.
    function timecode(t, fps) {
        if (!(t >= 0))
            t = 0
        const pad = (n, w) => String(n).padStart(w || 2, "0")
        const whole = Math.floor(t + 1e-6)
        const hms = pad(Math.floor(whole / 3600)) + ":" + pad(Math.floor(whole / 60) % 60) + ":" + pad(whole % 60)
        if (fps > 0) {
            const frame = Math.min(Math.round(fps) - 1, Math.floor((t - whole) * fps + 1e-6))
            return hms + ":" + pad(Math.max(0, frame))
        }
        return hms + "." + pad(Math.floor((t - whole) * 1000 + 1e-6), 3)
    }

    // Short form for ruler labels.
    function rulerLabel(t) {
        const pad = n => String(n).padStart(2, "0")
        const s = Math.round(t)
        return pad(Math.floor(s / 3600)) + ":" + pad(Math.floor(s / 60) % 60) + ":" + pad(s % 60)
    }
}
