#include "TrimJob.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

namespace {

constexpr qsizetype kStderrTailBytes = 4096;

QString seconds(double value)
{
    return QString::number(value, 'f', 6);
}

QString outputSuffix(const QString &input, TrimJob::Mode mode)
{
    const QString suffix = QFileInfo(input).suffix().toLower();
    if (mode == TrimJob::Fast)
        return suffix.isEmpty() ? QStringLiteral("mkv") : suffix;
    // Re-encoding uses H.264 and AAC, which fit in MKV or MP4 but not in
    // containers such as WebM or AVI.
    return suffix == QLatin1String("mkv") ? suffix : QStringLiteral("mp4");
}

} // namespace

TrimJob::TrimJob(QObject *parent)
    : QObject(parent)
{
}

TrimJob::~TrimJob()
{
    if (m_process) {
        m_process->disconnect(this);
        m_process->kill();
        m_process->waitForFinished(2000);
    }
}

void TrimJob::setSource(const QUrl &source)
{
    if (source == m_source)
        return;
    m_source = source;
    emit sourceChanged();
}

void TrimJob::setOutput(const QString &output)
{
    if (output == m_output)
        return;
    m_output = output;
    emit outputChanged();
}

void TrimJob::setInPoint(double seconds)
{
    if (qFuzzyCompare(seconds, m_inPoint))
        return;
    m_inPoint = seconds;
    emit inPointChanged();
}

void TrimJob::setOutPoint(double seconds)
{
    if (qFuzzyCompare(seconds, m_outPoint))
        return;
    m_outPoint = seconds;
    emit outPointChanged();
}

void TrimJob::setMode(Mode mode)
{
    if (mode == m_mode)
        return;
    m_mode = mode;
    emit modeChanged();
}

QString TrimJob::ffmpegPath()
{
    const QString exe = QStringLiteral("ffmpeg");
    const QString bundled = QStandardPaths::findExecutable(exe, {QCoreApplication::applicationDirPath()});
    if (!bundled.isEmpty())
        return bundled;
    return QStandardPaths::findExecutable(exe);
}

QString TrimJob::defaultOutputPath(const QString &input, Mode mode)
{
    const QFileInfo info(input);
    const QString dir = info.absolutePath();
    const QString base = info.completeBaseName() + QStringLiteral("_trim");
    const QString suffix = outputSuffix(input, mode);

    QString candidate = QDir(dir).filePath(base + QLatin1Char('.') + suffix);
    for (int n = 2; QFileInfo::exists(candidate); ++n)
        candidate = QDir(dir).filePath(QStringLiteral("%1_%2.%3").arg(base).arg(n).arg(suffix));
    return candidate;
}

QStringList TrimJob::arguments() const
{
    const QString input = m_source.isLocalFile() ? m_source.toLocalFile() : m_source.toString();
    const bool mkv = m_output.endsWith(QLatin1String(".mkv"), Qt::CaseInsensitive);
    const bool mp4Like = m_output.endsWith(QLatin1String(".mp4"), Qt::CaseInsensitive)
                         || m_output.endsWith(QLatin1String(".mov"), Qt::CaseInsensitive)
                         || m_output.endsWith(QLatin1String(".m4v"), Qt::CaseInsensitive);

    QStringList args{
        QStringLiteral("-hide_banner"), QStringLiteral("-nostdin"), QStringLiteral("-y"),
        QStringLiteral("-nostats"), QStringLiteral("-progress"), QStringLiteral("pipe:1"),
        // Seeking before -i is fast, and frame-exact when re-encoding.
        QStringLiteral("-ss"), seconds(m_inPoint),
        QStringLiteral("-i"), input,
        QStringLiteral("-t"), seconds(m_outPoint - m_inPoint),
        // Capital V skips cover art, which is stored as a video stream.
        QStringLiteral("-map"), QStringLiteral("0:V?"),
        QStringLiteral("-map"), QStringLiteral("0:a?"),
        QStringLiteral("-map_metadata"), QStringLiteral("0"),
    };

    if (m_mode == Fast) {
        args << QStringLiteral("-map") << QStringLiteral("0:s?")
             << QStringLiteral("-c") << QStringLiteral("copy")
             << QStringLiteral("-avoid_negative_ts") << QStringLiteral("make_zero");
    } else {
        args << QStringLiteral("-c:v") << QStringLiteral("libx264")
             << QStringLiteral("-preset") << QStringLiteral("veryfast")
             << QStringLiteral("-crf") << QStringLiteral("18")
             << QStringLiteral("-c:a") << QStringLiteral("aac")
             << QStringLiteral("-b:a") << QStringLiteral("192k");
        // MKV takes any subtitle format as-is; MP4 cannot hold most of them.
        if (mkv)
            args << QStringLiteral("-map") << QStringLiteral("0:s?") << QStringLiteral("-c:s") << QStringLiteral("copy");
        else
            args << QStringLiteral("-sn");
    }

    if (mp4Like)
        args << QStringLiteral("-movflags") << QStringLiteral("+faststart");

    args << m_output;
    return args;
}

void TrimJob::start()
{
    if (m_state == Running)
        return;

    setProgress(0);
    setErrorString({});
    m_stdoutBuffer.clear();
    m_stderrTail.clear();

    const QString input = m_source.toLocalFile();
    if (input.isEmpty() || !QFileInfo::exists(input)) {
        setErrorString(tr("The input file could not be found."));
        setState(Failed);
        emit finished();
        return;
    }
    if (m_outPoint - m_inPoint <= 0) {
        setErrorString(tr("The out point must be after the in point."));
        setState(Failed);
        emit finished();
        return;
    }
    const QString ffmpeg = ffmpegPath();
    if (ffmpeg.isEmpty()) {
        setErrorString(tr("FFmpeg was not found. Install it or place it next to the app."));
        setState(Failed);
        emit finished();
        return;
    }
    if (m_output.isEmpty())
        setOutput(defaultOutputPath(input, m_mode));

    m_process = new QProcess(this);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &TrimJob::readProgress);
    connect(m_process, &QProcess::readyReadStandardError, this, [this] {
        m_stderrTail += m_process->readAllStandardError();
        if (m_stderrTail.size() > kStderrTailBytes)
            m_stderrTail = m_stderrTail.right(kStderrTailBytes);
    });
    connect(m_process, &QProcess::finished, this, &TrimJob::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            onProcessFinished(-1, QProcess::CrashExit);
    });

    setState(Running);
    m_process->start(ffmpeg, arguments());
}

void TrimJob::cancel()
{
    if (m_state != Running || !m_process)
        return;
    m_process->disconnect(this);
    m_process->kill();
    m_process->waitForFinished(2000);
    m_process->deleteLater();
    QFile::remove(m_output);
    setState(Cancelled);
    emit finished();
}

void TrimJob::reset()
{
    if (m_state == Running)
        return;
    setProgress(0);
    setErrorString({});
    setOutput({});
    setState(Idle);
}

QUrl TrimJob::outputFolderUrl() const
{
    return QUrl::fromLocalFile(QFileInfo(m_output).absolutePath());
}

void TrimJob::readProgress()
{
    m_stdoutBuffer += m_process->readAllStandardOutput();
    const double length = m_outPoint - m_inPoint;
    qsizetype newline;
    while ((newline = m_stdoutBuffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_stdoutBuffer.left(newline).trimmed();
        m_stdoutBuffer.remove(0, newline + 1);
        if (line.startsWith("out_time_us=")) {
            bool ok = false;
            const qint64 us = line.mid(12).toLongLong(&ok);
            if (ok && length > 0)
                setProgress(qBound(0.0, us / 1e6 / length, 1.0));
        }
    }
}

void TrimJob::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    if (m_state != Running)
        return;
    if (m_process)
        m_process->deleteLater();

    if (status == QProcess::NormalExit && exitCode == 0) {
        setProgress(1);
        setState(Finished);
    } else {
        QString detail = QString::fromUtf8(m_stderrTail).trimmed();
        const QStringList lines = detail.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        detail = lines.mid(qMax(0, lines.size() - 3)).join(QLatin1Char('\n'));
        if (exitCode == -1 && detail.isEmpty())
            detail = tr("FFmpeg could not be started.");
        setErrorString(detail.isEmpty() ? tr("FFmpeg exited with code %1.").arg(exitCode) : detail);
        QFile::remove(m_output);
        setState(Failed);
    }
    emit finished();
}

void TrimJob::setState(State state)
{
    if (state == m_state)
        return;
    m_state = state;
    emit stateChanged();
}

void TrimJob::setProgress(double progress)
{
    if (qFuzzyCompare(progress, m_progress))
        return;
    m_progress = progress;
    emit progressChanged();
}

void TrimJob::setErrorString(const QString &error)
{
    if (error == m_errorString)
        return;
    m_errorString = error;
    emit errorStringChanged();
}
