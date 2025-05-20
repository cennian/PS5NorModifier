import QtQuick
import QtQuick.Controls // For potential future integration, not strictly needed for this visual-only component
import QtQuick.Layouts

Item {
    id: root

    property bool checked: false 
    onCheckedChanged: {
        console.log("ThemeToggleSwitch [ID:" + root + "]: root.checked property CHANGED to: " + root.checked);
    }
    property alias isDarkMode: root.checked 
    
    property color lightModeTrackColor: "#E9E9EA"
    property color darkModeTrackColor: "#2C2C2E" 
    property color thumbColor: "#FFFFFF" 
    property color darkThumbColor: "#48484A" 
    property color lightModeTextColor: "#8A8A8E"
    property color darkModeTextColor: "#8A8A8E" 
    property color lightModeIconColor: "#8A8A8E"
    property color darkModeIconColor: "#8A8A8E"

    implicitWidth: 180 
    implicitHeight: 40  

    signal toggled()

    // Visual part of the switch
    Rectangle { 
        id: track
        anchors.fill: parent // Track fills the root Item
        radius: height / 2
        color: {
            // console.log("ThemeToggleSwitch [ID:" + root + "]: Track color re-evaluated. root.checked: " + root.checked);
            return root.checked ? darkModeTrackColor : lightModeTrackColor;
        }
        
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 0 

            Item {
                id: lightModeContent
                Layout.fillHeight: true
                Layout.preferredWidth: (contentLayout.width - thumb.width) / 2 
                opacity: {
                    // console.log("ThemeToggleSwitch [ID:" + root + "]: lightModeContent opacity re-evaluated. root.checked: " + root.checked);
                    return root.checked ? 0 : 1;
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    Label {
                        id: sunIcon
                        text: "☀️" 
                        font.pixelSize: parent.height * 0.4 
                        color: lightModeIconColor
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        text: "LIGHT" 
                        font.bold: true
                        font.pixelSize: parent.height * 0.35 
                        color: lightModeTextColor
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            
            Item {
                id: thumbSpacer 
                Layout.preferredWidth: thumb.width
                Layout.fillHeight: true
            }

            Item {
                id: darkModeContent
                Layout.fillHeight: true
                Layout.preferredWidth: (contentLayout.width - thumb.width) / 2 
                opacity: {
                    // console.log("ThemeToggleSwitch [ID:" + root + "]: darkModeContent opacity re-evaluated. root.checked: " + root.checked);
                    return root.checked ? 1 : 0;
                }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                     Label {
                        text: "DARK" 
                        font.bold: true
                        font.pixelSize: parent.height * 0.35 
                        color: darkModeTextColor
                        verticalAlignment: Text.AlignVCenter
                    }
                    Label {
                        id: moonIcon
                        text: "🌙" 
                        font.pixelSize: parent.height * 0.4 
                        color: darkModeIconColor
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        
        Rectangle { 
            id: thumb
            width: track.height - 8 
            height: width 
            radius: width / 2
            color: root.checked ? darkThumbColor : thumbColor
            anchors.verticalCenter: parent.verticalCenter
            x: {
                // console.log("ThemeToggleSwitch [ID:" + root + "]: Thumb x re-evaluated. root.checked: " + root.checked);
                return root.checked ? (track.width - width - 4) : 4;
            }
            
            Behavior on x { SmoothedAnimation { duration: 200; velocity: 500 } }
            Behavior on color { ColorAnimation { duration: 200 } }

            Label {
                anchors.centerIn: parent
                text: root.checked ? moonIcon.text : sunIcon.text
                font.pixelSize: parent.height * 0.6 
                color: root.checked ? darkModeIconColor : lightModeIconColor
            }
        }
    }

    // Interactive Layer - ensure this is the last child of 'root' or has a higher z-order
    MouseArea {
        id: interactionArea // Given an ID for clarity
        anchors.fill: parent // Fills the entire root Item
        
        onClicked: {
            console.log("ThemeToggleSwitch [ID:" + root + "]: MouseArea onClicked. Current root.checked: " + root.checked);
            root.checked = !root.checked; // This should trigger onCheckedChanged and visual updates
            console.log("ThemeToggleSwitch [ID:" + root + "]: MouseArea onClicked. New root.checked: " + root.checked);
            root.toggled(); // Emit the signal that Main.qml listens to
            console.log("ThemeToggleSwitch [ID:" + root + "]: 'toggled' signal emitted.");
        }
        onPressedChanged: { // For detailed click debugging
            if (pressed) {
                console.log("ThemeToggleSwitch [ID:" + root + "]: MouseArea pressed at (" + mouseX + "," + mouseY + ")");
            } else {
                console.log("ThemeToggleSwitch [ID:" + root + "]: MouseArea released.");
            }
        }
    }
}
