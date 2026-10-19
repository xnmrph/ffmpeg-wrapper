#pragma once

#include <QList>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QStringList>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

// Timeline previews for one video: evenly spaced thumbnails and the audio
// waveform, made with FFmpeg in the background and cached on disk so going
// back to a video is instant.
class MediaPreview : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(double duration READ duration WRITE setDuration NOTIFY durationChanged)
    Q_PROPERTY(int thumbnailCount READ thumbnailCount WRITE setThumbnailCount NOTIFY thumbnailCountChanged)
    // One file URL per thumbnail, in time order; empty until that one is ready.
    Q_PROPERTY(QStringList thumbnails READ thumbnails NOTIFY thumbnailsChanged)
    // Audio peak per slice of the video, 0..1, kPeakCount long (empty if no audio).
    Q_PROPERTY(QList<qreal> peaks READ peaks NOTIFY peaksChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    static constexpr int kPeakCount = 4000;
    static constexpr int kThumbnailHeight = 96;

    explicit MediaPreview(QObject *parent = nullptr);
    ~MediaPreview() override;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    double duration() const { return m_duration; }
    void setDuration(double duration);
    int thumbnailCount() const { return m_thumbnailCount; }
    void setThumbnailCount(int count);
    QStringList thumbnails() const { return m_thumbnails; }
    QList<qreal> peaks() const { return m_peaks; }
    bool loading() const { return m_running > 0 || !m_pendingThumbs.isEmpty(); }

    // Where previews for a file are cached; changes when the file does.
    static QString cacheDirFor(const QString &path);

signals:
    void sourceChanged();
    void durationChanged();
    void thumbnailCountChanged();
    void thumbnailsChanged();
    void peaksChanged();
    void loadingChanged();

private:
    void restart();
    void stopAll();
    void startNextThumbnails();
    void startWaveform();
    QProcess *launch(const QStringList &args);
    void processFinished(QProcess *process);

    QUrl m_source;
    double m_duration = 0;
    int m_thumbnailCount = 40;
    QStringList m_thumbnails;
    QList<qreal> m_peaks;

    QString m_cacheDir;
    QList<int> m_pendingThumbs;
    QList<QPointer<QProcess>> m_processes;
    int m_running = 0;
    bool m_restartQueued = false;

    // Waveform decoding state.
    QByteArray m_pcm;
    qint64 m_samplesSeen = 0;
    QList<float> m_peakAccumulator;
};
