#include "backend.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QMessageBox> // For UX friendly error dialogs (can be replaced with QML popups)
#include <QXmlStreamReader>
#include <QIODevice>
#include <QTextStream> // For reading file content as hex

Backend::Backend(QObject *parent) : QObject(parent)
{
    m_networkManager = new QNetworkAccessManager(this);
    QString appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(appDataPath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    m_localDatabaseFile = dir.filePath("errorDB.xml");
    qDebug() << "Local database will be stored at:" << m_localDatabaseFile;

    m_serialPort = new QSerialPort(this);
    connect(m_serialPort, &QSerialPort::errorOccurred, this, &Backend::handleSerialError);
    connect(m_serialPort, &QSerialPort::readyRead, this, &Backend::handleSerialDataReady);

    updateAvailableSerialPorts(); // Initial population
}

QString Backend::statusMessage() const
{
    return m_statusMessage;
}

void Backend::setStatusMessage(const QString &message)
{
    if (m_statusMessage != message) {
        m_statusMessage = message;
        emit statusMessageChanged();
    }
}

QStringList Backend::availableSerialPorts() const
{
    return m_availableSerialPorts;
}

QString Backend::currentSerialPort() const
{
    return m_currentSerialPort;
}

void Backend::setCurrentSerialPort(const QString &portName)
{
    if (m_currentSerialPort != portName) {
        m_currentSerialPort = portName;
        emit currentSerialPortChanged();
    }
}

bool Backend::isSerialPortConnected() const
{
    return m_serialPort ? m_serialPort->isOpen() : false;
}

void Backend::updateAvailableSerialPorts()
{
    m_availableSerialPorts.clear();
    const auto infos = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &info : infos) {
        m_availableSerialPorts.append(info.portName());
    }
    emit availableSerialPortsChanged();
    if (!m_availableSerialPorts.isEmpty() && m_currentSerialPort.isEmpty()) {
        setCurrentSerialPort(m_availableSerialPorts.first());
    }
}

void Backend::refreshSerialPorts()
{
    updateAvailableSerialPorts();
    setStatusMessage("Serial ports refreshed.");
}

bool Backend::connectSerialPort()
{
    if (m_currentSerialPort.isEmpty()) {
        emit errorOccurred("Serial Port Error", "No serial port selected.");
        return false;
    }
    return connectSerialPortByName(m_currentSerialPort);
}

bool Backend::connectSerialPortByName(const QString &portName)
{
    if (m_serialPort->isOpen()) {
        if (m_serialPort->portName() == portName) {
            setStatusMessage("Already connected to " + portName);
            return true; // Already connected to this port
        }
        m_serialPort->close(); // Close if open on a different port
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(QSerialPort::Baud115200); // Common baud rate
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (m_serialPort->open(QIODevice::ReadWrite)) {
        setCurrentSerialPort(portName); // Update current port if different
        setStatusMessage("Connected to " + portName);
        emit serialPortConnectedChanged(true);
        return true;
    } else {
        setStatusMessage("Error connecting to " + portName + ": " + m_serialPort->errorString());
        emit errorOccurred("Serial Connection Failed", "Could not connect to " + portName + ": " + m_serialPort->errorString());
        emit serialPortConnectedChanged(false);
        return false;
    }
}

void Backend::disconnectSerialPort()
{
    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        setStatusMessage("Disconnected from serial port.");
        emit serialPortConnectedChanged(false);
    } else {
        setStatusMessage("No serial port is currently connected.");
    }
}

QString Backend::sendSerialCommand(const QString &command)
{
    if (!m_serialPort->isOpen()) {
        setStatusMessage("Serial port not connected.");
        emit errorOccurred("Serial Command Error", "Serial port is not connected.");
        return "Error: Not connected";
    }

    int sum = 0;
    for (QChar qc : command) {
        sum += qc.unicode();
    }
    QString checksum = QString::number(sum & 0xFF, 16).toUpper().rightJustified(2, '0');
    QString commandWithChecksum = command + ":" + checksum;

    qDebug() << "Sending serial command:" << commandWithChecksum;
    m_serialPort->write(commandWithChecksum.toUtf8() + "\n"); // Assuming commands are newline terminated
    
    if (m_serialPort->waitForBytesWritten(1000)) {
        if (m_serialPort->waitForReadyRead(3000)) { // Wait up to 3 seconds for a response
            QByteArray responseData = m_serialPort->readAll();
            while(m_serialPort->waitForReadyRead(100)){ // Keep reading if more data comes quickly
                responseData += m_serialPort->readAll();
            }
            QString response = QString::fromUtf8(responseData).trimmed();
            setStatusMessage("Command sent. Response: " + response);
            qDebug() << "Serial response:" << response;
            return response;
        } else {
            setStatusMessage("No response from serial device.");
            emit errorOccurred("Serial Command Error", "No response from serial device for command: " + command);
            return "Error: No response";
        }
    } else {
        setStatusMessage("Timeout writing to serial port.");
        emit errorOccurred("Serial Command Error", "Timeout writing to serial port for command: " + command);
        return "Error: Write timeout";
    }
}

void Backend::handleSerialError(QSerialPort::SerialPortError error)
{
    if (error != QSerialPort::NoError && error != QSerialPort::TimeoutError) { // TimeoutError might be frequent with waitForReadyRead
        QString errorMsg = "Serial port error: " + m_serialPort->errorString();
        setStatusMessage(errorMsg);
        emit errorOccurred("Serial Port Error", errorMsg);
    }
}

void Backend::handleSerialDataReady()
{
    // This slot is connected but sendSerialCommand uses blocking reads for now.
    // For a fully async approach, data reading logic would go here,
    // and sendSerialCommand would not block.
}

void Backend::downloadDatabaseAsync()
{
    QUrl url("http://uartcodes.com/xml.php"); // Same URL as in C#
    QNetworkRequest request(url);
    // request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true); // Allow redirects
    // In Qt 6, redirects are followed by default. If specific handling is needed,
    // it's done by checking the redirectionTarget attribute on the reply.
    // For now, we assume default behavior is sufficient.

    setStatusMessage("Downloading database...");
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onDownloadFinished(reply);
    });
}

void Backend::onDownloadFinished(QNetworkReply *reply)
{
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QFile file(m_localDatabaseFile);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(data);
            file.close();
            setStatusMessage("Offline database updated successfully.");
            QMessageBox::information(nullptr, "Offline Database Updated!", "The most recent offline database has been updated successfully.");
            emit databaseDownloadFinished(true);
        } else {
            setStatusMessage("Error: Could not save database file: " + file.errorString());
            QMessageBox::warning(nullptr, "Error", "Could not save database file: " + file.errorString());
            emit databaseDownloadFinished(false);
        }
    } else {
        setStatusMessage("Error downloading database: " + reply->errorString());
        QMessageBox::warning(nullptr, "Download Error", "Error downloading database: " + reply->errorString());
        emit databaseDownloadFinished(false);
    }
    reply->deleteLater();
}

QString Backend::parseErrorsOffline(const QString &errorCode)
{
    if (!QFile::exists(m_localDatabaseFile)) {
        setStatusMessage("Error: Local database file not found.");
        emit errorOccurred("Database Error", "Local database (errorDB.xml) not found. Please download it first.");
        return "Error: Local database file not found.";
    }

    QFile file(m_localDatabaseFile);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setStatusMessage("Error: Could not open local database file: " + file.errorString());
        emit errorOccurred("Database Error", "Could not open local database file: " + file.errorString());
        return "Error: Could not open local database file.";
    }

    QXmlStreamReader xml(&file);
    QString description = "Error code not found.";
    bool found = false;

    while (!xml.atEnd() && !xml.hasError()) {
        QXmlStreamReader::TokenType token = xml.readNext();
        if (token == QXmlStreamReader::StartElement) {
            if (xml.name().toString() == "errorCode") { // Assuming <errorCode> tag from C#
                QString currentErrorCode;
                QString currentDescription;
                while (!(xml.tokenType() == QXmlStreamReader::EndElement && xml.name().toString() == "errorCode")) {
                    if (xml.tokenType() == QXmlStreamReader::StartElement) {
                        if (xml.name().toString() == "ErrorCode") { // Tag from C#
                            xml.readNext();
                            currentErrorCode = xml.text().toString();
                        } else if (xml.name().toString() == "Description") { // Tag from C#
                            xml.readNext();
                            currentDescription = xml.text().toString();
                        }
                    }
                    xml.readNext();
                }
                if (currentErrorCode == errorCode) {
                    description = currentDescription;
                    found = true;
                    break;
                }
            }
        }
    }
    file.close();

    if (xml.hasError()) {
        setStatusMessage("Error parsing XML: " + xml.errorString());
        emit errorOccurred("Database Error", "Error parsing local database XML: " + xml.errorString());
        return "Error parsing XML.";
    }

    if (found) {
        setStatusMessage("Error code " + errorCode + " found: " + description);
        return "Error code: " + errorCode + "\nDescription: " + description;
    } else {
        setStatusMessage("Error code " + errorCode + " not found in local database.");
        return "Error code: " + errorCode + "\nDescription: Not found in local database.";
    }
}

QString Backend::openFile(const QString &filePath)
{
    QString cleanFilePath = filePath;
    if (cleanFilePath.startsWith("file:///")) {
        cleanFilePath = QUrl(filePath).toLocalFile();
    }

    QFile file(cleanFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        setStatusMessage("Error: Could not open file: " + file.errorString());
        emit errorOccurred("File Error", "Could not open file: " + file.errorString());
        return ""; // Return empty or error string
    }

    QByteArray fileData = file.readAll();
    file.close();

    QString hexData = QString(fileData.toHex(' ')); // Space separated hex
    
    setStatusMessage("File opened successfully: " + cleanFilePath);
    emit fileOpened(cleanFilePath, hexData);
    return hexData; // Or emit a signal with the content
}

bool Backend::saveFile(const QString &filePath, const QString &hexData)
{
    QString cleanFilePath = filePath;
    if (cleanFilePath.startsWith("file:///")) {
        cleanFilePath = QUrl(filePath).toLocalFile();
    }

    QFile file(cleanFilePath);
    if (!file.open(QIODevice::WriteOnly)) {
        setStatusMessage("Error: Could not open file for writing: " + file.errorString());
        emit errorOccurred("File Error", "Could not open file for writing: " + file.errorString());
        return false;
    }

    QString tempHex = hexData;
    tempHex.remove(' '); // Remove spaces if any
    QByteArray fileData = QByteArray::fromHex(tempHex.toUtf8());

    if (file.write(fileData) == -1) {
        setStatusMessage("Error: Could not write to file: " + file.errorString());
        emit errorOccurred("File Error", "Could not write to file: " + file.errorString());
        file.close();
        return false;
    }

    file.close();
    setStatusMessage("File saved successfully: " + cleanFilePath);
    return true;
}
