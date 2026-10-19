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
    // Folder mode adds the file sidebar and the export queue.
    property bool folderMode: false
    // In and out points set on each video this session, keyed by URL, so
    // moving between videos in a folder doesn't lose them.
    property var cuts: ({})
    readonly property bool busy: job.running || exportQueue.running

    width: 1280
    height: 800
    minimumWidth: 900
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

    // Opens a file or a folder, from the command line or a drop.
    function openPath(url) {
        if (folderModel.isFolder(url))
            openFolder(url)
        else
            openVideo(url)
    }

    function openVideo(url) {
        if (job.running)
            return
        folderMode = false
        job.reset()
        player.source = url
    }

    function openFolder(url) {
        folderModel.folder = url
        folderMode = true
        player.source = folderModel.count > 0 ? folderModel.urlAt(0) : ""
    }

    function selectVideo(url) {
        if (String(url) !== String(player.source))
            player.source = url
    }

    function stepVideo(delta) {
        const next = folderModel.indexOf(player.source) + delta
        if (next >= 0 && next < folderModel.count)
            player.source = folderModel.urlAt(next)
    }

    function rememberCut() {
        if (player.loaded && player.duration > 0)
            cuts[String(player.source)] = { inPoint: inPoint, outPoint: outPoint }
    }

    function setIn() { inPoint = Math.min(player.position, outPoint - scrubber.minimumLength); rememberCut() }
    function setOut() { outPoint = Math.max(player.position, inPoint + scrubber.minimumLength); rememberCut() }

    function nudge(delta) {
        player.seek(Math.max(0, Math.min(player.duration, player.position + delta)), true)
    }

    function addToQueue() {
        if (!folderMode || !player.loaded)
            return
        rememberCut()
        exportQueue.add(player.source, inPoint, outPoint, modeBox.currentValue)
        if (autoAdvance.checked)
            stepVideo(1)
    }

    Component.onCompleted: if (initialSource.toString() !== "") openPath(initialSource)

    Connections {
        target: player
        function onDurationChanged() {
            if (player.duration <= 0)
                return
            // Restore this video's cut: what was set here, else what's queued.
            const saved = window.cuts[String(player.source)]
            const queued = exportQueue.jobFor(player.source)
            if (saved) {
                window.inPoint = saved.inPoint
                window.outPoint = saved.outPoint
            } else if (queued) {
                window.inPoint = queued.inPoint
                window.outPoint = queued.outPoint
            } else {
                window.inPoint = 0
                window.outPoint = player.duration
            }
            if (saved || queued)
                player.seek(window.inPoint, true)
        }
    }

    FileDialog {
        id: openDialog
        title: "Open video"
        nameFilters: ["Videos (*.mp4 *.mkv *.mov *.avi *.webm *.m4v *.ts *.mts *.m2ts *.flv *.wmv *.mpg *.mpeg *.3gp *.ogv)", "All files (*)"]
        onAccepted: window.openVideo(selectedFile)
    }

    FolderDialog {
        id: folderDialog
        title: "Open folder"
        onAccepted: window.openFolder(selectedFolder)
    }

    Settings {
        id: appSettings
        onFfmpegPathChanged: encoderProbe.probe()
    }

    EncoderProbe {
        id: encoderProbe
        Component.onCompleted: encoderProbe.probe()
    }

    TrimJob {
        id: job
    }

    ExportQueue {
        id: exportQueue
        settings: appSettings
        maxConcurrent: appSettings.maxConcurrent
    }

    SettingsDialog {
        id: settingsDialog
        settings: appSettings
        probe: encoderProbe
    }

    VideoFolderModel {
        id: folderModel
        queue: exportQueue
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
    Shortcut { sequence: "Q"; enabled: window.folderMode; onActivated: window.addToQueue() }
    Shortcut { sequence: "Up"; enabled: window.folderMode; onActivated: window.stepVideo(-1) }
    Shortcut { sequence: "Down"; enabled: window.folderMode; onActivated: window.stepVideo(1) }
    Shortcut { sequence: StandardKey.Open; enabled: !window.busy; onActivated: openDialog.open() }
    Shortcut { sequence: "Ctrl+Shift+O"; enabled: !window.busy; onActivated: folderDialog.open() }
    Shortcut { sequence: StandardKey.Preferences; onActivated: settingsDialog.open() }
    Shortcut { sequence: "Ctrl+,"; onActivated: settingsDialog.open() }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Button {
                text: "Open video…"
                enabled: !window.busy
                onClicked: openDialog.open()
            }
            Button {
                text: "Open folder…"
                enabled: !window.busy
                onClicked: folderDialog.open()
            }
            Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                text: player.loaded ? window.fileName(player.source) : ""
                opacity: 0.8
            }
            Label {
                text: "Space play · I/O in/out · ←/→ frame · Shift+←/→ 5 s · [ ] jump"
                      + (window.folderMode ? " · Q queue · ↑/↓ video" : "")
                opacity: 0.5
                font.pixelSize: 11
            }
            Button {
                text: "Settings…"
                onClicked: settingsDialog.open()
            }
        }
    }

    // FFmpeg is needed for every trim, so say so up front when it's missing.
    Rectangle {
        id: ffmpegBanner
        z: 10
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? 40 : 0
        visible: !encoderProbe.probing && !encoderProbe.ffmpegFound
        color: "#5c2b2b"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Label {
                Layout.fillWidth: true
                text: appSettings.ffmpegPath !== ""
                      ? "The FFmpeg program chosen in Settings doesn't work. Trimming won't work until it's fixed."
                      : "FFmpeg wasn't found, so trimming won't work. Install FFmpeg, or choose where it is in Settings."
                elide: Text.ElideRight
            }
            Button {
                text: "Settings…"
                onClicked: settingsDialog.open()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: ffmpegBanner.height
        spacing: 0

        FileSidebar {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            visible: window.folderMode
            folderModel: folderModel
            currentUrl: player.source
            onVideoSelected: (url) => window.selectVideo(url)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                    text: player.errorString !== "" ? "Could not open this file: " + player.errorString
                        : window.folderMode && folderModel.count === 0 ? "This folder has no videos"
                        : "Open a video or a folder, or drop one here"
                    font.pixelSize: 18
                    opacity: 0.6
                }

                DropArea {
                    anchors.fill: parent
                    enabled: !window.busy
                    onDropped: (drop) => { if (drop.hasUrls) window.openPath(drop.urls[0]) }
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
                onInPointMoved: (time) => { window.inPoint = time; window.rememberCut() }
                onOutPointMoved: (time) => { window.outPoint = time; window.rememberCut() }
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
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Layout.bottomMargin: 10
                spacing: 10

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
                                  : "Re-encodes so the cut lands on the exact frame. Slower. The encoder and quality are set in Settings."
                }

                // Single-video mode: trim right away, with the result shown here.
                ProgressBar {
                    Layout.preferredWidth: 160
                    value: job.progress
                    visible: !window.folderMode && job.running
                }
                Label {
                    Layout.fillWidth: true
                    visible: !window.folderMode
                    elide: Text.ElideMiddle
                    ToolTip.visible: job.state === TrimJob.Failed && errorHover.hovered && job.errorDetails !== ""
                    ToolTip.text: job.errorDetails
                    HoverHandler { id: errorHover }
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
                    visible: !window.folderMode && job.state === TrimJob.Finished
                    onClicked: Qt.openUrlExternally(job.outputFolderUrl())
                }
                Button {
                    visible: !window.folderMode
                    enabled: player.loaded
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
                        job.applySettings(appSettings)
                        job.start()
                    }
                }

                // Folder mode: queue this video's cut and move on.
                Item {
                    Layout.fillWidth: true
                    visible: window.folderMode
                }
                CheckBox {
                    id: autoAdvance
                    visible: window.folderMode
                    checked: true
                    text: "Then go to next video"
                }
                Button {
                    visible: window.folderMode
                    enabled: player.loaded
                    highlighted: true
                    text: {
                        const queued = exportQueue.jobFor(player.source)
                        return queued && queued.state === TrimJob.Idle ? "Update queue (Q)" : "Add to queue (Q)"
                    }
                    onClicked: window.addToQueue()
                }
            }
        }

        QueuePanel {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            visible: window.folderMode
            queue: exportQueue
            formatTime: window.formatTime
            onJobActivated: (source) => window.selectVideo(source)
        }
    }
}
