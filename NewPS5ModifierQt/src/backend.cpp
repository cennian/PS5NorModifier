#include "backend.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QXmlStreamReader>
#include <QIODevice>
#include <QTextStream> // For reading file content as hex
#include <QRegularExpression> // For hex string manipulation
#include <QUrlQuery> // Ensure this line is present and processed

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
            emit databaseDownloadFinished(true);
        } else {
            setStatusMessage("Error: Could not save database file: " + file.errorString());
            emit errorOccurred("Database Save Error", "Could not save database file: " + file.errorString());
            emit databaseDownloadFinished(false);
        }
    } else {
        setStatusMessage("Error downloading database: " + reply->errorString());
        emit errorOccurred("Download Error", "Error downloading database: " + reply->errorString());
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

// Helper function to parse NOR details (stubbed)
QVariantMap Backend::parseNorDetails(const QByteArray &fileData) {
    QVariantMap details;
    // Placeholder values - actual parsing logic is complex and hardware-specific
    // This logic would replicate the C# version's offset reading and string conversions.
    details["model"] = "Unknown (Parsing not implemented)";
    details["moboSerial"] = "Unknown (Parsing not implemented)";
    details["boardSerial"] = "Unknown (Parsing not implemented)";
    details["wifiMac"] = "Unknown (Parsing not implemented)";
    details["lanMac"] = "Unknown (Parsing not implemented)";
    details["variant"] = "Unknown (Parsing not implemented)";
    details["size"] = QString("%1 bytes (%2MB)").arg(fileData.size()).arg(fileData.size() / 1024.0 / 1024.0, 0, 'f', 2);

    return details;
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
        return "";
    }

    QByteArray fileData = file.readAll();
    file.close();

    QString hexData = QString(fileData.toHex(' ')); // Space separated hex
    QVariantMap details = parseNorDetails(fileData);
    
    setStatusMessage("File opened successfully: " + cleanFilePath);
    emit fileOpened(cleanFilePath, hexData, details); // Emit with details
    return hexData;
}

// Helper function to apply NOR modifications (stubbed)
QByteArray Backend::applyNorModifications(QByteArray originalData, const QVariantMap &modifications) {
    qDebug() << "applyNorModifications called with: " << modifications;
    setStatusMessage("NOR modification logic not fully implemented in backend.");
    return originalData; 
}

bool Backend::saveModifiedFile(const QString &filePathToSave, const QString &originalFilePath, const QVariantMap &modifications)
{
    QString cleanFilePathToSave = filePathToSave;
    if (cleanFilePathToSave.startsWith("file:///")) {
        cleanFilePathToSave = QUrl(filePathToSave).toLocalFile();
    }

    QString cleanOriginalFilePath = originalFilePath;
     if (cleanOriginalFilePath.startsWith("file:///")) {
        cleanOriginalFilePath = QUrl(originalFilePath).toLocalFile();
    }

    QFile origFile(cleanOriginalFilePath);
    if (!origFile.open(QIODevice::ReadOnly)) {
        setStatusMessage("Error: Could not open original file for reading: " + origFile.errorString());
        emit errorOccurred("File Error", "Could not open original file: " + origFile.errorString());
        return false;
    }
    QByteArray originalData = origFile.readAll();
    origFile.close();

    QByteArray modifiedData = applyNorModifications(originalData, modifications);

    QFile file(cleanFilePathToSave);
    if (!file.open(QIODevice::WriteOnly)) {
        setStatusMessage("Error: Could not open file for writing: " + file.errorString());
        emit errorOccurred("File Error", "Could not open file for writing: " + file.errorString());
        return false;
    }

    if (file.write(modifiedData) == -1) {
        setStatusMessage("Error: Could not write to file: " + file.errorString());
        emit errorOccurred("File Error", "Could not write to file: " + file.errorString());
        file.close();
        return false;
    }

    file.close();
    setStatusMessage("File saved successfully with modifications: " + cleanFilePathToSave);
    return true;
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

QString Backend::parseErrorsOnline(const QString &errorCode) {
    if (errorCode.isEmpty()) {
        emit errorOccurred("Input Error", "Error code cannot be empty.");
        return "Error: Empty error code"; 
    }
    QUrl url("http://uartcodes.com/xml.php");
    QUrlQuery query; // This requires <QUrlQuery> to be included
    query.addQueryItem("errorCode", errorCode);
    url.setQuery(query);

    QNetworkRequest request(url);
    setStatusMessage("Fetching online description for " + errorCode + "...");
    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, errorCode]() {
        onOnlineErrorCheckFinished(reply);
    });
    return "Fetching description..."; 
}

void Backend::onOnlineErrorCheckFinished(QNetworkReply *reply) {
    QString resultText;
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        QXmlStreamReader xml(data);
        QString description = "Description not found or error parsing response.";
        
        // Construct QUrlQuery from the reply URL's query string
        QUrlQuery query(reply->url().query());
        QString parsedErrorCode = query.queryItemValue("errorCode"); 

        bool inErrorCodeOuter = false;
        QString currentCode, currentDesc;

        while (!xml.atEnd() && !xml.hasError()) {
            QXmlStreamReader::TokenType token = xml.readNext();
            if (token == QXmlStreamReader::StartElement) {
                if (xml.name().toString() == "errorCodes") { // Root
                    // continue
                } else if (xml.name().toString() == "errorCode") {
                    inErrorCodeOuter = true;
                    currentCode.clear();
                    currentDesc.clear();
                } else if (inErrorCodeOuter && xml.name().toString() == "ErrorCode") {
                    currentCode = xml.readElementText();
                } else if (inErrorCodeOuter && xml.name().toString() == "Description") {
                    currentDesc = xml.readElementText();
                }
            } else if (token == QXmlStreamReader::EndElement) {
                if (xml.name().toString() == "errorCode") {
                    if (currentCode == parsedErrorCode || parsedErrorCode.isEmpty()) { // If only one result, it's ours
                        description = currentDesc;
                        // If parsedErrorCode was empty and we got a code, update it
                        if (parsedErrorCode.isEmpty() && !currentCode.isEmpty()) parsedErrorCode = currentCode;
                        break; 
                    }
                    inErrorCodeOuter = false;
                }
            }
        }
        if (xml.hasError()) {
            description = "Error parsing XML response: " + xml.errorString();
        }
        resultText = "Error code: " + parsedErrorCode + "\nDescription: " + description;
        setStatusMessage("Online check for " + parsedErrorCode + " complete.");
    } else {
        resultText = "Error fetching online description: " + reply->errorString();
        setStatusMessage(resultText);
    }
    emit onlineErrorResultReady(resultText);
    reply->deleteLater();
}

void Backend::readAllErrorLogs() {
    if (!m_serialPort->isOpen()) {
        setStatusMessage("Serial port not connected.");
        emit errorOccurred("Serial Command Error", "Serial port is not connected.");
        emit allErrorLogsData("Error: Not connected");
        return;
    }
    QString aggregatedLogs = "Reading all error logs:\n";
    bool anErrorOccurred = false;

    for (int i = 0; i <= 10; ++i) {
        QString command = QString("errlog %1").arg(i);
        QString response = sendSerialCommand(command); // sendSerialCommand is blocking
        aggregatedLogs += QString("Cmd: %1 -> Response: %2\n").arg(command).arg(response);
        if (response.startsWith("Error:")) {
            anErrorOccurred = true;
        }
    }
    setStatusMessage(anErrorOccurred ? "Finished reading logs with some errors." : "Finished reading all error logs.");
    emit allErrorLogsData(aggregatedLogs);
}

void Backend::clearConsoleErrorLogs() {
    if (!m_serialPort->isOpen()) {
        setStatusMessage("Serial port not connected.");
        emit errorOccurred("Serial Command Error", "Serial port is not connected.");
        emit consoleErrorLogsCleared("Error: Not connected");
        return;
    }
    QString response = sendSerialCommand("errlog clear");
    setStatusMessage("Clear error logs command sent. Response: " + response);
    emit consoleErrorLogsCleared(response);
}
