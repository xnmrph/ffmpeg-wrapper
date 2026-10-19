#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// One FFmpeg trim of one input file. Used directly for single-video mode and,
// in folder mode, as an entry in the export queue.
class TrimJob : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString output READ output WRITE setOutput NOTIFY outputChanged)
    Q_PROPERTY(double inPoint READ inPoint WRITE setInPoint NOTIFY inPointChanged)
    Q_PROPERTY(double outPoint READ outPoint WRITE setOutPoint NOTIFY outPointChanged)
    Q_PROPERTY(Mode mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    enum Mode {
        Fast,     // stream copy: lossless and quick, but cuts snap to keyframes
        Accurate, // re-encode: frame-exact cuts, slower
    };
    Q_ENUM(Mode)

    enum State { Idle, Running, Finished, Failed, Cancelled };
    Q_ENUM(State)

    explicit TrimJob(QObject *parent = nullptr);
    ~TrimJob() override;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    QString output() const { return m_output; }
    void setOutput(const QString &output);
    double inPoint() const { return m_inPoint; }
    void setInPoint(double seconds);
    double outPoint() const { return m_outPoint; }
    void setOutPoint(double seconds);
    Mode mode() const { return m_mode; }
    void setMode(Mode mode);
    State state() const { return m_state; }
    bool running() const { return m_state == Running; }
    double progress() const { return m_progress; }
    QString errorString() const { return m_errorString; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void cancel();
    // Folder containing the output, for "Show in folder".
    Q_INVOKABLE QUrl outputFolderUrl() const;

    // The FFmpeg arguments for the current settings (output must be set).
    QStringList arguments() const;

    // FFmpeg next to the app binary wins over one on PATH, so packaged builds
    // use the bundled copy.
    static QString ffmpegPath();
    // "<name>_trim.<ext>" beside the input, numbered if that already exists.
    static QString defaultOutputPath(const QString &input, Mode mode);

signals:
    void sourceChanged();
    void outputChanged();
    void inPointChanged();
    void outPointChanged();
    void modeChanged();
    void stateChanged();
    void progressChanged();
    void errorStringChanged();
    void finished();

private:
    void setState(State state);
    void setProgress(double progress);
    void setErrorString(const QString &error);
    void readProgress();
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);

    QUrl m_source;
    QString m_output;
    double m_inPoint = 0;
    double m_outPoint = 0;
    Mode m_mode = Fast;
    State m_state = Idle;
    double m_progress = 0;
    QString m_errorString;
    QPointer<QProcess> m_process;
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrTail;
};
