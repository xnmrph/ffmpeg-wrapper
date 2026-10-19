import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Trimmer

ApplicationWindow {
    id: window

    property url initialSource
    property real inPoint: 0
    property real outPoint: 0

    width: 1280
    height: 800
    minimumWidth: 800
    minimumHeight: 520
    visible: true
    title: player.loaded ? fileName(player.source) + " - Video Trimmer" : "Video Trimmer"
    color: palette.window

    palette {
        window: "#2b2d31"
        windowText: "#e6e6e6"
        base: "#1e1f22"
        alternateBase: "#2b2d31"
        text: "#e6e6e6"
        button: "#3a3c41"
        buttonText: "#e6e6e6"
        highlight: "#3d8bfd"
        highlightedText: "white"
        toolTipBase: "#1e1f22"
        toolTipText: "#e6e6e6"
        placeholderText: "#8a8a8a"
        mid: "#45474c"
        dark: "#1a1b1e"
        light: "#4a4c52"
        midlight: "#3f4146"
        shadow: "#000000"
        disabled.text: "#707070"
        disabled.buttonText: "#707070"
        disabled.windowText: "#707070"
    }

    function fileName(url) {
        const s = decodeURIComponent(url.toString())
        return s.substring(s.lastIndexOf("/") + 1)
    }

    function formatTime(t) {
        if (!(t >= 0))
            t = 0
        const ms = Math.round(t * 1000)
        const h = Math.floor(ms / 3600000)
        const m = Math.floor(ms / 60000) % 60
        const s = Math.floor(ms / 1000) % 60
        const pad = (n, w) => String(n).padStart(w, "0")
        return (h > 0 ? h + ":" : "") + pad(m, 2) + ":" + pad(s, 2) + "." + pad(ms % 1000, 3)
    }

    function openVideo(url) {
        if (job.running)
            return
        job.output = ""
        player.source = url
    }

    function setIn() { inPoint = Math.min(player.position, outPoint - scrubber.minimumLength) }
    function setOut() { outPoint = Math.max(player.position, inPoint + scrubber.minimumLength) }

    function nudge(delta) {
        player.seek(Math.max(0, Math.min(player.duration, player.position + delta)), true)
    }

    Component.onCompleted: if (initialSource.toString() !== "") openVideo(initialSource)

    Connections {
        target: player
        function onDurationChanged() {
            window.inPoint = 0
            window.outPoint = player.duration
        }
    }

    FileDialog {
        id: openDialog
        title: "Open video"
        nameFilters: ["Videos (*.mp4 *.mkv *.mov *.avi *.webm *.m4v *.ts *.mts *.m2ts *.flv *.wmv *.mpg *.mpeg)", "All files (*)"]
        onAccepted: window.openVideo(selectedFile)
    }

    TrimJob {
        id: job
    }

    Shortcut { sequence: "Space"; onActivated: player.togglePause() }
    Shortcut { sequence: "I"; onActivated: window.setIn() }
    Shortcut { sequence: "O"; onActivated: window.setOut() }
    Shortcut { sequence: "Left"; onActivated: player.frameBackStep() }
    Shortcut { sequence: "Right"; onActivated: player.frameStep() }
    Shortcut { sequence: "Shift+Left"; onActivated: window.nudge(-5) }
    Shortcut { sequence: "Shift+Right"; onActivated: window.nudge(5) }
    Shortcut { sequence: "["; onActivated: player.seek(window.inPoint, true) }
    Shortcut { sequence: "]"; onActivated: player.seek(window.outPoint, true) }
    Shortcut { sequence: StandardKey.Open; onActivated: openDialog.open() }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Button {
                text: "Open video…"
                enabled: !job.running
                onClicked: openDialog.open()
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                text: player.loaded ? window.fileName(player.source) : ""
                opacity: 0.8
            }
            Label {
                text: "Space play · I/O set in/out · ←/→ frame · Shift+←/→ 5 s · [ ] jump to in/out"
                opacity: 0.5
                font.pixelSize: 11
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "black"

            MpvItem {
                id: player
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                enabled: player.loaded
                onClicked: player.togglePause()
            }

            Label {
                anchors.centerIn: parent
                visible: !player.loaded
                horizontalAlignment: Text.AlignHCenter
                text: player.errorString !== ""
                      ? "Could not open this file: " + player.errorString
                      : "Open a video, or drop one here"
                font.pixelSize: 18
                opacity: 0.6
            }

            DropArea {
                anchors.fill: parent
                onDropped: (drop) => { if (drop.hasUrls) window.openVideo(drop.urls[0]) }
            }
        }

        Scrubber {
            id: scrubber
            Layout.fillWidth: true
            Layout.topMargin: 6
            duration: player.duration
            position: player.position
            inPoint: window.inPoint
            outPoint: window.outPoint
            onSeekRequested: (time, exact) => player.seek(time, exact)
            onInPointMoved: (time) => window.inPoint = time
            onOutPointMoved: (time) => window.outPoint = time
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 6
            spacing: 10
            enabled: player.loaded

            Button {
                text: player.paused ? "Play" : "Pause"
                Layout.preferredWidth: 72
                onClicked: player.togglePause()
            }
            Label {
                text: window.formatTime(player.position) + " / " + window.formatTime(player.duration)
                font.family: "monospace"
            }

            Item { Layout.fillWidth: true }

            Button { text: "Set in"; onClicked: window.setIn() }
            Label {
                text: window.formatTime(window.inPoint)
                font.family: "monospace"
            }
            Label { text: "→"; opacity: 0.6 }
            Label {
                text: window.formatTime(window.outPoint)
                font.family: "monospace"
            }
            Button { text: "Set out"; onClicked: window.setOut() }
            Label {
                text: "(" + window.formatTime(window.outPoint - window.inPoint) + ")"
                font.family: "monospace"
                opacity: 0.7
            }

            Item { Layout.fillWidth: true }

            ComboBox {
                id: modeBox
                Layout.preferredWidth: 220
                enabled: !job.running
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "Fast (lossless, keyframes)", value: TrimJob.Fast },
                    { text: "Accurate (re-encode)", value: TrimJob.Accurate }
                ]
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: currentValue === TrimJob.Fast
                              ? "Copies the streams without re-encoding. Very quick and lossless, but the start snaps to the nearest earlier keyframe."
                              : "Re-encodes to H.264/AAC so the cut lands on the exact frame. Slower."
            }
            Button {
                text: job.running ? "Cancel" : "Trim"
                highlighted: !job.running
                Layout.preferredWidth: 90
                onClicked: {
                    if (job.running) {
                        job.cancel()
                        return
                    }
                    job.source = player.source
                    job.inPoint = window.inPoint
                    job.outPoint = window.outPoint
                    job.mode = modeBox.currentValue
                    job.output = ""
                    job.start()
                }
            }
        }

        // Status of the last trim.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 10
            Layout.preferredHeight: 28
            spacing: 10
            visible: job.state !== TrimJob.Idle

            ProgressBar {
                Layout.preferredWidth: 220
                value: job.progress
                visible: job.running
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                color: job.state === TrimJob.Failed ? "#ff6b6b" : palette.windowText
                text: {
                    switch (job.state) {
                    case TrimJob.Running: return "Trimming… " + Math.round(job.progress * 100) + "%"
                    case TrimJob.Finished: return "Saved " + job.output
                    case TrimJob.Failed: return "Trim failed: " + job.errorString
                    case TrimJob.Cancelled: return "Trim cancelled"
                    }
                    return ""
                }
            }
            Button {
                text: "Show in folder"
                visible: job.state === TrimJob.Finished
                onClicked: Qt.openUrlExternally(job.outputFolderUrl())
            }
        }
    }
}
