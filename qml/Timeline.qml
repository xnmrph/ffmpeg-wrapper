import QtQuick
import QtQuick.Shapes
import MxCut

// Premiere-style timeline: a time ruler, a video track of thumbnails and an
// audio track with the waveform, with the kept segments, their handles and the
// playhead drawn across all three. It only reports what the user did; the
// owner decides how to seek and where to keep the points.
Rectangle {
    id: root

    property real duration: 0
    property real position: 0
    // The parts to keep, as {inPoint, outPoint}, each drawn in its own colour;
    // activeSegment is the one the in/out keys change.
    property var segments: []
    property int activeSegment: 0
    property real fps: 0
    property string clipName
    property var thumbnails: []
    // Width / height of the picture, so thumbnail tiles keep its shape.
    property real aspect: 16 / 9
    property var peaks: []
    property real minimumLength: 0.04

    signal seekRequested(real time, bool exact)
    signal segmentMoved(int index, real inPoint, real outPoint)
    signal segmentSelected(int index)

    // Where the user is scrubbing to, or -1. The playhead follows the mouse
    // until the player has caught up, so it never jumps ahead to a keyframe.
    property real scrubTime: -1
    readonly property real shownPosition: scrubTime >= 0 ? scrubTime : position

    function scrubTo(t, exact) {
        scrubTime = t
        settleTimer.stop()
        root.seekRequested(t, exact)
    }
    function endScrub(t) {
        root.seekRequested(t, true)
        settleTimer.restart()
    }

    onPositionChanged: if (scrubTime >= 0 && settleTimer.running && Math.abs(position - scrubTime) < 0.05)
                           settleTimer.triggered()

    Timer {
        id: settleTimer
        interval: 800
        onTriggered: { stop(); root.scrubTime = -1 }
    }

    readonly property int headerWidth: 46
    readonly property int rulerHeight: 28
    readonly property int videoHeight: 66
    readonly property int audioHeight: 54
    readonly property int gap: 3

    implicitHeight: rulerHeight + videoHeight + audioHeight + gap * 2 + 14
    color: Theme.surface
    enabled: duration > 0

    function xFor(t) { return duration > 0 ? t / duration * lane.width : 0 }
    function timeAt(x) { return duration > 0 ? Math.max(0, Math.min(duration, x / lane.width * duration)) : 0 }

    // Ruler spacing: the smallest step that leaves room for a label.
    readonly property real majorStep: {
        const steps = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200]
        for (const s of steps) {
            if (duration <= 0 || lane.width * s / duration >= 96)
                return s
        }
        return 7200
    }

    // Track headers, like V1 and A1 in an editor.
    component TrackHeader: Rectangle {
        property alias label: labelText.text
        property color tint
        width: root.headerWidth - 8
        radius: 4
        color: Qt.darker(tint, 1.6)
        border.color: Qt.darker(tint, 1.1)
        Text {
            id: labelText
            anchors.centerIn: parent
            color: Theme.text
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    TrackHeader {
        x: 4
        y: root.rulerHeight + root.gap
        height: root.videoHeight
        label: "V1"
        tint: Theme.videoClip
    }
    TrackHeader {
        x: 4
        y: root.rulerHeight + root.gap * 2 + root.videoHeight
        height: root.audioHeight
        label: "A1"
        tint: "#1f7a46"
    }

    Item {
        id: lane
        x: root.headerWidth
        width: root.width - root.headerWidth - 14
        height: parent.height

        // Ruler
        Item {
            id: ruler
            width: parent.width
            height: root.rulerHeight
            clip: true

            // Each segment's range on the ruler.
            Repeater {
                model: root.segments
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    x: root.xFor(modelData.inPoint)
                    width: Math.max(0, root.xFor(modelData.outPoint) - x)
                    anchors.bottom: parent.bottom
                    height: 6
                    color: root.segments.length > 1 ? Theme.segmentColor(index) : Theme.accent
                    opacity: index === root.activeSegment ? 0.7 : 0.4
                }
            }

            Repeater {
                model: root.duration > 0 ? Math.floor(root.duration / root.majorStep * 5) + 1 : 0
                delegate: Rectangle {
                    required property int index
                    readonly property bool major: index % 5 === 0
                    x: root.xFor(index * root.majorStep / 5)
                    y: major ? 12 : 20
                    width: 1
                    height: root.rulerHeight - y
                    color: major ? Theme.textDim : Theme.textFaint
                }
            }
            Repeater {
                model: root.duration > 0 ? Math.floor(root.duration / root.majorStep) + 1 : 0
                delegate: Text {
                    required property int index
                    x: root.xFor(index * root.majorStep) + 4
                    y: 2
                    text: Theme.rulerLabel(index * root.majorStep, root.majorStep, root.fps)
                    color: Theme.textDim
                    font.pixelSize: 10
                    font.family: Theme.mono
                }
            }
        }

        // Video track: thumbnails inside a clip.
        Rectangle {
            id: videoClip
            y: root.rulerHeight + root.gap
            width: parent.width
            height: root.videoHeight
            radius: 4
            color: Theme.videoClip
            clip: true
            visible: root.duration > 0

            // Tiles at the picture's shape, each showing the thumbnail
            // nearest its place in time, like an editor's filmstrip.
            Row {
                id: strip
                anchors.fill: parent
                anchors.topMargin: 16
                readonly property real tileWidth: Math.max(24, height * Math.max(0.3, Math.min(4, root.aspect)))
                Repeater {
                    model: root.thumbnails.length > 0 ? Math.ceil(strip.width / strip.tileWidth) : 0
                    delegate: Image {
                        required property int index
                        readonly property int thumb: Math.min(root.thumbnails.length - 1,
                            Math.floor((index + 0.5) * strip.tileWidth / strip.width * root.thumbnails.length))
                        width: strip.tileWidth
                        height: strip.height
                        source: root.thumbnails[thumb] || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Rectangle {
                            anchors.right: parent.right
                            width: 1
                            height: parent.height
                            color: "black"
                            opacity: 0.5
                        }
                    }
                }
            }
            Text {
                x: 6
                y: 1
                width: parent.width - 12
                text: root.clipName
                color: "white"
                elide: Text.ElideRight
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Audio track: waveform inside a clip.
        Rectangle {
            id: audioClip
            y: root.rulerHeight + root.gap * 2 + root.videoHeight
            width: parent.width
            height: root.audioHeight
            radius: 4
            color: Theme.audioClip
            clip: true
            visible: root.duration > 0

            WaveformView {
                anchors.fill: parent
                anchors.margins: 2
                peaks: root.peaks
                color: Theme.waveform
            }
            Text {
                anchors.centerIn: parent
                visible: root.peaks.length === 0
                text: "No audio"
                color: Theme.textFaint
                font.pixelSize: 11
            }
        }

        // Everything outside the segments is dimmed.
        Repeater {
            model: {
                // The gaps between the segments, merged where they overlap.
                const kept = root.segments.slice().sort((a, b) => a.inPoint - b.inPoint)
                const gaps = []
                let from = 0
                for (const s of kept) {
                    if (s.inPoint > from)
                        gaps.push({ from: from, to: s.inPoint })
                    from = Math.max(from, s.outPoint)
                }
                if (from < root.duration)
                    gaps.push({ from: from, to: root.duration })
                return gaps
            }
            delegate: Rectangle {
                required property var modelData
                x: root.xFor(modelData.from)
                y: videoClip.y
                width: Math.max(0, root.xFor(modelData.to) - x)
                height: audioClip.y + audioClip.height - y
                color: "black"
                opacity: 0.6
            }
        }

        // Click or drag anywhere to scrub. Every seek is frame exact; mpv
        // drops the ones it can't keep up with, so the picture lands on the
        // frame under the mouse.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => root.scrubTo(root.timeAt(mouse.x), true)
            onPositionChanged: (mouse) => { if (pressed) root.scrubTo(root.timeAt(mouse.x), true) }
            onReleased: (mouse) => root.endScrub(root.timeAt(mouse.x))
        }

        component Handle: Item {
            id: handle
            property bool isIn: true
            property int segment: 0
            readonly property var range: root.segments[segment] || { inPoint: 0, outPoint: 0 }
            readonly property real time: isIn ? range.inPoint : range.outPoint
            readonly property color tint: root.segments.length > 1 ? Theme.segmentColor(segment) : Theme.accent
            readonly property bool active: segment === root.activeSegment
            z: active ? 2 : 1
            opacity: active || root.segments.length < 2 ? 1 : 0.7

            x: root.xFor(time) - width / 2
            width: 14
            height: audioClip.y + audioClip.height
            visible: root.duration > 0

            // Bracket line across the tracks.
            Rectangle {
                x: handle.isIn ? handle.width / 2 : handle.width / 2 - 3
                y: videoClip.y
                width: 3
                height: parent.height - y
                color: dragArea.pressed || dragArea.containsMouse ? Qt.lighter(handle.tint, 1.3) : handle.tint
            }
            // Tab on the ruler.
            Rectangle {
                x: handle.isIn ? handle.width / 2 : handle.width / 2 - 10
                y: root.rulerHeight - 16
                width: 10
                height: 16
                radius: 2
                color: handle.tint
                Text {
                    anchors.centerIn: parent
                    text: handle.isIn ? "<" : ">"
                    color: Theme.onColor(handle.tint)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Only the tab on the ruler moves the point, so scrubbing over the
            // tracks never drags it along.
            MouseArea {
                id: dragArea
                y: root.rulerHeight - 18
                height: 20
                x: handle.isIn ? handle.width / 2 - 3 : handle.width / 2 - 13
                width: 16
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                onPressed: root.segmentSelected(handle.segment)
                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return
                    const t = root.timeAt(mapToItem(lane, mouse.x, 0).x)
                    const r = handle.range
                    if (handle.isIn) {
                        const v = Math.max(0, Math.min(t, r.outPoint - root.minimumLength))
                        root.segmentMoved(handle.segment, v, r.outPoint)
                        root.scrubTo(v, true)
                    } else {
                        const v = Math.min(root.duration, Math.max(t, r.inPoint + root.minimumLength))
                        root.segmentMoved(handle.segment, r.inPoint, v)
                        root.scrubTo(v, true)
                    }
                }
                onReleased: root.endScrub(handle.time)
            }
        }

        Repeater {
            model: root.segments.length
            delegate: Item {
                required property int index
                anchors.fill: parent
                z: index === root.activeSegment ? 2 : 1
                Handle { isIn: true; segment: parent.index }
                Handle { isIn: false; segment: parent.index }
            }
        }

        // Playhead: a tab on the ruler and a line through the tracks.
        Item {
            id: playhead
            x: root.xFor(root.shownPosition)
            height: audioClip.y + audioClip.height
            visible: root.duration > 0

            Rectangle {
                x: -0.5
                y: root.rulerHeight - 4
                width: 1
                height: parent.height - y
                color: "#5aa8ff"
            }
            Shape {
                x: -7
                y: root.rulerHeight - 16
                width: 14
                height: 14
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    fillColor: "#5aa8ff"
                    strokeWidth: -1
                    startX: 0; startY: 0
                    PathLine { x: 14; y: 0 }
                    PathLine { x: 14; y: 8 }
                    PathLine { x: 7; y: 14 }
                    PathLine { x: 0; y: 8 }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
    }
}
