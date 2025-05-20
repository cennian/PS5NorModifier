import QtQuick
import QtQuick.Controls
import QtQuick.Layouts // For Layout attached properties

Button {
    id: control

    property string buttonStyle: "default" // e.g., "primary", "success", "danger"
    property var buttonStyles // This will be passed from Main.qml, containing all style definitions

    // Determine the current style definition based on buttonStyle, fallback to "default"
    // Main.qml's buttonStyles.default now correctly derives from root.currentPalette
    property var styleDefinition: buttonStyles && buttonStyles[buttonStyle] ? buttonStyles[buttonStyle] : (buttonStyles ? buttonStyles["default"] : {})
    
    // Extract colors and properties from the styleDefinition
    // These assume styleDefinition and its properties (like .background) are always valid
    // because Main.qml's buttonStyles (including "default") should provide them.
    property color baseColor: styleDefinition.background
    property color hoverColor: styleDefinition.hover
    property color pressedColor: styleDefinition.pressed
    property color textColor: styleDefinition.text
    property color borderColor: styleDefinition.border
    property real buttonRadius: 6 // Rounded corners as seen in the image

    background: Rectangle {
        color: control.down ? pressedColor : (control.hovered ? hoverColor : baseColor)
        border.color: borderColor
        border.width: 1 // Buttons in the image appear to have a 1px border or distinct edge
        radius: buttonRadius
    }

    contentItem: Label {
        text: control.text
        font: control.font
        color: control.textColor // Use the resolved textColor property from StyledButton
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        // Padding is now controlled by the Button's top/bottom/left/rightPadding
    }

    // Standardized padding
    leftPadding: 16
    rightPadding: 16
    topPadding: 8 
    bottomPadding: 8

    Layout.preferredHeight: 40 // Standardized height
    Layout.minimumWidth: 80 // Optional: ensure a minimum width for very short text
}
