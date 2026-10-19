#pragma once

#include "TrimJob.h"

#include <QProcess>
#include <QString>

// Writes a short test clip with a keyframe every 2 s and a sine tone.
inline bool makeTestClip(const QString &path, int seconds = 20)
{
    const QString duration = QString::number(seconds);
    QProcess p;
    p.start(TrimJob::ffmpegPath(), {
        "-hide_banner", "-loglevel", "error", "-y",
        "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=30:duration=" + duration,
        "-f", "lavfi", "-i", "sine=frequency=440:duration=" + duration,
        "-c:v", "libx264", "-g", "60", "-keyint_min", "60", "-sc_threshold", "0",
        "-c:a", "aac", "-shortest", path,
    });
    return p.waitForFinished(60000) && p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
}
