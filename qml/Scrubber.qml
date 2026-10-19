import QtQuick

// Timeline with a playhead and draggable in/out handles. It only reports what
// the user did; the owner decides how to seek and where to store the points.
Item {
    id: root

    property real duration: 0
    property real position: 0
    property real inPoint: 0
    property real outPoint: 0
    property real minimumLength: 0.04
    property color accent: palette.highlight

    signal seekRequested(real time, bool exact)
    signal inPointMoved(real time)
    signal outPointMoved(real time)

    implicitHeight: 56
    enabled: duration > 0

    function xFor(t) { return duration > 0 ? t / duration * track.width : 0 }
    function timeAt(x) { return duration > 0 ? Math.max(0, Math.min(duration, x / track.width * duration)) : 0 }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        height: 14
        radius: 3
        color: "#3a3c41"

        // Kept portion of the video.
        Rectangle {
            x: root.xFor(root.inPoint)
            width: Math.max(0, root.xFor(root.outPoint) - x)
            height: parent.height
            radius: 3
            color: root.accent
            opacity: 0.55
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -16
            anchors.bottomMargin: -16
            cursorShape: Qt.PointingHandCursor
            onPressed: (mouse) => root.seekRequested(root.timeAt(mouse.x), false)
            onPositionChanged: (mouse) => { if (pressed) root.seekRequested(root.timeAt(mouse.x), false) }
            onReleased: (mouse) => root.seekRequested(root.timeAt(mouse.x), true)
        }
    }

    // Playhead
    Rectangle {
        x: track.x + root.xFor(root.position) - width / 2
        anchors.verticalCenter: track.verticalCenter
        width: 2
        height: root.height - 8
        color: "white"
    }

    component Handle: Rectangle {
        id: handle
        property bool isIn: true
        readonly property real time: isIn ? root.inPoint : root.outPoint

        x: track.x + root.xFor(time) - (isIn ? width : 0)
        anchors.verticalCenter: track.verticalCenter
        width: 12
        height: 34
        radius: 2
        color: dragArea.pressed || dragArea.containsMouse ? Qt.lighter(root.accent, 1.3) : root.accent

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 1
            text: handle.isIn ? "IN" : "OUT"
            color: root.accent
            font.pixelSize: 9
            font.bold: true
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor

            onPositionChanged: (mouse) => {
                if (!pressed)
                    return
                const t = root.timeAt(mapToItem(track, mouse.x, 0).x)
                if (handle.isIn) {
                    const v = Math.min(t, root.outPoint - root.minimumLength)
                    root.inPointMoved(Math.max(0, v))
                    root.seekRequested(Math.max(0, v), false)
                } else {
                    const v = Math.max(t, root.inPoint + root.minimumLength)
                    root.outPointMoved(Math.min(root.duration, v))
                    root.seekRequested(Math.min(root.duration, v), false)
                }
            }
            onReleased: root.seekRequested(handle.time, true)
        }
    }

    Handle { isIn: true }
    Handle { isIn: false }
}
