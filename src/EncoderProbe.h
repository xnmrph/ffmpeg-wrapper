#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <functional>

// Finds FFmpeg and works out which encoders actually run on this machine:
// software encoders count if FFmpeg was built with them, GPU encoders only if
// a short test encode succeeds.
class EncoderProbe : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool probing READ probing NOTIFY probingChanged)
    Q_PROPERTY(bool ffmpegFound READ ffmpegFound NOTIFY resultsChanged)
    Q_PROPERTY(QString ffmpegPath READ ffmpegPath NOTIFY resultsChanged)
    Q_PROPERTY(QString ffmpegVersion READ ffmpegVersion NOTIFY resultsChanged)
    // [{ id, label, gpu, available }] in Encoders::all() order.
    Q_PROPERTY(QVariantList encoders READ encoders NOTIFY resultsChanged)

public:
    explicit EncoderProbe(QObject *parent = nullptr);
    ~EncoderProbe() override;

    bool probing() const { return m_probing; }
    bool ffmpegFound() const { return !m_ffmpegPath.isEmpty(); }
    QString ffmpegPath() const { return m_ffmpegPath; }
    QString ffmpegVersion() const { return m_ffmpegVersion; }
    QVariantList encoders() const;
    QStringList available() const { return m_available; }

    Q_INVOKABLE void probe();
    Q_INVOKABLE bool isAvailable(const QString &id) const { return m_available.contains(id); }

signals:
    void probingChanged();
    void resultsChanged();
    void finished();

private:
    void runStep();
    void finish();
    void startProcess(const QStringList &args, std::function<void(int, const QByteArray &)> done);

    bool m_probing = false;
    QString m_ffmpegPath;
    QString m_ffmpegVersion;
    QStringList m_built;     // encoders this FFmpeg was built with
    QStringList m_toTest;    // GPU encoders still to try
    QStringList m_available; // encoders that work here
    QPointer<QProcess> m_process;
};
