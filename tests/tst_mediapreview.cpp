#include "MediaPreview.h"
#include "testclip.h"

#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

class TestMediaPreview : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void makesThumbnailsAndWaveform();
    void reusesTheCache();
    void silentVideoHasNoPeaks();

private:
    static bool waitUntilIdle(MediaPreview &preview);

    QTemporaryDir m_dir;
    QString m_clip;
};

void TestMediaPreview::initTestCase()
{
    if (TrimJob::ffmpegPath().isEmpty())
        QSKIP("ffmpeg is required");
    QStandardPaths::setTestModeEnabled(true);
    QDir(QStandardPaths::writableLocation(QStandardPaths::CacheLocation)).removeRecursively();
    QVERIFY(m_dir.isValid());
    m_clip = m_dir.filePath("clip.mp4");
    QVERIFY(makeTestClip(m_clip, 6));
}

bool TestMediaPreview::waitUntilIdle(MediaPreview &preview)
{
    // Work starts on the next event loop pass, so let it begin first.
    QTest::qWait(50);
    return QTest::qWaitFor([&] { return !preview.loading(); }, 120000);
}

void TestMediaPreview::makesThumbnailsAndWaveform()
{
    MediaPreview preview;
    preview.setThumbnailCount(6);
    preview.setSource(QUrl::fromLocalFile(m_clip));
    preview.setDuration(6.0);
    QVERIFY(waitUntilIdle(preview));

    const QStringList thumbs = preview.thumbnails();
    QCOMPARE(thumbs.size(), 6);
    for (const QString &thumb : thumbs) {
        QVERIFY2(!thumb.isEmpty(), "a thumbnail is missing");
        QVERIFY(QFileInfo(QUrl(thumb).toLocalFile()).size() > 0);
    }

    // A steady tone: every slice of the waveform has sound in it.
    const QList<qreal> peaks = preview.peaks();
    QCOMPARE(peaks.size(), MediaPreview::kPeakCount);
    int loud = 0;
    for (qreal p : peaks)
        loud += p > 0.05;
    QVERIFY2(loud > MediaPreview::kPeakCount * 0.9, qPrintable(QString::number(loud)));
}

void TestMediaPreview::reusesTheCache()
{
    MediaPreview preview;
    preview.setThumbnailCount(6);
    preview.setSource(QUrl::fromLocalFile(m_clip));
    preview.setDuration(6.0);
    QTest::qWait(50);
    // Everything was made by the previous test, so nothing needs FFmpeg.
    QVERIFY(!preview.loading());
    QCOMPARE(preview.peaks().size(), MediaPreview::kPeakCount);
    for (const QString &thumb : preview.thumbnails())
        QVERIFY(!thumb.isEmpty());
}

void TestMediaPreview::silentVideoHasNoPeaks()
{
    const QString silent = m_dir.filePath("silent.mp4");
    QProcess p;
    p.start(TrimJob::ffmpegPath(), {"-hide_banner", "-loglevel", "error", "-y",
                                    "-f", "lavfi", "-i", "testsrc2=size=160x120:rate=25:duration=3",
                                    "-c:v", "libx264", silent});
    QVERIFY(p.waitForFinished(60000) && p.exitCode() == 0);

    MediaPreview preview;
    preview.setThumbnailCount(3);
    preview.setSource(QUrl::fromLocalFile(silent));
    preview.setDuration(3.0);
    QVERIFY(waitUntilIdle(preview));
    QVERIFY(preview.peaks().isEmpty());
    for (const QString &thumb : preview.thumbnails())
        QVERIFY(!thumb.isEmpty());
}

QTEST_GUILESS_MAIN(TestMediaPreview)
#include "tst_mediapreview.moc"
