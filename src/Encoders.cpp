#include "Encoders.h"

namespace Encoders {

const QList<Info> &all()
{
    static const QList<Info> encoders{
        {QStringLiteral("libx264"), QStringLiteral("H.264 (CPU, x264)"), false},
        {QStringLiteral("libx265"), QStringLiteral("H.265 / HEVC (CPU, x265)"), false},
        {QStringLiteral("libsvtav1"), QStringLiteral("AV1 (CPU, SVT-AV1)"), false},
        {QStringLiteral("h264_nvenc"), QStringLiteral("H.264 (NVIDIA GPU)"), true},
        {QStringLiteral("hevc_nvenc"), QStringLiteral("H.265 / HEVC (NVIDIA GPU)"), true},
        {QStringLiteral("av1_nvenc"), QStringLiteral("AV1 (NVIDIA GPU)"), true},
        {QStringLiteral("h264_qsv"), QStringLiteral("H.264 (Intel GPU, Quick Sync)"), true},
        {QStringLiteral("hevc_qsv"), QStringLiteral("H.265 / HEVC (Intel GPU, Quick Sync)"), true},
        {QStringLiteral("h264_amf"), QStringLiteral("H.264 (AMD GPU, AMF)"), true},
        {QStringLiteral("hevc_amf"), QStringLiteral("H.265 / HEVC (AMD GPU, AMF)"), true},
        {QStringLiteral("h264_vaapi"), QStringLiteral("H.264 (GPU, VA-API)"), true},
        {QStringLiteral("hevc_vaapi"), QStringLiteral("H.265 / HEVC (GPU, VA-API)"), true},
    };
    return encoders;
}

const Info *find(const QString &id)
{
    for (const Info &info : all()) {
        if (info.id == id)
            return &info;
    }
    return nullptr;
}

static bool isVaapi(const QString &id) { return id.endsWith(QLatin1String("_vaapi")); }

QStringList inputArgs(const QString &id)
{
    if (isVaapi(id))
        return {QStringLiteral("-vaapi_device"), QStringLiteral("/dev/dri/renderD128")};
    return {};
}

QStringList videoArgs(const QString &id, int quality, int speed, bool mp4Container)
{
    speed = qBound(0, speed, 2);
    const QString q = QString::number(qBound(0, quality, 51));
    QStringList args{QStringLiteral("-c:v"), id};

    if (id == QLatin1String("libx264") || id == QLatin1String("libx265")) {
        static const char *presets[] = {"veryfast", "medium", "slow"};
        args << QStringLiteral("-preset") << QLatin1String(presets[speed]) << QStringLiteral("-crf") << q;
    } else if (id == QLatin1String("libsvtav1")) {
        static const char *presets[] = {"10", "8", "6"};
        args << QStringLiteral("-preset") << QLatin1String(presets[speed]) << QStringLiteral("-crf") << q;
    } else if (id.endsWith(QLatin1String("_nvenc"))) {
        static const char *presets[] = {"p2", "p4", "p6"};
        args << QStringLiteral("-preset") << QLatin1String(presets[speed]) << QStringLiteral("-rc")
             << QStringLiteral("vbr") << QStringLiteral("-cq") << q << QStringLiteral("-b:v") << QStringLiteral("0");
    } else if (id.endsWith(QLatin1String("_qsv"))) {
        static const char *presets[] = {"veryfast", "medium", "slow"};
        args << QStringLiteral("-preset") << QLatin1String(presets[speed]) << QStringLiteral("-global_quality") << q;
    } else if (id.endsWith(QLatin1String("_amf"))) {
        static const char *presets[] = {"speed", "balanced", "quality"};
        args << QStringLiteral("-quality") << QLatin1String(presets[speed]) << QStringLiteral("-rc")
             << QStringLiteral("cqp") << QStringLiteral("-qp_i") << q << QStringLiteral("-qp_p") << q;
    } else if (isVaapi(id)) {
        args << QStringLiteral("-vf") << QStringLiteral("format=nv12,hwupload") << QStringLiteral("-qp") << q;
    }

    // Apple players only accept HEVC in MP4 with this tag.
    if (mp4Container && (id.startsWith(QLatin1String("hevc")) || id == QLatin1String("libx265")))
        args << QStringLiteral("-tag:v") << QStringLiteral("hvc1");
    return args;
}

} // namespace Encoders
