import QtQuick
import QtQuick.Shapes
import Trimmer

// Premiere-style timeline: a time ruler, a video track of thumbnails and an
// audio track with the waveform, with the in/out range, its handles and the
// playhead drawn across all three. It only reports what the user did; the
// owner decides how to seek and where to keep the points.
Rectangle {
    id: root

    property real duration: 0
    property real position: 0
    property real inPoint: 0
    property real outPoint: 0
    property real fps: 0
    property string clipName
    property var thumbnails: []
    // Width / height of the picture, so thumbnail tiles keep its shape.
    property real aspect: 16 / 9
    property var peaks: []
    property real minimumLength: 0.04

    signal seekRequested(real time, bool exact)
    signal inPointMoved(real time)
    signal outPointMoved(real time)

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

            // In/out range on the ruler.
            Rectangle {
                x: root.xFor(root.inPoint)
                width: Math.max(0, root.xFor(root.outPoint) - x)
                anchors.bottom: parent.bottom
                height: 6
                color: Theme.accent
                opacity: 0.45
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

        // Everything outside the in/out range is dimmed.
        Rectangle {
            y: videoClip.y
            width: root.xFor(root.inPoint)
            height: audioClip.y + audioClip.height - y
            color: "black"
            opacity: 0.6
        }
        Rectangle {
            x: root.xFor(root.outPoint)
            y: videoClip.y
            width: Math.max(0, parent.width - x)
            height: audioClip.y + audioClip.height - y
            color: "black"
            opacity: 0.6
        }

        // Click or drag anywhere to scrub: quick keyframe seeks while moving,
        // an exact seek on release.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => root.seekRequested(root.timeAt(mouse.x), false)
            onPositionChanged: (mouse) => { if (pressed) root.seekRequested(root.timeAt(mouse.x), false) }
            onReleased: (mouse) => root.seekRequested(root.timeAt(mouse.x), true)
        }

        component Handle: Item {
            id: handle
            property bool isIn: true
            readonly property real time: isIn ? root.inPoint : root.outPoint

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
                color: dragArea.pressed || dragArea.containsMouse ? Qt.lighter(Theme.accent, 1.3) : Theme.accent
            }
            // Tab on the ruler.
            Rectangle {
                x: handle.isIn ? handle.width / 2 : handle.width / 2 - 10
                y: root.rulerHeight - 16
                width: 10
                height: 16
                radius: 2
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: handle.isIn ? "I" : "O"
                    color: "white"
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.leftMargin: -4
                anchors.rightMargin: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                onPositionChanged: (mouse) => {
                    if (!pressed)
                        return
                    const t = root.timeAt(mapToItem(lane, mouse.x, 0).x)
                    if (handle.isIn) {
                        const v = Math.max(0, Math.min(t, root.outPoint - root.minimumLength))
                        root.inPointMoved(v)
                        root.seekRequested(v, false)
                    } else {
                        const v = Math.min(root.duration, Math.max(t, root.inPoint + root.minimumLength))
                        root.outPointMoved(v)
                        root.seekRequested(v, false)
                    }
                }
                onReleased: root.seekRequested(handle.time, true)
            }
        }

        Handle { isIn: true }
        Handle { isIn: false }

        // Playhead: a tab on the ruler and a line through the tracks.
        Item {
            id: playhead
            x: root.xFor(root.position)
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
