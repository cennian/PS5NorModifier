import QtQuick.Controls
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore // For StandardPaths
import PS5NorModifier 1.0

ApplicationWindow {
    id: root 
    width: 900
    height: 700
    visible: true
    title: "PS5 NOR Modifier Qt - Modern Edition"

    // Theme Properties
    property bool isDarkMode: false 
    onIsDarkModeChanged: {
        console.log("Main.qml: isDarkMode CHANGED to: " + isDarkMode);
    }

    readonly property color accentColor: "#0078D4" // Fluent Design Blue
    readonly property color accentColorTextOnDark: "#FFFFFF"
    readonly property color accentColorTextOnLight: "#FFFFFF" // Often white text on accent

    readonly property var buttonStyles: {
        "primary":    { "background": "#007BFF", "text": "#FFFFFF", "border": "#007BFF", "hover": Qt.lighter("#007BFF", 1.10), "pressed": Qt.darker("#007BFF", 1.10) },
        "secondary":  { "background": "#6C757D", "text": "#FFFFFF", "border": "#6C757D", "hover": Qt.lighter("#6C757D", 1.10), "pressed": Qt.darker("#6C757D", 1.10) },
        "success":    { "background": "#28A745", "text": "#FFFFFF", "border": "#28A745", "hover": Qt.lighter("#28A745", 1.10), "pressed": Qt.darker("#28A745", 1.10) },
        "danger":     { "background": "#DC3545", "text": "#FFFFFF", "border": "#DC3545", "hover": Qt.lighter("#DC3545", 1.10), "pressed": Qt.darker("#DC3545", 1.10) },
        "warning":    { "background": "#FFC107", "text": "#212529", "border": "#FFC107", "hover": Qt.lighter("#FFC107", 1.10), "pressed": Qt.darker("#FFC107", 1.10) }, // Dark text for yellow
        "info":       { "background": "#17A2B8", "text": "#FFFFFF", "border": "#17A2B8", "hover": Qt.lighter("#17A2B8", 1.10), "pressed": Qt.darker("#17A2B8", 1.10) },
        "lightStyle": { "background": "#F8F9FA", "text": "#212529", "border": "#ADB5BD", "hover": Qt.darker("#F8F9FA", 1.05), "pressed": Qt.darker("#F8F9FA", 1.15) }, // "Light" button from image
        "darkStyle":  { "background": "#343A40", "text": "#FFFFFF", "border": "#343A40", "hover": Qt.lighter("#343A40", 1.20), "pressed": Qt.lighter("#343A40", 1.40) }, // "Dark" button from image
        "default": { // Fallback, uses currentPalette button colors
            "background": root.currentPalette.buttonBackground, // Use root.currentPalette
            "text": root.currentPalette.buttonText,
            "border": root.currentPalette.buttonBorder,
            "hover": root.currentPalette.buttonHover,
            "pressed": root.currentPalette.buttonPressed
        }
    }

    readonly property var lightPalette: {
        "windowBackground": "#F3F3F3", // Overall window
        "text": "#000000",             // Primary text
        "secondaryText": "#505050",    // Dimmer text
        "placeholderText": "#767676",
        "paneBackground": "#FFFFFF",   // Header, footer, GroupBox background
        "cardBackground": "#FFFFFF",   // For elements that need to stand out slightly
        "controlBackground": "#FFFFFF",// TextField, ComboBox, etc.
        "controlHover": "#E5F1FB",     // Light blue hover, derived from accent
        "controlPressed": "#CCE4F7",   // Slightly darker blue for pressed
        "controlBorder": "#ACACAC",
        "controlFocusBorder": accentColor,
        "buttonText": "#000000",
        "buttonBackground": "#E1E1E1",
        "buttonHover": "#E5F1FB",
        "buttonPressed": "#CCE4F7",
        "buttonBorder": "#ACACAC",
        "statusBarText": "#000000",
        "menuBarBackground": "#F3F3F3",
        "menuItemBackground": "transparent",
        "menuItemHover": "#E5F1FB",
        "textAreaBackground": "#FFFFFF",
        "textAreaReadOnlyBackground": "#F9F9F9", // Slightly off-white for read-only
        "dialogBackground": "#FFFFFF",
        "dialogText": "#000000"
    }

    readonly property var darkPalette: {
        "windowBackground": "#202020",
        "text": "#FFFFFF",
        "secondaryText": "#A0A0A0",
        "placeholderText": "#8A8A8A",
        "paneBackground": "#2D2D2D",
        "cardBackground": "#252525",
        "controlBackground": "#3C3C3C",
        "controlHover": "#005A9E",    // Darker blue hover
        "controlPressed": "#004578",  // Even darker blue
        "controlBorder": "#5A5A5A",
        "controlFocusBorder": accentColor,
        "buttonText": "#FFFFFF",
        "buttonBackground": "#3C3C3C",
        "buttonHover": "#005A9E",
        "buttonPressed": "#004578",
        "buttonBorder": "#5A5A5A",
        "statusBarText": "#FFFFFF",
        "menuBarBackground": "#2D2D2D",
        "menuItemBackground": "transparent",
        "menuItemHover": "#005A9E",
        "textAreaBackground": "#2B2B2B",
        "textAreaReadOnlyBackground": "#252525",
        "dialogBackground": "#2D2D2D",
        "dialogText": "#FFFFFF"
    }

    property var currentPalette: isDarkMode ? darkPalette : lightPalette
    onCurrentPaletteChanged: {
        console.log("Main.qml: currentPalette CHANGED. Window background should be: " + currentPalette.windowBackground);
    }

    Component.onCompleted: {
        console.log("Main.qml: Component.onCompleted. Initial isDarkMode: " + isDarkMode);
        console.log("Main.qml: Component.onCompleted. Initial currentPalette.windowBackground: " + currentPalette.windowBackground);
    }

    background: Rectangle {
        color: currentPalette.windowBackground
    }

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

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: "" // Text is set directly on the MessageDialog
        buttons: Dialog.Ok // Changed from standardButtons
    }

    MessageDialog {
        id: infoDialog
        title: "Information"
        text: "" // Text is set directly on the MessageDialog
        buttons: Dialog.Ok // Changed from standardButtons
    }
    
    FileDialog {
        id: openFileDialog
        title: "Open NOR Dump File"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) // Changed back to currentFolder
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
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) // Changed back to currentFolder
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
            if (!backend) return; // Should not be necessary here, but good practice
            errorDialog.title = title ? title : "Error"
            errorDialog.text = message
            errorDialog.open()
        }
        function onDatabaseDownloadFinished(success) {
            if (!backend) return;
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
            if (!backend) return;
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
            // This function is called by backend, so backend is valid.
            // Bindings that read backend.isSerialPortConnected need guards for initial setup.
            // connectButton.text, icon.name, etc., will be updated by their direct bindings.
            statusBarLabel.text = connected && backend ? "Connected to " + backend.currentSerialPort : "Disconnected";
        }
        function onAvailableSerialPortsChanged() {
            if (!backend) return; // Guard
            var currentPort = backend.currentSerialPort
            if (backend.availableSerialPorts && backend.availableSerialPorts.includes(currentPort)) {
                serialPortCombo.currentIndex = backend.availableSerialPorts.indexOf(currentPort)
            } else if (backend.availableSerialPorts && backend.availableSerialPorts.length > 0) {
                serialPortCombo.currentIndex = 0
                // backend.currentSerialPort = backend.availableSerialPorts[0]; // C++ should manage this if it's a Q_PROPERTY
            } else {
                serialPortCombo.currentIndex = -1
            }
        }
    }

    Pane { // Header Pane
        id: header
        width: parent.width
        implicitHeight: headerContentRow.implicitHeight + padding * 2 
        background: Rectangle { color: currentPalette.paneBackground }
        padding: 10

        RowLayout {
            id: headerContentRow
            width: parent.width
            Label {
                id: headerLabel
                text: "PS5 NOR Modifier"
                font.bold: true
                font.pixelSize: 18
                color: currentPalette.text
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            ThemeToggleSwitch {
                id: themeToggle
                // Bind the switch's visual state to the application's isDarkMode property
                checked: root.isDarkMode 
                
                // When the switch is toggled internally (its 'checked' state changes and it emits 'toggled'),
                // we update the application's isDarkMode state.
                onToggled: {
                    console.log("Main.qml: ThemeToggleSwitch 'toggled' signal received.");
                    // The switch has already changed its internal 'checked' state.
                    // We align the application's isDarkMode with the switch's new state.
                    root.isDarkMode = themeToggle.checked; 
                    console.log("Main.qml: Set isDarkMode from themeToggle.checked: " + themeToggle.checked);
                }
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }
        }
    }

    ColumnLayout {
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 10
        spacing: 10

        Label {
            id: statusLabel
            text: backend ? backend.statusMessage : "Initializing..." // Guarded backend access
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            font.italic: true
            color: currentPalette.secondaryText
        }

        RowLayout {
            spacing: 2
            Repeater {
                model: ["File Operations", "Error Database", "Serial (UART)"]
                delegate: Button {
                    property int buttonIndex: index
                    text: modelData
                    icon.name: ["document-open", "help-faq", "preferences-system"][buttonIndex]
                    onClicked: currentTabIndex = buttonIndex
                    flat: currentTabIndex !== buttonIndex
                    highlighted: currentTabIndex === buttonIndex
                    Layout.preferredHeight: 40 // Standardized height
                    Layout.fillWidth: true

                    background: Rectangle {
                        color: parent.highlighted ? accentColor : "transparent"
                        border.color: parent.highlighted ? accentColor : (parent.hovered ? currentPalette.controlBorder : "transparent")
                        border.width: 1
                    }
                    contentItem: Label {
                        text: parent.text
                        color: parent.highlighted ? (isDarkMode ? accentColorTextOnDark : accentColorTextOnLight) : currentPalette.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        width: parent.width
                        height: 2
                        color: parent.highlighted ? accentColor : "transparent"
                        anchors.bottom: parent.bottom
                    }
                }
            }
        }

        StackLayout {
            id: mainContentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: currentTabIndex

            ColumnLayout {
                Layout.margins: 5
                spacing: 10

                RowLayout {
                    spacing: 10
                    StyledButton {
                        text: "Open .bin File"
                        icon.name: "document-open-symbolic"
                        onClicked: openFileDialog.open()
                        Layout.preferredWidth: 160 // Adjusted width slightly for new padding
                        Layout.preferredHeight: 40 // Standardized height
                        buttonStyle: "primary" // Apply "primary" style
                        buttonStyles: root.buttonStyles // Pass the styles map
                    }
                    StyledButton {
                        text: "Save .bin File"
                        icon.name: "document-save-symbolic"
                        enabled: fileContentArea.text !== ""
                        onClicked: saveFileDialog.open()
                        Layout.preferredWidth: 160 // Adjusted width slightly
                        Layout.preferredHeight: 40 // Standardized height
                        buttonStyle: "secondary" // Apply "secondary" style
                        buttonStyles: root.buttonStyles // Pass the styles map
                    }
                }
                Label {
                    text: "File Path: " + (currentFilePath ? currentFilePath : "No file opened")
                    font.bold: true
                    color: currentPalette.text
                }
                Label {
                    text: "File Size: " + fileSize
                    color: currentPalette.text
                }
                Label {
                    text: "Console Model: " + consoleModel
                    color: currentPalette.text
                }
                Label {
                    text: "Mobo Serial: " + motherboardSerial
                    color: currentPalette.text
                }
                Label {
                    text: "Board Serial: " + boardSerial
                    color: currentPalette.text
                }
                Label {
                    text: "WiFi MAC: " + wifiMac
                    color: currentPalette.text
                }
                Label {
                    text: "LAN MAC: " + lanMac
                    color: currentPalette.text
                }
                Label {
                    text: "Board Variant: " + boardVariant
                    color: currentPalette.text
                }
                
                Label {
                    text: "File Content (Hex View):"
                    font.bold: true
                    color: currentPalette.text
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
                    color: currentPalette.text
                    placeholderTextColor: currentPalette.placeholderText
                    background: Rectangle {
                        color: currentPalette.textAreaBackground
                        border.color: currentPalette.controlBorder
                        border.width: 1
                        radius: 4
                    }
                }
            }

            ColumnLayout {
                Layout.margins: 5
                spacing: 10
                
                RowLayout {
                    spacing: 10
                    CheckBox {
                        id: useOfflineDbCheckBox
                        text: "Use Offline Database"
                        checked: useOfflineErrorDb
                        onCheckedChanged: useOfflineErrorDb = checked
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 3
                            border.color: parent.checked ? accentColor : currentPalette.controlBorder
                            color: parent.checked ? accentColor : "transparent"
                            Text {
                                text: "✔"
                                anchors.centerIn: parent
                                font.pixelSize: 12
                                color: parent.parent.checked ? accentColorTextOnLight : "transparent"
                                visible: parent.parent.checked
                            }
                        }
                        contentItem: Label {
                            text: parent.text
                            color: currentPalette.text
                            leftPadding: parent.indicator.width + parent.spacing
                            Layout.preferredHeight: 40 // Align height
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    StyledButton {
                        text: "Download/Update Error Database"
                        icon.name: "arrow-down"
                        onClicked: backend.downloadDatabaseAsync()
                        buttonStyle: "info" // Apply "info" style
                        buttonStyles: root.buttonStyles
                        Layout.preferredWidth: 280 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
                    }
                }

                GroupBox {
                    title: "Error Code Lookup"
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: currentPalette.cardBackground
                        border.color: currentPalette.controlBorder
                        border.width: 1
                        radius: 4
                    }
                    label: Label {
                        text: parent.title
                        color: currentPalette.text
                        padding: 5
                        font.bold: true
                    }
                    ColumnLayout {
                        spacing: 5
                        TextField {
                            id: errorCodeInput
                            placeholderText: "Enter Error Code (e.g., SU-101312-8)"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40 // Standardized height
                            Keys.onReturnPressed: parseErrorCodeButton.clicked()
                            color: currentPalette.text
                            placeholderTextColor: currentPalette.placeholderText
                            background: Rectangle {
                                color: currentPalette.controlBackground
                                border.color: parent.activeFocus ? currentPalette.controlFocusBorder : currentPalette.controlBorder
                                border.width: 1
                                radius: 4
                            }
                        }
                        StyledButton {
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
                            buttonStyle: "success" // Apply "success" style
                            buttonStyles: root.buttonStyles
                            Layout.preferredHeight: 40 // Standardized height
                        }
                        Label {
                            text: "Result:"
                            color: currentPalette.text
                        }
                        TextArea {
                            id: errorResultArea
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            readOnly: true
                            wrapMode: Text.WordWrap
                            placeholderText: "Parsed error description will appear here."
                            color: currentPalette.text
                            placeholderTextColor: currentPalette.placeholderText
                            background: Rectangle {
                                color: currentPalette.textAreaReadOnlyBackground
                                border.color: currentPalette.controlBorder
                                border.width: 1
                                radius: 4
                            }
                        }
                    }
                }
            }
            
            ColumnLayout { // Tab 3: Serial (UART)
                Layout.margins: 5
                spacing: 10

                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true
                    ComboBox {
                        id: serialPortCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40 // Standardized height
                        model: backend ? backend.availableSerialPorts : [] // Guarded
                        textRole: ""
                        currentIndex: (backend && backend.availableSerialPorts && typeof backend.currentSerialPort !== 'undefined') ? backend.availableSerialPorts.indexOf(backend.currentSerialPort) : -1
                        onActivated: (index) => {
                            if (backend && backend.availableSerialPorts && index !== -1 && index < backend.availableSerialPorts.length) {
                                backend.currentSerialPort = backend.availableSerialPorts[index];
                            }
                        }
                        background: Rectangle {
                            color: currentPalette.controlBackground
                            border.color: parent.activeFocus ? currentPalette.controlFocusBorder : currentPalette.controlBorder
                            border.width: 1
                            radius: 4
                        }
                        contentItem: Label {
                            text: parent.displayText
                            color: currentPalette.text
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            padding: 5
                        }
                        popup.background: Rectangle {
                            color: currentPalette.paneBackground
                            border.color: currentPalette.controlBorder
                            radius: 4
                        }
                        delegate: ItemDelegate {
                            width: serialPortCombo.width
                            height: 35 // Dropdown item height can be slightly less or same
                            contentItem: Label {
                                text: modelData
                                color: currentPalette.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            highlighted: ListView.isCurrentItem
                            hoverEnabled: true
                            background: Rectangle {
                                color: highlighted ? accentColor : (hovered ? currentPalette.controlHover : "transparent")
                            }
                        }
                    }
                    StyledButton { 
                        text: "Refresh"
                        icon.name: "view-refresh"
                        onClicked: backend.refreshSerialPorts()
                        buttonStyles: root.buttonStyles // Uses "default" style
                        Layout.preferredWidth: 120 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
                    }
                    StyledButton {
                        id: connectButton
                        text: backend && backend.isSerialPortConnected ? "Disconnect" : "Connect"
                        icon.name: backend && backend.isSerialPortConnected ? "network-offline" : "network-wired"
                        enabled: backend && ( (serialPortCombo.currentIndex !== -1 && backend.availableSerialPorts && backend.availableSerialPorts.length > 0) || backend.isSerialPortConnected) 
                        onClicked: {
                            if (!backend) return;
                            if (backend.isSerialPortConnected) {
                                backend.disconnectSerialPort()
                            } else {
                                if (serialPortCombo.currentIndex !== -1) {
                                    backend.connectSerialPort()
                                } else {
                                    errorDialog.text = "Please select a serial port."
                                    errorDialog.title = "Serial Port Required"
                                    errorDialog.open()
                                }
                            }
                        }
                        buttonStyle: backend && backend.isSerialPortConnected ? "danger" : "success"
                        buttonStyles: root.buttonStyles
                        Layout.preferredWidth: 140 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
                    }
                }
                RowLayout {
                    spacing: 10
                    StyledButton {
                        text: "Read All Error Logs"
                        icon.name: "format-list-bulleted"
                        onClicked: {
                            serialOutputArea.append(">> Reading all error logs...\n")
                            backend.readAllErrorLogs()
                        }
                        buttonStyle: "info"
                        buttonStyles: root.buttonStyles
                        Layout.preferredWidth: 200 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
                    }
                    StyledButton {
                        text: "Clear Console Error Logs"
                        icon.name: "edit-clear"
                        onClicked: {
                            serialOutputArea.append(">> Clearing console error logs...\n")
                            backend.clearConsoleErrorLogs()
                        }
                        buttonStyle: "warning"
                        buttonStyles: root.buttonStyles
                        Layout.preferredWidth: 220 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
                    }
                }

                GroupBox {
                    title: "Send Command"
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: currentPalette.cardBackground
                        border.color: currentPalette.controlBorder
                        border.width: 1
                        radius: 4
                    }
                    label: Label {
                        text: parent.title
                        color: currentPalette.text
                        padding: 5
                        font.bold: true
                    }
                    ColumnLayout {
                        spacing: 5
                        TextField { // Command Input TextField
                            id: serialCommandInput
                            placeholderText: "Enter command (e.g., errlog 0)"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40 // Standardized height
                            enabled: backend && backend.isSerialPortConnected
                            Keys.onReturnPressed: sendSerialCommandButton.clicked()
                            color: currentPalette.text
                            placeholderTextColor: currentPalette.placeholderText
                            background: Rectangle {
                                color: currentPalette.controlBackground
                                border.color: parent.activeFocus ? currentPalette.controlFocusBorder : currentPalette.controlBorder
                                border.width: 1
                                radius: 4
                            }
                        }
                        StyledButton {
                            id: sendSerialCommandButton
                            text: "Send Command"
                            icon.name: "document-send"
                            enabled: backend && backend.isSerialPortConnected && serialCommandInput.text.trim() !== ""
                            onClicked: {
                                if (!backend) return;
                                var response = backend.sendSerialCommand(serialCommandInput.text.trim())
                                serialOutputArea.append(">> " + serialCommandInput.text.trim() + "\n")
                                serialOutputArea.append("<< " + response + "\n")
                            }
                            buttonStyle: "primary"
                            buttonStyles: root.buttonStyles
                            Layout.preferredWidth: 180 // Example width adjustment
                            Layout.preferredHeight: 40 // Standardized height
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Serial Output/Log:"
                        color: currentPalette.text
                        Layout.fillWidth: true
                    }
                    StyledButton {
                        text: "Clear Output"
                        icon.name: "edit-clear-all"
                        onClicked: serialOutputArea.clear()
                        buttonStyle: "secondary"
                        buttonStyles: root.buttonStyles
                        Layout.preferredWidth: 150 // Example width adjustment
                        Layout.preferredHeight: 40 // Standardized height
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
                    color: currentPalette.text
                    placeholderTextColor: currentPalette.placeholderText
                    background: Rectangle {
                        color: currentPalette.textAreaReadOnlyBackground
                        border.color: currentPalette.controlBorder
                        border.width: 1
                        radius: 4
                    }
                }
            }
        }
    }

    footer: Pane {
        id: statusBar
        implicitHeight: statusBarLabel.implicitHeight + 10
        width: parent.width
        background: Rectangle {
            color: currentPalette.paneBackground
        }
        padding: 5

        Label {
            id: statusBarLabel
            text: "Ready"
            anchors.verticalCenter: parent.verticalCenter
            color: currentPalette.statusBarText
        }
    }

    MenuBar {
        background: Rectangle {
            color: currentPalette.menuBarBackground
        }
        // Delegate for the top-level Menu titles (e.g., "Help")
        delegate: MenuItem {
            id: menuBarItem
            implicitHeight: 30
            background: Rectangle {
                color: menuBarItem.popup && menuBarItem.popup.visible ? accentColor : (menuBarItem.hovered ? currentPalette.menuItemHover : currentPalette.menuItemBackground)
            }
            contentItem: Label {
                text: menuBarItem.text
                color: menuBarItem.popup && menuBarItem.popup.visible ? (isDarkMode ? accentColorTextOnDark : accentColorTextOnLight) : currentPalette.text
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                rightPadding: 10
            }
        }

        Menu {
            title: "Help"
            background: Rectangle {
                color: currentPalette.paneBackground
                border.color: currentPalette.controlBorder
                radius: 4
            }
            delegate: MenuItem {
                implicitHeight: 30
                background: Rectangle {
                    color: control.highlighted ? accentColor : (control.hovered ? currentPalette.menuItemHover : currentPalette.menuItemBackground)
                }
                contentItem: Label {
                    text: control.text
                    color: control.highlighted ? (isDarkMode ? accentColorTextOnDark : accentColorTextOnLight) : currentPalette.text
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    rightPadding: 10
                }
            }
            Action {
                text: "Donate to TheCod3r"
                onTriggered: Qt.openUrlExternally("https://www.streamelements.com/thecod3r/tip")
            }
            Action {
                text: "ConsoleFix.Shop"
                onTriggered: Qt.openUrlExternally("https://www.consolefix.shop")
            }
        }
    }
}
