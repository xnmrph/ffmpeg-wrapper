import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Trimmer

// Folder mode's right panel: the export queue and its controls.
Rectangle {
    id: root

    required property ExportQueue queue
    required property var formatTime

    signal jobActivated(url source)

    color: palette.base

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.margins: 10
            text: "Export queue  ·  " + root.queue.count
            font.bold: true
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 1
            model: root.queue
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: row
                required property int index
                required property string name
                required property url source
                required property real inPoint
                required property real outPoint
                required property int mode
                required property int jobState
                required property real progress
                required property string errorString

                width: ListView.view.width
                onClicked: root.jobActivated(source)

                contentItem: ColumnLayout {
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: row.name
                            elide: Text.ElideMiddle
                        }
                        ToolButton {
                            text: "✕"
                            implicitWidth: 24
                            implicitHeight: 24
                            ToolTip.visible: hovered
                            ToolTip.text: row.jobState === TrimJob.Running ? "Cancel and remove" : "Remove"
                            onClicked: root.queue.remove(row.index)
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.formatTime(row.inPoint) + " → " + root.formatTime(row.outPoint)
                              + "  ·  " + (row.mode === TrimJob.Fast ? "Fast" : "Accurate")
                        font.pixelSize: 11
                        font.family: "monospace"
                        opacity: 0.75
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        visible: row.jobState === TrimJob.Running
                        value: row.progress
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: row.jobState !== TrimJob.Running && row.jobState !== TrimJob.Idle
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        text: row.jobState === TrimJob.Finished ? "Done"
                            : row.jobState === TrimJob.Failed ? "Failed: " + row.errorString
                            : "Cancelled"
                        color: row.jobState === TrimJob.Finished ? "#3fb950"
                             : row.jobState === TrimJob.Failed ? "#ff6b6b" : "#8a8a8a"
                        ToolTip.visible: row.jobState === TrimJob.Failed && failHover.hovered
                        ToolTip.text: row.errorString
                        HoverHandler { id: failHover }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                width: parent.width - 40
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Set the in and out points on a video, then press Add to queue (Q)."
                opacity: 0.6
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            visible: root.queue.finishedCount + root.queue.failedCount > 0
            text: root.queue.finishedCount + " done"
                  + (root.queue.failedCount > 0 ? "  ·  " + root.queue.failedCount + " failed" : "")
                  + (root.queue.pendingCount > 0 ? "  ·  " + root.queue.pendingCount + " waiting" : "")
            font.pixelSize: 11
            opacity: 0.75
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 8

            Label { text: "At once" }
            SpinBox {
                from: 1
                to: 8
                value: root.queue.maxConcurrent
                onValueModified: root.queue.maxConcurrent = value
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: "How many videos are trimmed at the same time"
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Clear done"
                enabled: root.queue.finishedCount > 0
                onClicked: root.queue.clearFinished()
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            highlighted: !root.queue.running
            enabled: root.queue.running || root.queue.count > root.queue.finishedCount
            text: root.queue.running ? "Cancel" : "Start trimming"
            onClicked: root.queue.running ? root.queue.cancel() : root.queue.start()
        }
    }
}
