import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Layouts
import Trimmer

ApplicationWindow {
    id: window

    property url initialSource
    property real inPoint: 0
    property real outPoint: 0
    property int trimMode: TrimJob.Fast
    // Folder mode adds the file sidebar and the export queue.
    property bool folderMode: false
    // In and out points set on each video this session, keyed by URL, so
    // moving between videos in a folder doesn't lose them.
    property var cuts: ({})
    readonly property bool busy: job.running || exportQueue.running
    readonly property real minimumLength: 0.04

    width: 1440
    height: 900
    minimumWidth: 960
    minimumHeight: 600
    visible: true
    title: player.loaded ? fileName(player.source) + " - mxCut" : "mxCut"
    color: Theme.background

    Material.theme: Material.Dark
    Material.accent: Theme.accent
    Material.primary: Theme.accent
    Material.background: Theme.surfaceRaised
    Material.foreground: Theme.text
    // Material shouts button labels in capitals; keep them as written.
    font.capitalization: Font.MixedCase

    function fileName(url) {
        const s = decodeURIComponent(url.toString())
        return s.substring(s.lastIndexOf("/") + 1)
    }

    function timecode(t) { return Theme.timecode(t, player.fps) }

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

    // A trim is about to take the place of this video, so close it if it is
    // showing; reopenFile shows whatever is there afterwards.
    property url releasedSource
    function releaseFile(source) {
        if (String(player.source) !== String(source))
            return
        releasedSource = source
        player.source = ""
    }
    // Videos whose file was replaced by a trim, so their old cut no longer fits.
    property var replacedFiles: ({})
    function reopenFile(source, current, replaced) {
        if (replaced) {
            delete cuts[String(source)]
            replacedFiles[String(current)] = true
        }
        if (String(releasedSource) !== String(source))
            return
        releasedSource = ""
        player.source = current
    }

    function rememberCut() {
        if (player.loaded && player.duration > 0)
            cuts[String(player.source)] = { inPoint: inPoint, outPoint: outPoint }
    }

    function setIn() { inPoint = Math.min(player.position, outPoint - minimumLength); rememberCut() }
    function setOut() { outPoint = Math.max(player.position, inPoint + minimumLength); rememberCut() }

    function nudge(delta) {
        player.seek(Math.max(0, Math.min(player.duration, player.position + delta)), true)
    }

    function addToQueue() {
        if (!folderMode || !player.loaded)
            return
        rememberCut()
        exportQueue.add(player.source, inPoint, outPoint, trimMode)
        if (autoAdvance.checked)
            stepVideo(1)
    }

    function trimNow() {
        if (job.running) {
            job.cancel()
            return
        }
        job.source = player.source
        job.inPoint = inPoint
        job.outPoint = outPoint
        job.mode = trimMode
        job.output = ""
        job.applySettings(appSettings)
        job.start()
    }

    Component.onCompleted: if (initialSource.toString() !== "") openPath(initialSource)

    Connections {
        target: player
        function onDurationChanged() {
            if (player.duration <= 0)
                return
            // Restore this video's cut: what was set here, else what's queued.
            const fresh = window.replacedFiles[String(player.source)] === true
            delete window.replacedFiles[String(player.source)]
            const saved = fresh ? undefined : window.cuts[String(player.source)]
            const queued = fresh ? null : exportQueue.jobFor(player.source)
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
        onAboutToReplace: (source) => window.releaseFile(source)
        onReplaceFinished: (source, current, replaced) => window.reopenFile(source, current, replaced)
    }

    ExportQueue {
        id: exportQueue
        settings: appSettings
        maxConcurrent: appSettings.maxConcurrent
        onAboutToReplace: (source) => window.releaseFile(source)
        onReplaceFinished: (source, current, replaced) => window.reopenFile(source, current, replaced)
    }

    MediaPreview {
        id: preview
        source: player.loaded ? player.source : ""
        duration: player.duration
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
    Shortcut { sequence: appSettings.inKey; onActivated: window.setIn() }
    Shortcut { sequence: appSettings.outKey; onActivated: window.setOut() }
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

    header: Rectangle {
        implicitHeight: 48
        color: "#0b0b0d"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            spacing: 6

            Image {
                source: "qrc:/packaging/branding/logo.png"
                sourceSize.height: 48
                Layout.preferredHeight: 24
                Layout.preferredWidth: 24 * implicitWidth / implicitHeight
                Layout.rightMargin: 18
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            IconButton {
                text: "Open video"
                iconPath: Icons.movie
                tip: "Open one video (Ctrl+O)"
                enabled: !window.busy
                onClicked: openDialog.open()
            }
            IconButton {
                text: "Open folder"
                iconPath: Icons.folder
                tip: "Trim a folder of videos as a batch (Ctrl+Shift+O)"
                enabled: !window.busy
                onClicked: folderDialog.open()
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                text: player.loaded ? window.fileName(player.source) : ""
                color: Theme.textDim
                font.pixelSize: 13
            }
            IconButton {
                iconPath: Icons.keyboard
                tip: "Space  play / pause\n" + appSettings.inKey + " / " + appSettings.outKey + "  set in / out\n"
                     + "← / →  previous / next frame\n"
                     + "Shift + ← / →  jump 5 seconds\n[ / ]  go to in / out\n"
                     + "Q  add to queue (folder)\n↑ / ↓  previous / next video (folder)\nCtrl + ,  settings"
            }
            IconButton {
                iconPath: Icons.settings
                tip: "Settings (Ctrl+,)"
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
        color: "#3a1517"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 10
            Text {
                Layout.fillWidth: true
                text: appSettings.ffmpegPath !== ""
                      ? "The FFmpeg program chosen in Settings doesn't work. Trimming won't work until it's fixed."
                      : "FFmpeg wasn't found, so trimming won't work. Install FFmpeg, or choose where it is in Settings."
                color: "#ffb4b4"
                elide: Text.ElideRight
                font.pixelSize: 13
            }
            IconButton {
                text: "Settings"
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

            // Program monitor
            Item {
                id: monitor
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    id: picture
                    anchors.fill: parent
                    anchors.margins: 18

                    MpvItem {
                        id: player
                        anchors.fill: parent
                    }

                    // Outline around the picture itself, so black bars inside
                    // the video stand out from the empty space around it.
                    Rectangle {
                        readonly property real fit: player.videoWidth > 0 && player.videoHeight > 0
                            ? Math.min(picture.width / player.videoWidth, picture.height / player.videoHeight) : 0
                        readonly property real w: player.videoWidth * fit
                        readonly property real h: player.videoHeight * fit
                        visible: player.loaded && fit > 0 && outlineButton.checked
                        x: Math.floor((picture.width - w) / 2) - 1
                        y: Math.floor((picture.height - h) / 2) - 1
                        width: Math.ceil(w) + 2
                        height: Math.ceil(h) + 2
                        color: "transparent"
                        border.color: "white"
                        border.width: 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: player.loaded
                    onClicked: player.togglePause()
                }

                Column {
                    anchors.centerIn: parent
                    visible: !player.loaded
                    spacing: 14

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        path: Icons.movie
                        size: 48
                        color: Theme.textFaint
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: player.errorString !== "" ? "Could not open this file: " + player.errorString
                            : window.folderMode && folderModel.count === 0 ? "This folder has no videos"
                            : "Open a video or a folder, or drop one here"
                        color: Theme.textDim
                        font.pixelSize: 16
                    }
                }

                DropArea {
                    anchors.fill: parent
                    enabled: !window.busy
                    onDropped: (drop) => { if (drop.hasUrls) window.openPath(drop.urls[0]) }
                }
            }

            // Transport bar, as under a program monitor.
            Item {
                Layout.fillWidth: true
                implicitHeight: 48

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: window.timecode(timeline.shownPosition)
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 18
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    enabled: player.loaded

                    IconButton { iconPath: Icons.markIn; tip: "Set in point (" + appSettings.inKey + ")"; onClicked: window.setIn() }
                    IconButton { iconPath: Icons.markOut; tip: "Set out point (" + appSettings.outKey + ")"; onClicked: window.setOut() }
                    Item { width: 12; height: 1 }
                    IconButton { iconPath: Icons.goToIn; tip: "Go to in point ([)"; onClicked: player.seek(window.inPoint, true) }
                    IconButton { iconPath: Icons.stepBack; tip: "Previous frame (←)"; onClicked: player.frameBackStep() }
                    IconButton {
                        iconPath: player.paused ? Icons.play : Icons.pause
                        iconSize: 24
                        implicitWidth: 44
                        tip: "Play / pause (Space)"
                        onClicked: player.togglePause()
                    }
                    IconButton { iconPath: Icons.stepForward; tip: "Next frame (→)"; onClicked: player.frameStep() }
                    IconButton { iconPath: Icons.goToOut; tip: "Go to out point (])"; onClicked: player.seek(window.outPoint, true) }
                    Item { width: 12; height: 1 }
                    IconButton {
                        id: outlineButton
                        iconPath: Icons.frame
                        checkable: true
                        checked: true
                        tip: "Outline the picture, to spot black bars"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: window.timecode(player.duration)
                    color: Theme.textDim
                    font.family: Theme.mono
                    font.pixelSize: 14
                }
            }

            Timeline {
                id: timeline
                Layout.fillWidth: true
                duration: player.duration
                position: player.position
                inPoint: window.inPoint
                outPoint: window.outPoint
                fps: player.fps
                clipName: player.loaded ? window.fileName(player.source) : ""
                thumbnails: preview.thumbnails
                peaks: preview.peaks
                aspect: player.videoHeight > 0 ? player.videoWidth / player.videoHeight : 16 / 9
                minimumLength: window.minimumLength
                onSeekRequested: (time, exact) => player.seek(time, exact)
                onInPointMoved: (time) => { window.inPoint = time; window.rememberCut() }
                onOutPointMoved: (time) => { window.outPoint = time; window.rememberCut() }
            }

            // Action bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 60
                color: Theme.surface

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 14
                    enabled: player.loaded

                    component Readout: Column {
                        property string label
                        property string value
                        property color valueColor: Theme.text
                        spacing: 1
                        Text { text: parent.label; color: Theme.textFaint; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
                        Text { text: parent.value; color: parent.valueColor; font.family: Theme.mono; font.pixelSize: 14 }
                    }

                    Readout { label: "IN"; value: window.timecode(window.inPoint) }
                    Readout { label: "OUT"; value: window.timecode(window.outPoint) }
                    Readout { label: "DURATION"; value: window.timecode(window.outPoint - window.inPoint); valueColor: Theme.accent }

                    Item { Layout.fillWidth: true }

                    // Segmented Fast / Accurate switch.
                    Rectangle {
                        implicitWidth: modes.implicitWidth + 6
                        implicitHeight: 34
                        radius: Theme.radius + 2
                        color: Theme.background
                        border.color: Theme.border

                        Row {
                            id: modes
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: [
                                    { mode: TrimJob.Fast, text: "Fast",
                                      tip: "Copies the streams without re-encoding. Very quick and lossless, but the start snaps to the nearest earlier keyframe." },
                                    { mode: TrimJob.Accurate, text: "Accurate",
                                      tip: "Re-encodes so the cut lands on the exact frame. Slower. The encoder and quality are set in Settings." }
                                ]
                                delegate: IconButton {
                                    required property var modelData
                                    text: modelData.text
                                    tip: modelData.tip
                                    implicitHeight: 28
                                    implicitWidth: 80
                                    enabled: !job.running
                                    primary: window.trimMode === modelData.mode
                                    onClicked: window.trimMode = modelData.mode
                                }
                            }
                        }
                    }

                    // Single-video mode: trim right away, with the result shown here.
                    ColumnLayout {
                        visible: !window.folderMode && job.state !== TrimJob.Idle
                        Layout.maximumWidth: 360
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            font.pixelSize: 12
                            color: job.state === TrimJob.Failed ? Theme.danger
                                 : job.state === TrimJob.Finished ? Theme.success : Theme.textDim
                            text: {
                                switch (job.state) {
                                case TrimJob.Running: return "Trimming… " + Math.round(job.progress * 100) + "%"
                                case TrimJob.Finished: return "Saved " + job.output
                                case TrimJob.Failed: return "Trim failed: " + job.errorString
                                case TrimJob.Cancelled: return "Trim cancelled"
                                }
                                return ""
                            }
                            ToolTip.visible: statusHover.hovered && (job.state === TrimJob.Failed ? job.errorDetails !== "" : job.state === TrimJob.Finished)
                            ToolTip.text: job.state === TrimJob.Failed ? job.errorDetails : job.output
                            HoverHandler { id: statusHover }
                        }
                        Rectangle {
                            visible: job.running
                            Layout.fillWidth: true
                            implicitHeight: 3
                            radius: 2
                            color: Theme.hover
                            Rectangle {
                                width: parent.width * job.progress
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }
                    }
                    IconButton {
                        text: "Show in folder"
                        iconPath: Icons.openFolder
                        visible: !window.folderMode && job.state === TrimJob.Finished
                        onClicked: Qt.openUrlExternally(job.outputFolderUrl())
                    }
                    IconButton {
                        visible: !window.folderMode
                        primary: !job.running
                        iconPath: job.running ? Icons.close : Icons.cut
                        text: job.running ? "Cancel" : "Trim"
                        implicitHeight: 36
                        implicitWidth: 110
                        onClicked: window.trimNow()
                    }

                    // Folder mode: queue this video's cut and move on.
                    CheckBox {
                        id: autoAdvance
                        visible: window.folderMode
                        checked: true
                        text: "Then next"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Go to the next video after adding this one"
                    }
                    IconButton {
                        visible: window.folderMode
                        primary: true
                        iconPath: Icons.queueAdd
                        implicitHeight: 36
                        tip: "Q"
                        text: {
                            const queued = exportQueue.jobFor(player.source)
                            return queued && queued.state === TrimJob.Idle ? "Update queue" : "Add to queue"
                        }
                        onClicked: window.addToQueue()
                    }
                }
            }
        }

        QueuePanel {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            visible: window.folderMode
            queue: exportQueue
            formatTime: window.timecode
            onJobActivated: (source) => window.selectVideo(source)
        }
    }
}
