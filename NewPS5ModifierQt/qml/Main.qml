import QtQuick.Controls
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import PS5NorModifier 1.0 // Matches URI in CMakeLists.txt

ApplicationWindow {
    width: 900
    height: 700
    visible: true
    title: "PS5 NOR Modifier Qt - Modern Edition"

    // To store the hex content of the currently opened file
    property string currentFileHexContent: ""
    property string currentFilePath: ""
    property int currentTabIndex: 0 // To track active tab

    // Properties to hold detailed NOR information
    property string consoleModel: "Unknown"
    property string motherboardSerial: "Unknown"
    property string boardSerial: "Unknown"
    property string wifiMac: "Unknown"
    property string lanMac: "Unknown"
    property string boardVariant: "Unknown"
    property string fileSize: "0 bytes (0MB)"

    // Property for offline/online error parsing choice
    property bool useOfflineErrorDb: true

    // FontLoader { id: iconFont; source: "qrc:/qt-project.org/imports/QtQuick/Controls/imagine/fonts/qtcontrolsicons.ttf" } // Commented out or remove if causing issues and not strictly needed

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: ""
        buttons: Dialog.Ok
    }

    MessageDialog {
        id: infoDialog
        title: "Information"
        text: ""
        buttons: Dialog.Ok
    }
    
    FileDialog {
        id: openFileDialog
        title: "Open NOR Dump File"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) // StandardPaths should now be defined
        nameFilters: ["Binary files (*.bin)", "All files (*)"]
        onAccepted: {
            console.log("File selected: " + openFileDialog.file)
            currentFilePath = openFileDialog.file
            var hexContent = backend.openFile(openFileDialog.file)
        }
    }

    FileDialog {
        id: saveFileDialog
        title: "Save Modified NOR File"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) // StandardPaths should now be defined
        nameFilters: ["Binary files (*.bin)", "All files (*)"]
        onAccepted: {
            console.log("Save to file: " + saveFileDialog.file)
            if (backend.saveFile(saveFileDialog.file, fileContentArea.text)) {
                infoDialog.text = "File saved successfully to " + saveFileDialog.file
                infoDialog.open()
            }
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
                infoDialog.text = backend.statusMessage
                infoDialog.open()
            } else {
                if (!errorDialog.visible) {
                    errorDialog.title = "Database Download Failed"
                    errorDialog.text = backend.statusMessage
                    errorDialog.open()
                }
            }
        }
        function onFileOpened(fileName, fileContentHex, details) {
            currentFilePath = fileName
            currentFileHexContent = fileContentHex
            fileContentArea.text = fileContentHex
            
            consoleModel = details.model || "Unknown"
            motherboardSerial = details.moboSerial || "Unknown"
            boardSerial = details.boardSerial || "Unknown"
            wifiMac = details.wifiMac || "Unknown"
            lanMac = details.lanMac || "Unknown"
            boardVariant = details.variant || "Unknown"
            fileSize = details.size || "0 bytes (0MB)"
            
            statusBarLabel.text = "Opened: " + fileName
            infoDialog.text = "File opened: " + fileName;
            infoDialog.open();
        }
        function onSerialPortConnectedChanged(connected) {
            connectButton.text = connected ? "Disconnect" : "Connect";
            serialCommandInput.enabled = connected;
            sendSerialCommandButton.enabled = connected && serialCommandInput.text.trim() !== "";
            statusBarLabel.text = connected ? "Connected to " + backend.currentSerialPort : "Disconnected";
        }
        function onAvailableSerialPortsChanged() {
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

    Pane {
        id: header
        width: parent.width
        implicitHeight: headerLabel.implicitHeight + 20

        Label {
            id: headerLabel
            text: "PS5 NOR Modifier"
            font.bold: true
            font.pixelSize: 18
            anchors.centerIn: parent
        }
    }

    ColumnLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 10

        Label {
            id: statusLabel
            text: backend.statusMessage
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            font.italic: true
        }

        RowLayout {
            spacing: 2
            Button {
                text: "File Operations"
                icon.name: "document-open"
                onClicked: currentTabIndex = 0
                flat: currentTabIndex !== 0
                highlighted: currentTabIndex === 0
                Layout.preferredHeight: 30 
            }
            Button {
                text: "Error Database"
                icon.name: "help-faq"
                onClicked: currentTabIndex = 1
                flat: currentTabIndex !== 1
                highlighted: currentTabIndex === 1
                Layout.preferredHeight: 30
            }
            Button {
                text: "Serial (UART)"
                icon.name: "preferences-system"
                onClicked: currentTabIndex = 2
                flat: currentTabIndex !== 2
                highlighted: currentTabIndex === 2
                Layout.preferredHeight: 30
            }
        }

        StackLayout {
            id: mainContentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTabIndex

            ColumnLayout { // Tab 1: File Operations
                Layout.margins: 5 // Added: This will create padding around this ColumnLayout
                spacing: 10

                RowLayout {
                    spacing: 10
                    Button {
                        text: "Open .bin File"
                        icon.name: "document-open-symbolic"
                        onClicked: openFileDialog.open()
                        Layout.preferredWidth: 150
                    }
                    Button {
                        text: "Save .bin File"
                        icon.name: "document-save-symbolic"
                        enabled: fileContentArea.text !== ""
                        onClicked: saveFileDialog.open()
                        Layout.preferredWidth: 150
                    }
                }
                Label {
                    text: "File Path: " + (currentFilePath ? currentFilePath : "No file opened")
                    font.bold: true
                }
                Label { text: "File Size: " + fileSize }
                Label { text: "Console Model: " + consoleModel }
                Label { text: "Mobo Serial: " + motherboardSerial }
                Label { text: "Board Serial: " + boardSerial }
                Label { text: "WiFi MAC: " + wifiMac }
                Label { text: "LAN MAC: " + lanMac }
                Label { text: "Board Variant: " + boardVariant }
                
                Label {
                    text: "File Content (Hex View):"
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
                    readOnly: false
                }
            }

            ColumnLayout { // Tab 2: Error Database
                Layout.margins: 5 // Added: This will create padding around this ColumnLayout
                spacing: 10
                
                RowLayout {
                    spacing: 10
                    CheckBox {
                        id: useOfflineDbCheckBox
                        text: "Use Offline Database"
                        checked: useOfflineErrorDb
                        onCheckedChanged: useOfflineErrorDb = checked
                    }
                    Button {
                        text: "Download/Update Error Database"
                        icon.name: "arrow-down"
                        onClicked: backend.downloadDatabaseAsync()
                    }
                }

                GroupBox {
                    title: "Error Code Lookup"
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
                                    var result = useOfflineErrorDb ? backend.parseErrorsOffline(errorCodeInput.text.trim()) : backend.parseErrorsOnline(errorCodeInput.text.trim())
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
            
            ColumnLayout { // Tab 3: Serial (UART)
                Layout.margins: 5 // Added: This will create padding around this ColumnLayout
                spacing: 10

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    ComboBox {
                        id: serialPortCombo
                        Layout.fillWidth: true
                        model: backend.availableSerialPorts
                        textRole: ""
                        currentIndex: backend.availableSerialPorts.indexOf(backend.currentSerialPort)
                        
                        onActivated: (index) => {
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
                
                RowLayout {
                    spacing: 10
                    Button {
                        text: "Read All Error Logs"
                        icon.name: "format-list-bulleted"
                        onClicked: {
                            serialOutputArea.append(">> Reading all error logs...\n");
                        }
                    }
                    Button {
                        text: "Clear Console Error Logs"
                        icon.name: "edit-clear"
                        onClicked: {
                            serialOutputArea.append(">> Clearing console error logs...\n");
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
                                serialOutputArea.append(">> " + serialCommandInput.text.trim() + "\\n")
                                serialOutputArea.append("<< " + response + "\\n")
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Serial Output/Log:"; Layout.fillWidth: true }
                    Button {
                        text: "Clear Output"
                        icon.name: "edit-clear-all"
                        onClicked: serialOutputArea.clear()
                    }
                }
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

    footer: Pane {
        id: statusBar
        implicitHeight: statusBarLabel.implicitHeight + 10
        width: parent.width

        Label {
            id: statusBarLabel
            text: "Ready"
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MenuBar {
        Menu {
            title: "Help"
            Action { text: "Donate to TheCod3r"; onTriggered: Qt.openUrlExternally("https://www.streamelements.com/thecod3r/tip") }
            Action { text: "ConsoleFix.Shop"; onTriggered: Qt.openUrlExternally("https://www.consolefix.shop") }
        }
    }
}
