#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QFile>
#include <QXmlStreamReader> 
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QStringList>
#include <QUrl> 
#include <QVariantMap> 

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
    Q_INVOKABLE QString parseErrorsOnline(const QString &errorCode); 
    Q_INVOKABLE QString openFile(const QString &filePath); 
    Q_INVOKABLE bool saveFile(const QString &filePath, const QString &hexData); 
    Q_INVOKABLE bool saveModifiedFile(const QString &filePath, const QString &originalFilePath, const QVariantMap &modifications); 

    Q_INVOKABLE void refreshSerialPorts();
    Q_INVOKABLE bool connectSerialPort(); 
    Q_INVOKABLE bool connectSerialPortByName(const QString &portName); 
    Q_INVOKABLE void disconnectSerialPort();
    Q_INVOKABLE QString sendSerialCommand(const QString &command); 
    Q_INVOKABLE void readAllErrorLogs(); 
    Q_INVOKABLE void clearConsoleErrorLogs(); 

signals:
    void statusMessageChanged();
    void databaseDownloadFinished(bool success);
    void availableSerialPortsChanged();
    void currentSerialPortChanged();
    void serialPortConnectedChanged(bool connected);
    void errorOccurred(const QString &title, const QString &message); 
    void fileOpened(const QString &fileName, const QString &fileContentHex, const QVariantMap &details); 
    void onlineErrorResultReady(const QString &result); 
    void allErrorLogsData(const QString &data); 
    void consoleErrorLogsCleared(const QString &result); 

private slots:
    void onDownloadFinished(QNetworkReply *reply);
    void onOnlineErrorCheckFinished(QNetworkReply *reply); 
    void handleSerialError(QSerialPort::SerialPortError error);
    void handleSerialDataReady(); 

private:
    QNetworkAccessManager *m_networkManager;
    QString m_statusMessage;
    QString m_localDatabaseFile; 
    QSerialPort *m_serialPort = nullptr;
    QStringList m_availableSerialPorts;
    QString m_currentSerialPort;

    void updateAvailableSerialPorts();
    QVariantMap parseNorDetails(const QByteArray &fileData); 
    QByteArray applyNorModifications(QByteArray originalData, const QVariantMap &modifications); 
};

#endif // BACKEND_H
