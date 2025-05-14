#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QXmlStreamReader> // Required for parseErrorsOffline
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QStringList>
#include <QUrl> // Required for QUrl::toLocalFile

class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString statusMessage READ statusMessage WRITE setStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString localDatabaseFile READ localDatabaseFile CONSTANT)
    Q_PROPERTY(QStringList availableSerialPorts READ availableSerialPorts NOTIFY availableSerialPortsChanged)
    Q_PROPERTY(QString currentSerialPort READ currentSerialPort WRITE setCurrentSerialPort NOTIFY currentSerialPortChanged)
    Q_PROPERTY(bool isSerialPortConnected READ isSerialPortConnected NOTIFY serialPortConnectedChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    QString statusMessage() const;
    void setStatusMessage(const QString &message);

    QString localDatabaseFile() const { return m_localDatabaseFile; }
    QStringList availableSerialPorts() const;
    QString currentSerialPort() const;
    void setCurrentSerialPort(const QString &portName);
    bool isSerialPortConnected() const;

    Q_INVOKABLE void downloadDatabaseAsync();
    Q_INVOKABLE QString parseErrorsOffline(const QString &errorCode);
    Q_INVOKABLE QString openFile(const QString &filePath); // Returns hex string or empty on error
    Q_INVOKABLE bool saveFile(const QString &filePath, const QString &hexData);
    Q_INVOKABLE void refreshSerialPorts();
    Q_INVOKABLE bool connectSerialPort(); // Connects to currentSerialPort
    Q_INVOKABLE bool connectSerialPortByName(const QString &portName); // Connects to a specific port
    Q_INVOKABLE void disconnectSerialPort();
    Q_INVOKABLE QString sendSerialCommand(const QString &command); // Returns response or error string

signals:
    void statusMessageChanged();
    void databaseDownloadFinished(bool success);
    void availableSerialPortsChanged();
    void currentSerialPortChanged();
    void serialPortConnectedChanged(bool connected);
    void errorOccurred(const QString &title, const QString &message); // For UX friendly errors
    void fileOpened(const QString &fileName, const QString &fileContentHex);

private slots:
    void onDownloadFinished(QNetworkReply *reply);
    void handleSerialError(QSerialPort::SerialPortError error);
    void handleSerialDataReady(); // For asynchronous data reading (optional for now)

private:
    QNetworkAccessManager *m_networkManager;
    QString m_statusMessage;
    QString m_localDatabaseFile; // Initialized in constructor
    QSerialPort *m_serialPort = nullptr;
    QStringList m_availableSerialPorts;
    QString m_currentSerialPort;

    void updateAvailableSerialPorts();
    // static QString calculateChecksum(const QString &str); // Helper for serial commands
};

#endif // BACKEND_H
