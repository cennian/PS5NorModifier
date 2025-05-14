import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtQuick.Dialogs 6.2 // For MessageDialog
import PS5NorModifier 1.0 // Matches URI in CMakeLists.txt

ApplicationWindow {
    width: 900
    height: 700
    visible: true
    title: "PS5 NOR Modifier Qt - Modern Edition"

    // To store the hex content of the currently opened file
    property string currentFileHexContent: ""
    property string currentFilePath: ""

    FontLoader { id: iconFont; source: "qrc:/qt-project.org/imports/QtQuick/Controls/imagine/fonts/qtcontrolsicons.ttf" }

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: ""
        standardButtons: MessageDialog.Ok
        icon: StandardIcon.Critical
    }

    MessageDialog {
        id: infoDialog
        title: "Information"
        text: ""
        standardButtons: MessageDialog.Ok
        icon: StandardIcon.Information
    }
    
    FileDialog {
        id: openFileDialog
        title: "Open NOR Dump File"
        folder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        nameFilters: ["Binary files (*.bin)", "All files (*)"]
        onAccepted: {
            console.log("File selected: " + openFileDialog.file)
            currentFilePath = openFileDialog.file
            // backend.openFile returns hex string directly or empty on error
            var hexContent = backend.openFile(openFileDialog.file)
            // fileOpened signal will update UI if successful
        }
    }

    FileDialog {
        id: saveFileDialog
        title: "Save Modified NOR File"
        folder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        nameFilters: ["Binary files (*.bin)", "All files (*)"]
        selectExisting: false
        onAccepted: {
            console.log("Save to file: " + saveFileDialog.file)
            if (backend.saveFile(saveFileDialog.file, fileContentArea.text)) {
                infoDialog.text = "File saved successfully to " + saveFileDialog.file
                infoDialog.open()
            }
            // Error handling is done via backend's errorOccurred signal
        }
    }

    Connections {
        target: backend
        function onErrorOccurred(title, message) {
            errorDialog.title = title ? title : "Error"
            errorDialog.text = message
            errorDialog.open()
        }
        function onDatabaseDownloadFinished(success) {
            if (success) {
                infoDialog.text = backend.statusMessage // Use status message from backend
                infoDialog.open()
            } else {
                // Error should have been shown via errorOccurred
                 if (!errorDialog.visible) { // Show generic if no specific error was raised
                    errorDialog.title = "Database Download Failed"
                    errorDialog.text = backend.statusMessage
                    errorDialog.open()
                }
            }
        }
        function onFileOpened(fileName, fileContentHex) {
            currentFilePath = fileName
            currentFileHexContent = fileContentHex
            fileContentArea.text = fileContentHex // Display hex content
            
            // Update status bar or a dedicated file info label
            statusBar.text = "Opened: " + fileName
            infoDialog.text = "File opened: " + fileName;
            infoDialog.open();
        }
        function onSerialPortConnectedChanged(connected) {
            connectButton.text = connected ? "Disconnect" : "Connect";
            serialCommandInput.enabled = connected;
            sendSerialCommandButton.enabled = connected && serialCommandInput.text.trim() !== "";
            // Update status bar
            statusBar.text = connected ? "Connected to " + backend.currentSerialPort : "Disconnected";
        }
         function onAvailableSerialPortsChanged() {
            // Model is directly bound, but if manual update needed:
            // serialPortCombo.model = backend.availableSerialPorts
            // Ensure current selection is preserved if possible
            var currentPort = backend.currentSerialPort
            if (backend.availableSerialPorts.includes(currentPort)) {
                serialPortCombo.currentIndex = backend.availableSerialPorts.indexOf(currentPort)
            } else if (backend.availableSerialPorts.length > 0) {
                serialPortCombo.currentIndex = 0
                backend.currentSerialPort = backend.availableSerialPorts[0]
            } else {
                serialPortCombo.currentIndex = -1
            }
        }
    }

    Header {
        id: header
        text: "PS5 NOR Modifier"
    }

    ColumnLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        anchors.margins: 10
        spacing: 10

        Label {
            id: statusLabel // General status messages from backend
            text: backend.statusMessage
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            font.italic: true
        }

        TabView {
            id: mainTabView
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            Tab {
                title: "File Operations"
                icon.name: "document-open" // Example using a symbolic name
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 10

                    RowLayout {
                        spacing: 10
                        Button {
                            text: "Open .bin File"
                            icon.name: "document-open-symbolic" // Placeholder
                            onClicked: openFileDialog.open()
                            Layout.preferredWidth: 150
                        }
                        Button {
                            text: "Save .bin File"
                            icon.name: "document-save-symbolic" // Placeholder
                            enabled: fileContentArea.text !== ""
                            onClicked: saveFileDialog.open()
                            Layout.preferredWidth: 150
                        }
                    }
                    Label {
                        text: "File Content (Hex View): " + (currentFilePath ? currentFilePath : "No file opened")
                        font.bold: true
                    }
                    TextArea {
                        id: fileContentArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        placeholderText: "Open a .bin file to see its content in hex format..."
                        wrapMode: Text.WordWrap
                        font.family: "Monospace"
                        font.pixelSize: 12
                        readOnly: false // Allow editing for saving
                    }
                }
            }

            Tab {
                title: "Error Database"
                icon.name: "help-faq" // Example

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 10
                    
                    Button {
                        text: "Download/Update Error Database"
                        icon.name: "arrow-down"
                        onClicked: backend.downloadDatabaseAsync()
                        Layout.alignment: Qt.AlignLeft
                    }

                    GroupBox {
                        title: "Error Code Lookup (Offline)"
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 5
                            TextField {
                                id: errorCodeInput
                                placeholderText: "Enter Error Code (e.g., SU-101312-8)"
                                Layout.fillWidth: true
                                Keys.onReturnPressed: parseErrorCodeButton.clicked()
                            }
                            Button {
                                id: parseErrorCodeButton
                                text: "Parse Error Code"
                                icon.name: "edit-find"
                                onClicked: {
                                    if (errorCodeInput.text.trim() !== "") {
                                        var result = backend.parseErrorsOffline(errorCodeInput.text.trim())
                                        errorResultArea.text = result
                                    } else {
                                        errorDialog.text = "Please enter an error code."
                                        errorDialog.title = "Input Required"
                                        errorDialog.open()
                                    }
                                }
                            }
                            Label { text: "Result:" }
                            TextArea {
                                id: errorResultArea
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                readOnly: true
                                wrapMode: Text.WordWrap
                                placeholderText: "Parsed error description will appear here."
                                background: Rectangle { color: "#f0f0f0" }
                            }
                        }
                    }
                }
            }
            
            Tab {
                title: "Serial (UART)"
                icon.name: "preferences-system" // Example

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 10

                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true
                        ComboBox {
                            id: serialPortCombo
                            Layout.fillWidth: true
                            model: backend.availableSerialPorts
                            textRole: "" // Display the string directly
                            currentIndex: backend.availableSerialPorts.indexOf(backend.currentSerialPort)
                            
                            onActivated: (index) => { // More reliable for user selection
                                if (index !== -1 && index < backend.availableSerialPorts.length) {
                                   backend.currentSerialPort = backend.availableSerialPorts[index]
                                }
                            }
                        }
                        Button {
                            text: "Refresh"
                            icon.name: "view-refresh"
                            onClicked: backend.refreshSerialPorts()
                        }
                        Button {
                            id: connectButton
                            text: backend.isSerialPortConnected ? "Disconnect" : "Connect"
                            icon.name: backend.isSerialPortConnected ? "network-offline" : "network-wired"
                            enabled: serialPortCombo.currentIndex !== -1 || backend.isSerialPortConnected
                            onClicked: {
                                if (backend.isSerialPortConnected) {
                                    backend.disconnectSerialPort()
                                } else {
                                    if(serialPortCombo.currentIndex !== -1) {
                                     // backend.currentSerialPort should be set by ComboBox onActivated
                                        backend.connectSerialPort() 
                                    } else {
                                        errorDialog.text = "Please select a serial port."
                                        errorDialog.title = "Serial Port Required"
                                        errorDialog.open()
                                    }
                                }
                            }
                        }
                    }
                    
                    GroupBox {
                        title: "Send Command"
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 5
                             TextField {
                                id: serialCommandInput
                                placeholderText: "Enter command (e.g., errlog 0)"
                                Layout.fillWidth: true
                                enabled: backend.isSerialPortConnected
                                Keys.onReturnPressed: sendSerialCommandButton.clicked()
                            }
                            Button {
                                id: sendSerialCommandButton
                                text: "Send Command"
                                icon.name: "document-send"
                                enabled: backend.isSerialPortConnected && serialCommandInput.text.trim() !== ""
                                onClicked: {
                                     var response = backend.sendSerialCommand(serialCommandInput.text.trim())
                                     // Append command and response for clarity
                                     serialOutputArea.append(">> " + serialCommandInput.text.trim() + "\\n")
                                     serialOutputArea.append("<< " + response + "\\n")
                                     // Status message is also updated by backend
                                }
                            }
                        }
                    }
                    Label { text: "Serial Output/Log:" }
                    TextArea {
                        id: serialOutputArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readOnly: true
                        wrapMode: Text.WordWrap
                        placeholderText: "Serial communication logs and responses..."
                        font.family: "Monospace"
                        font.pixelSize: 12
                        background: Rectangle { color: "#e8e8e8" }
                    }
                }
            }
        }
    }

    StatusBar {
        id: statusBar
        Label {
            id: statusBarLabel
            text: "Ready" // Default status
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
