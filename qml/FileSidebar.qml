import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Trimmer

// Folder mode's left panel: every video in the folder and its queue state.
Rectangle {
    id: root

    required property VideoFolderModel folderModel
    property url currentUrl

    signal videoSelected(url url)

    color: Theme.surface

    function badge(state) {
        switch (state) {
        case TrimJob.Idle: return { text: "Queued", color: Theme.accent }
        case TrimJob.Running: return { text: "Trimming", color: Theme.warning }
        case TrimJob.Finished: return { text: "Done", color: Theme.success }
        case TrimJob.Failed: return { text: "Failed", color: Theme.danger }
        case TrimJob.Cancelled: return { text: "Cancelled", color: Theme.textFaint }
        }
        return null
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.rightMargin: 1
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8
            Icon {
                path: Icons.folder
                size: 18
                color: Theme.textDim
            }
            Text {
                Layout.fillWidth: true
                text: root.folderModel.folderName
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }
            Text {
                text: root.folderModel.count
                color: Theme.textFaint
                font.pixelSize: 12
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            leftMargin: 6
            rightMargin: 6
            spacing: 2
            clip: true
            model: root.folderModel
            ScrollBar.vertical: ScrollBar {}

            delegate: AbstractButton {
                id: row
                required property string name
                required property url url
                required property int queueState
                readonly property var status: root.badge(queueState)
                readonly property bool current: String(url) === String(root.currentUrl)

                width: ListView.view.width - 12
                implicitHeight: 34
                hoverEnabled: true
                onClicked: root.videoSelected(url)

                background: Rectangle {
                    radius: Theme.radius
                    color: row.current ? Qt.rgba(0.18, 0.55, 1, 0.18) : row.hovered ? Theme.hover : "transparent"
                    Rectangle {
                        visible: row.current
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 12
                        radius: 2
                        color: Theme.accent
                    }
                }

                contentItem: RowLayout {
                    spacing: 8
                    Icon {
                        Layout.leftMargin: 6
                        path: Icons.movie
                        size: 16
                        color: row.current ? Theme.accent : Theme.textFaint
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.name
                        color: row.current ? Theme.text : Theme.textDim
                        font.pixelSize: 13
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        visible: row.status !== null
                        Layout.rightMargin: 4
                        implicitWidth: badgeText.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: row.status ? Qt.rgba(row.status.color.r, row.status.color.g, row.status.color.b, 0.18) : "transparent"
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: row.status ? row.status.text : ""
                            color: row.status ? row.status.color : "transparent"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No videos in this folder"
                color: Theme.textFaint
            }
        }
    }
}
