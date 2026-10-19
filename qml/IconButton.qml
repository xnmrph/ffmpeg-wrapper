import QtQuick
import QtQuick.Controls

// Flat, rounded button with an optional icon; "primary" fills it with the accent.
AbstractButton {
    id: root

    property string iconPath
    property real iconSize: 18
    property string tip
    property bool primary: false
    property color tint: primary ? "white" : Theme.text

    implicitWidth: text !== "" ? content.implicitWidth + 24 : 32
    implicitHeight: 32
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : 0.4

    ToolTip.visible: tip !== "" && hovered
    ToolTip.delay: 500
    ToolTip.text: tip

    background: Rectangle {
        radius: Theme.radius
        color: root.primary
               ? (root.down ? Qt.darker(Theme.accent, 1.2) : root.hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
               : (root.down ? "#303036" : root.checked ? Theme.hover : root.hovered ? Theme.hover : "transparent")
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconPath !== ""
                path: root.iconPath
                size: root.iconSize
                color: root.checked && !root.primary ? Theme.accent : root.tint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.text !== ""
                text: root.text
                color: root.tint
                font.pixelSize: 13
                font.weight: root.primary ? Font.DemiBold : Font.Medium
            }
        }
    }
}
