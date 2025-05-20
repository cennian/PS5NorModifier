cmake_minimum_required(VERSION 3.16)
project(PS5NorModifierQt VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network SerialPort Widgets QuickControls2)

qt_standard_project_setup()

qt_add_executable(PS5NorModifierApp
    src/main.cpp
    src/backend.cpp
    src/backend.h
)

qt_add_qml_module(PS5NorModifierApp
    URI PS5NorModifier
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/StyledButton.qml
        qml/ThemeToggleSwitch.qml
)

target_link_libraries(PS5NorModifierApp PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
    Qt6::SerialPort
    Qt6::Widgets
    Qt6::QuickControls2
)

install(TARGETS PS5NorModifierApp
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
