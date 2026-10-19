// Never loaded. It names QML modules that Qt loads indirectly (Qt Quick
// Dialogs' own file dialog uses the folder list model) so that windeployqt
// and linuxdeploy's Qt plugin copy them into packages.
import Qt.labs.folderlistmodel
import QtQuick.Dialogs
import QtQuick.Controls.Material

QtObject {}
