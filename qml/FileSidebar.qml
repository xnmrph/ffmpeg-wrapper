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

    color: palette.base

    function badge(state) {
        switch (state) {
        case TrimJob.Idle: return { text: "Queued", color: palette.highlight }
        case TrimJob.Running: return { text: "Trimming", color: "#e0a030" }
        case TrimJob.Finished: return { text: "Done", color: "#3fb950" }
        case TrimJob.Failed: return { text: "Failed", color: "#ff6b6b" }
        case TrimJob.Cancelled: return { text: "Cancelled", color: "#8a8a8a" }
        }
        return null
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.margins: 10
            text: root.folderModel.folderName + "  ·  " + root.folderModel.count
                  + (root.folderModel.count === 1 ? " video" : " videos")
            font.bold: true
            elide: Text.ElideMiddle
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.folderModel
            currentIndex: root.folderModel.indexOf(root.currentUrl)
            highlightMoveDuration: 0
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: row
                required property string name
                required property url url
                required property int queueState
                readonly property var status: root.badge(queueState)

                width: ListView.view.width
                highlighted: String(url) === String(root.currentUrl)
                onClicked: root.videoSelected(url)

                contentItem: RowLayout {
                    spacing: 8
                    Label {
                        Layout.fillWidth: true
                        text: row.name
                        elide: Text.ElideMiddle
                    }
                    Label {
                        visible: row.status !== null
                        text: row.status ? row.status.text : ""
                        color: row.status ? row.status.color : "transparent"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No videos in this folder"
                opacity: 0.6
            }
        }
    }
}
