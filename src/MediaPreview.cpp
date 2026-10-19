#include "MediaPreview.h"

#include "TrimJob.h"

#include <QCryptographicHash>
#include <QDataStream>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTimer>
#include <QtEndian>

namespace {

// Audio is decoded to mono at this rate just for drawing; plenty for peaks.
constexpr int kWaveformSampleRate = 4000;
constexpr int kMaxParallelThumbnails = 3;

QString seconds(double value)
{
    return QString::number(value, 'f', 3);
}

} // namespace

MediaPreview::MediaPreview(QObject *parent)
    : QObject(parent)
{
}

MediaPreview::~MediaPreview()
{
    stopAll();
}

void MediaPreview::setSource(const QUrl &source)
{
    if (source == m_source)
        return;
    m_source = source;
    emit sourceChanged();
    restart();
}

void MediaPreview::setDuration(double duration)
{
    if (qFuzzyCompare(duration, m_duration))
        return;
    m_duration = duration;
    emit durationChanged();
    restart();
}

void MediaPreview::setThumbnailCount(int count)
{
    count = qBound(1, count, 200);
    if (count == m_thumbnailCount)
        return;
    m_thumbnailCount = count;
    emit thumbnailCountChanged();
    restart();
}

QString MediaPreview::cacheDirFor(const QString &path)
{
    const QFileInfo info(path);
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(info.absoluteFilePath().toUtf8());
    hash.addData(QByteArray::number(info.size()));
    hash.addData(QByteArray::number(info.lastModified().toMSecsSinceEpoch()));
    const QString root = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return QDir(root).filePath(QStringLiteral("previews/") + QString::fromLatin1(hash.result().toHex().left(20)));
}

void MediaPreview::restart()
{
    // Source and duration usually change together; regenerate once.
    if (m_restartQueued)
        return;
    m_restartQueued = true;
    QTimer::singleShot(0, this, [this] {
        m_restartQueued = false;
        stopAll();

        m_thumbnails = QStringList(m_thumbnailCount, QString());
        m_peaks.clear();
        m_pendingThumbs.clear();
        emit thumbnailsChanged();
        emit peaksChanged();

        const QString path = m_source.toLocalFile();
        if (path.isEmpty() || m_duration <= 0 || TrimJob::ffmpegPath().isEmpty() || !QFileInfo::exists(path)) {
            emit loadingChanged();
            return;
        }
        m_cacheDir = cacheDirFor(path);
        QDir().mkpath(m_cacheDir);

        for (int i = 0; i < m_thumbnailCount; ++i) {
            const QString file = QDir(m_cacheDir).filePath(QStringLiteral("t%1_%2.jpg").arg(m_thumbnailCount).arg(i));
            if (QFileInfo(file).size() > 0)
                m_thumbnails[i] = QUrl::fromLocalFile(file).toString();
            else
                m_pendingThumbs << i;
        }
        emit thumbnailsChanged();

        startWaveform();
        startNextThumbnails();
        emit loadingChanged();
    });
}

void MediaPreview::stopAll()
{
    for (const QPointer<QProcess> &process : std::as_const(m_processes)) {
        if (process) {
            process->disconnect(this);
            process->kill();
            process->waitForFinished(500);
            process->deleteLater();
        }
    }
    m_processes.clear();
    m_running = 0;
    m_pendingThumbs.clear();
    m_pcm.clear();
}

QProcess *MediaPreview::launch(const QStringList &args)
{
    auto *process = new QProcess(this);
    m_processes << process;
    ++m_running;
    connect(process, &QProcess::finished, this, [this, process] { processFinished(process); });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            processFinished(process);
    });
    process->start(TrimJob::ffmpegPath(), args);
    return process;
}

void MediaPreview::processFinished(QProcess *process)
{
    if (!m_processes.contains(process))
        return;
    m_processes.removeAll(process);
    --m_running;
    process->deleteLater();
    startNextThumbnails();
    emit loadingChanged();
}

void MediaPreview::startNextThumbnails()
{
    const QString path = m_source.toLocalFile();
    while (!m_pendingThumbs.isEmpty() && m_running < kMaxParallelThumbnails + 1) {
        const int index = m_pendingThumbs.takeFirst();
        const double t = m_duration * (index + 0.5) / m_thumbnailCount;
        const QString file = QDir(m_cacheDir).filePath(QStringLiteral("t%1_%2.jpg").arg(m_thumbnailCount).arg(index));
        QProcess *process = launch({
            QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error"),
            QStringLiteral("-ss"), seconds(t), QStringLiteral("-i"), path,
            QStringLiteral("-frames:v"), QStringLiteral("1"), QStringLiteral("-an"), QStringLiteral("-sn"),
            QStringLiteral("-vf"), QStringLiteral("scale=-2:%1").arg(kThumbnailHeight),
            QStringLiteral("-q:v"), QStringLiteral("5"), QStringLiteral("-y"), file,
        });
        connect(process, &QProcess::finished, this, [this, index, file](int exitCode) {
            if (exitCode == 0 && QFileInfo(file).size() > 0 && index < m_thumbnails.size()) {
                m_thumbnails[index] = QUrl::fromLocalFile(file).toString();
                emit thumbnailsChanged();
            }
        });
    }
}

void MediaPreview::startWaveform()
{
    const QString cacheFile = QDir(m_cacheDir).filePath(QStringLiteral("peaks.bin"));
    QFile cached(cacheFile);
    if (cached.open(QIODevice::ReadOnly)) {
        QDataStream in(&cached);
        QList<qreal> peaks;
        in >> peaks;
        if (in.status() == QDataStream::Ok) {
            m_peaks = peaks;
            emit peaksChanged();
            return;
        }
    }

    m_pcm.clear();
    m_samplesSeen = 0;
    m_peakAccumulator = QList<float>(kPeakCount, 0.0f);
    const qint64 expectedSamples = qMax<qint64>(1, qint64(m_duration * kWaveformSampleRate));

    QProcess *process = launch({
        QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error"),
        QStringLiteral("-i"), m_source.toLocalFile(),
        QStringLiteral("-map"), QStringLiteral("0:a:0"), QStringLiteral("-vn"), QStringLiteral("-sn"),
        QStringLiteral("-ac"), QStringLiteral("1"), QStringLiteral("-ar"), QString::number(kWaveformSampleRate),
        QStringLiteral("-f"), QStringLiteral("s16le"), QStringLiteral("-"),
    });
    const auto consume = [this, process, expectedSamples] {
        m_pcm += process->readAllStandardOutput();
        const qsizetype usable = m_pcm.size() & ~qsizetype(1);
        const auto *samples = reinterpret_cast<const uchar *>(m_pcm.constData());
        for (qsizetype i = 0; i < usable; i += 2) {
            const qint16 s = qFromLittleEndian<qint16>(samples + i);
            const int bucket = int(qMin<qint64>(kPeakCount - 1, m_samplesSeen * kPeakCount / expectedSamples));
            const float level = qAbs(float(s)) / 32768.0f;
            if (level > m_peakAccumulator[bucket])
                m_peakAccumulator[bucket] = level;
            ++m_samplesSeen;
        }
        m_pcm.remove(0, usable);
    };
    connect(process, &QProcess::readyReadStandardOutput, this, consume);
    connect(process, &QProcess::finished, this, [this, cacheFile, consume](int exitCode) {
        consume();
        if (exitCode != 0 || m_samplesSeen == 0)
            return; // no audio stream
        m_peaks.clear();
        m_peaks.reserve(kPeakCount);
        for (float p : std::as_const(m_peakAccumulator))
            m_peaks << p;
        emit peaksChanged();

        QFile out(cacheFile);
        if (out.open(QIODevice::WriteOnly)) {
            QDataStream stream(&out);
            stream << m_peaks;
        }
    });
}
