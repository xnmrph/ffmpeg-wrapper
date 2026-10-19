#pragma once

#include <QList>
#include <QString>
#include <QStringList>

// Video encoders offered for Accurate mode, and the FFmpeg arguments each
// needs. Quality is on a CRF-like scale (lower is better, 18 is visually
// lossless for x264); speed is 0 = fast, 1 = balanced, 2 = best quality.
namespace Encoders {

struct Info {
    QString id;    // FFmpeg encoder name
    QString label; // shown to the user
    bool gpu;
};

const QList<Info> &all();
const Info *find(const QString &id);

// Arguments that must come before -i (hardware device setup).
QStringList inputArgs(const QString &id);
// Video encoder, filters and rate-control arguments, after -i.
QStringList videoArgs(const QString &id, int quality, int speed, bool mp4Container);

} // namespace Encoders
