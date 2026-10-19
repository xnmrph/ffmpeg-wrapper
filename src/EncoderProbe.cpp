#include "EncoderProbe.h"

#include "Encoders.h"
#include "TrimJob.h"

#include <QRegularExpression>
#include <QTimer>
#include <QVariantMap>

#include <memory>

namespace {
constexpr int kTestTimeoutMs = 15000;
}

EncoderProbe::EncoderProbe(QObject *parent)
    : QObject(parent)
{
}

EncoderProbe::~EncoderProbe()
{
    if (m_process) {
        m_process->disconnect(this);
        m_process->kill();
        m_process->waitForFinished(1000);
    }
}

QVariantList EncoderProbe::encoders() const
{
    QVariantList list;
    for (const Encoders::Info &info : Encoders::all()) {
        list << QVariantMap{
            {QStringLiteral("id"), info.id},
            {QStringLiteral("label"), info.label},
            {QStringLiteral("gpu"), info.gpu},
            {QStringLiteral("available"), m_available.contains(info.id)},
        };
    }
    return list;
}

void EncoderProbe::probe()
{
    if (m_probing)
        return;
    m_probing = true;
    emit probingChanged();

    m_ffmpegPath = TrimJob::ffmpegPath();
    m_ffmpegVersion.clear();
    m_built.clear();
    m_toTest.clear();
    m_available.clear();
    emit resultsChanged();

    if (m_ffmpegPath.isEmpty()) {
        finish();
        return;
    }

    startProcess({QStringLiteral("-hide_banner"), QStringLiteral("-version")}, [this](int, const QByteArray &out) {
        // "ffmpeg version 6.1.1-3ubuntu5 Copyright ..." -> "6.1.1-3ubuntu5"
        const QString first = QString::fromUtf8(out).section(QLatin1Char('\n'), 0, 0);
        m_ffmpegVersion = first.section(QLatin1Char(' '), 2, 2);
        if (m_ffmpegVersion.isEmpty()) {
            // Not a working FFmpeg (wrong file, missing libraries).
            m_ffmpegPath.clear();
            finish();
            return;
        }

        startProcess({QStringLiteral("-hide_banner"), QStringLiteral("-encoders")}, [this](int, const QByteArray &out) {
            static const QRegularExpression line(QStringLiteral("^\\s*V\\S*\\s+(\\S+)"),
                                                 QRegularExpression::MultilineOption);
            auto it = line.globalMatch(QString::fromUtf8(out));
            while (it.hasNext())
                m_built << it.next().captured(1);

            for (const Encoders::Info &info : Encoders::all()) {
                if (!m_built.contains(info.id))
                    continue;
                if (info.gpu)
                    m_toTest << info.id;
                else
                    m_available << info.id;
            }
            emit resultsChanged();
            runStep();
        });
    });
}

void EncoderProbe::runStep()
{
    if (m_toTest.isEmpty()) {
        finish();
        return;
    }
    const QString id = m_toTest.takeFirst();
    // Encode a few frames of a blank picture and throw the result away.
    QStringList args{QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error")};
    args << Encoders::inputArgs(id)
         << QStringLiteral("-f") << QStringLiteral("lavfi")
         << QStringLiteral("-i") << QStringLiteral("color=c=black:s=256x256:r=30:d=0.2")
         << Encoders::videoArgs(id, 23, 0, false)
         << QStringLiteral("-frames:v") << QStringLiteral("3")
         << QStringLiteral("-f") << QStringLiteral("null") << QStringLiteral("-");
    startProcess(args, [this, id](int exitCode, const QByteArray &) {
        if (exitCode == 0) {
            m_available << id;
            emit resultsChanged();
        }
        runStep();
    });
}

void EncoderProbe::finish()
{
    emit resultsChanged();
    m_probing = false;
    emit probingChanged();
    emit finished();
}

void EncoderProbe::startProcess(const QStringList &args, std::function<void(int, const QByteArray &)> done)
{
    auto *process = new QProcess(this);
    m_process = process;
    process->setProcessChannelMode(QProcess::MergedChannels);

    auto *timeout = new QTimer(process);
    timeout->setSingleShot(true);
    connect(timeout, &QTimer::timeout, process, [process] { process->kill(); });

    auto handled = std::make_shared<bool>(false);
    auto complete = [this, process, done, handled](int exitCode) {
        if (*handled)
            return;
        *handled = true;
        const QByteArray out = process->readAll();
        process->deleteLater();
        done(exitCode, out);
    };
    connect(process, &QProcess::finished, this, [complete](int exitCode, QProcess::ExitStatus status) {
        complete(status == QProcess::NormalExit ? exitCode : -1);
    });
    connect(process, &QProcess::errorOccurred, this, [complete](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            complete(-1);
    });

    timeout->start(kTestTimeoutMs);
    process->start(m_ffmpegPath, args);
}
