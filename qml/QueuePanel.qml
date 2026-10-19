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

    color: Theme.surface

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 1
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8
            Icon {
                path: Icons.queueAdd
                size: 18
                color: Theme.textDim
            }
            Text {
                Layout.fillWidth: true
                text: "Export queue"
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                text: root.queue.count
                color: Theme.textFaint
                font.pixelSize: 12
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            leftMargin: 8
            rightMargin: 8
            clip: true
            spacing: 6
            model: root.queue
            ScrollBar.vertical: ScrollBar {}

            delegate: AbstractButton {
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
                required property string errorDetails

                readonly property color stateColor: jobState === TrimJob.Finished ? Theme.success
                    : jobState === TrimJob.Failed ? Theme.danger
                    : jobState === TrimJob.Running ? Theme.accent
                    : jobState === TrimJob.Cancelled ? Theme.textFaint : Theme.border

                width: ListView.view.width - 16
                padding: 10
                leftPadding: 14
                implicitHeight: card.implicitHeight + topPadding + bottomPadding
                hoverEnabled: true
                onClicked: root.jobActivated(source)

                background: Rectangle {
                    radius: Theme.radius + 2
                    color: row.hovered ? Theme.hover : Theme.surfaceRaised
                    border.color: Theme.border
                    Rectangle {
                        width: 3
                        x: 0
                        y: 8
                        height: parent.height - 16
                        radius: 2
                        color: row.stateColor
                    }
                }

                contentItem: ColumnLayout {
                    id: card
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: row.name
                            color: Theme.text
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                        IconButton {
                            iconPath: Icons.close
                            iconSize: 14
                            implicitWidth: 22
                            implicitHeight: 22
                            tint: Theme.textDim
                            tip: row.jobState === TrimJob.Running ? "Cancel and remove" : "Remove"
                            onClicked: root.queue.remove(row.index)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.formatTime(row.inPoint) + "  →  " + root.formatTime(row.outPoint)
                        color: Theme.textDim
                        font.pixelSize: 11
                        font.family: Theme.mono
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: row.mode === TrimJob.Fast ? "FAST" : "ACCURATE"
                            color: Theme.textFaint
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            color: row.jobState === TrimJob.Idle ? Theme.textDim : row.stateColor
                            text: row.jobState === TrimJob.Running ? Math.round(row.progress * 100) + "%"
                                : row.jobState === TrimJob.Finished ? "Done"
                                : row.jobState === TrimJob.Failed ? "Failed"
                                : row.jobState === TrimJob.Cancelled ? "Cancelled" : "Waiting"
                        }
                    }
                    Rectangle {
                        visible: row.jobState === TrimJob.Running
                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 2
                        color: Theme.hover
                        Rectangle {
                            width: parent.width * row.progress
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: row.jobState === TrimJob.Failed
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: Theme.danger
                        text: row.errorString
                        ToolTip.visible: failHover.hovered && row.errorDetails !== ""
                        ToolTip.text: row.errorDetails
                        HoverHandler { id: failHover }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 48
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Set the in and out points on a video, then press Add to queue (Q)."
                color: Theme.textFaint
                font.pixelSize: 13
                lineHeight: 1.3
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 10
            visible: root.queue.finishedCount + root.queue.failedCount > 0
            text: root.queue.finishedCount + " done"
                  + (root.queue.failedCount > 0 ? "  ·  " + root.queue.failedCount + " failed" : "")
                  + (root.queue.pendingCount > 0 ? "  ·  " + root.queue.pendingCount + " waiting" : "")
            color: Theme.textDim
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 10
            Layout.topMargin: 6
            spacing: 6

            Text {
                text: "At once"
                color: Theme.textDim
                font.pixelSize: 12
            }
            IconButton {
                text: "−"
                implicitWidth: 26
                implicitHeight: 26
                enabled: root.queue.maxConcurrent > 1
                onClicked: root.queue.settings.maxConcurrent = root.queue.maxConcurrent - 1
            }
            Text {
                text: root.queue.maxConcurrent
                color: Theme.text
                font.family: Theme.mono
                font.pixelSize: 13
                ToolTip.visible: concurrencyHover.hovered
                ToolTip.text: "How many videos are trimmed at the same time"
                HoverHandler { id: concurrencyHover }
            }
            IconButton {
                text: "+"
                implicitWidth: 26
                implicitHeight: 26
                enabled: root.queue.maxConcurrent < 8
                onClicked: root.queue.settings.maxConcurrent = root.queue.maxConcurrent + 1
            }
            Item { Layout.fillWidth: true }
            IconButton {
                text: "Clear done"
                enabled: root.queue.finishedCount > 0
                onClicked: root.queue.clearFinished()
            }
        }

        IconButton {
            Layout.fillWidth: true
            Layout.margins: 12
            implicitHeight: 40
            primary: !root.queue.running
            iconPath: root.queue.running ? Icons.close : Icons.play
            enabled: root.queue.running || root.queue.count > root.queue.finishedCount
            text: root.queue.running ? "Cancel" : "Start trimming"
            onClicked: root.queue.running ? root.queue.cancel() : root.queue.start()
        }
    }
}
