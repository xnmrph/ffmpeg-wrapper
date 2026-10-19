#include "TrimJob.h"
#include "testclip.h"

#include <QFileInfo>
#include <QProcess>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

class TestTrimJob : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void defaultOutputPath();
    void fastTrimSnapsToKeyframe();
    void accurateTrimIsFrameExact();
    void rejectsEmptyRange();
    void cancelRemovesPartialOutput();

private:
    double probeDuration(const QString &path);
    bool runTrim(TrimJob &job);

    QTemporaryDir m_dir;
    QString m_clip;
};

void TestTrimJob::initTestCase()
{
    if (TrimJob::ffmpegPath().isEmpty() || QStandardPaths::findExecutable("ffprobe").isEmpty())
        QSKIP("ffmpeg and ffprobe are required");
    QVERIFY(m_dir.isValid());

    // 20 s at 30 fps with a keyframe every 2 s, so fast and accurate cuts differ.
    m_clip = m_dir.filePath("clip.mp4");
    QVERIFY(makeTestClip(m_clip));
}

double TestTrimJob::probeDuration(const QString &path)
{
    QProcess p;
    p.start(QStandardPaths::findExecutable("ffprobe"), {
        "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=duration", "-of", "csv=p=0", path,
    });
    p.waitForFinished(10000);
    return p.readAllStandardOutput().trimmed().toDouble();
}

bool TestTrimJob::runTrim(TrimJob &job)
{
    QSignalSpy done(&job, &TrimJob::finished);
    job.start();
    return done.count() > 0 || done.wait(60000);
}

void TestTrimJob::defaultOutputPath()
{
    const QString fast = TrimJob::defaultOutputPath(m_clip, TrimJob::Fast);
    QCOMPARE(QFileInfo(fast).fileName(), QStringLiteral("clip_trim.mp4"));

    QFile existing(fast);
    QVERIFY(existing.open(QIODevice::WriteOnly));
    existing.close();
    QCOMPARE(QFileInfo(TrimJob::defaultOutputPath(m_clip, TrimJob::Fast)).fileName(),
             QStringLiteral("clip_trim_2.mp4"));
    QFile::remove(fast);

    QCOMPARE(QFileInfo(TrimJob::defaultOutputPath("/x/a.webm", TrimJob::Accurate)).suffix(), QStringLiteral("mp4"));
    QCOMPARE(QFileInfo(TrimJob::defaultOutputPath("/x/a.mkv", TrimJob::Accurate)).suffix(), QStringLiteral("mkv"));
    QCOMPARE(QFileInfo(TrimJob::defaultOutputPath("/x/a.webm", TrimJob::Fast)).suffix(), QStringLiteral("webm"));
}

void TestTrimJob::fastTrimSnapsToKeyframe()
{
    TrimJob job;
    job.setSource(QUrl::fromLocalFile(m_clip));
    job.setInPoint(5.0);
    job.setOutPoint(9.0);
    job.setMode(TrimJob::Fast);
    job.setOutput(m_dir.filePath("fast.mp4"));
    QVERIFY(runTrim(job));
    QCOMPARE(job.state(), TrimJob::Finished);
    QCOMPARE(job.progress(), 1.0);

    // Starts at the keyframe at 4 s, so up to 2 s longer than requested.
    const double d = probeDuration(job.output());
    QVERIFY2(d >= 3.9 && d <= 6.1, qPrintable(QString::number(d)));
}

void TestTrimJob::accurateTrimIsFrameExact()
{
    TrimJob job;
    job.setSource(QUrl::fromLocalFile(m_clip));
    job.setInPoint(5.0);
    job.setOutPoint(9.0);
    job.setMode(TrimJob::Accurate);
    job.setOutput(m_dir.filePath("accurate.mp4"));
    QVERIFY(runTrim(job));
    QCOMPARE(job.state(), TrimJob::Finished);

    const double d = probeDuration(job.output());
    QVERIFY2(qAbs(d - 4.0) < 0.05, qPrintable(QString::number(d)));
}

void TestTrimJob::rejectsEmptyRange()
{
    TrimJob job;
    job.setSource(QUrl::fromLocalFile(m_clip));
    job.setInPoint(5.0);
    job.setOutPoint(5.0);
    QVERIFY(runTrim(job));
    QCOMPARE(job.state(), TrimJob::Failed);
    QVERIFY(!job.errorString().isEmpty());
}

void TestTrimJob::cancelRemovesPartialOutput()
{
    TrimJob job;
    job.setSource(QUrl::fromLocalFile(m_clip));
    job.setInPoint(0);
    job.setOutPoint(20);
    job.setMode(TrimJob::Accurate);
    job.setOutput(m_dir.filePath("cancelled.mp4"));
    job.start();
    QCOMPARE(job.state(), TrimJob::Running);
    job.cancel();
    QCOMPARE(job.state(), TrimJob::Cancelled);
    QVERIFY(!QFileInfo::exists(job.output()));
}

QTEST_GUILESS_MAIN(TestTrimJob)
#include "tst_trimjob.moc"
