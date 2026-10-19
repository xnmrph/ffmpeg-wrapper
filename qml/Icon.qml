import QtQuick
import QtQuick.Shapes

// A single-colour vector icon from Icons.
Item {
    id: root

    property string path
    property color color: Theme.text
    property real size: 20

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            strokeColor: "transparent"
            scale: Qt.size(root.size / 24, root.size / 24)
            PathSvg { path: root.path }
        }
    }
}
