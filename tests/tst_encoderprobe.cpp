#include "EncoderProbe.h"
#include "Encoders.h"
#include "TrimJob.h"

#include <QSignalSpy>
#include <QTest>

class TestEncoderProbe : public QObject
{
    Q_OBJECT

private slots:
    void findsWorkingEncoders();
    void reportsMissingFfmpeg();
    void encoderArguments();
};

void TestEncoderProbe::findsWorkingEncoders()
{
    if (TrimJob::ffmpegPath().isEmpty())
        QSKIP("ffmpeg is required");

    EncoderProbe probe;
    QSignalSpy done(&probe, &EncoderProbe::finished);
    probe.probe();
    QVERIFY(probe.probing());
    QVERIFY(done.wait(280000));
    QVERIFY(!probe.probing());
    QVERIFY(probe.ffmpegFound());
    QVERIFY(!probe.ffmpegVersion().isEmpty());
    QVERIFY(probe.isAvailable("libx264"));

    const QVariantList list = probe.encoders();
    QCOMPARE(list.size(), Encoders::all().size());
    // Whatever GPU encoders passed must really encode here.
    for (const QString &id : probe.available()) {
        const Encoders::Info *info = Encoders::find(id);
        QVERIFY(info);
        qInfo() << "available:" << id << (info->gpu ? "(GPU)" : "");
    }
}

void TestEncoderProbe::reportsMissingFfmpeg()
{
    TrimJob::setFfmpegOverride("/definitely/not/ffmpeg");
    EncoderProbe probe;
    QSignalSpy done(&probe, &EncoderProbe::finished);
    probe.probe();
    QVERIFY(done.count() == 1 || done.wait(5000));
    QVERIFY(!probe.ffmpegFound());
    QVERIFY(probe.available().isEmpty());
    TrimJob::setFfmpegOverride({});
}

void TestEncoderProbe::encoderArguments()
{
    QStringList a = Encoders::videoArgs("h264_nvenc", 20, 1, true);
    QCOMPARE(a.at(a.indexOf("-cq") + 1), QStringLiteral("20"));
    QCOMPARE(a.at(a.indexOf("-preset") + 1), QStringLiteral("p4"));
    a = Encoders::videoArgs("hevc_vaapi", 22, 0, true);
    QVERIFY(a.contains("format=nv12,hwupload"));
    QVERIFY(a.contains("hvc1"));
    QCOMPARE(Encoders::inputArgs("hevc_vaapi").size(), 2);
    QVERIFY(Encoders::inputArgs("libx264").isEmpty());
    a = Encoders::videoArgs("libx264", 18, 2, false);
    QCOMPARE(a.at(a.indexOf("-preset") + 1), QStringLiteral("slow"));
    QVERIFY(!a.contains("hvc1"));
}

QTEST_GUILESS_MAIN(TestEncoderProbe)
#include "tst_encoderprobe.moc"
