#include "MpvItem.h"

#include <QDebug>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QPointer>
#include <QQuickWindow>

#include <mpv/client.h>
#include <mpv/render_gl.h>

#include <stdexcept>
#include <vector>

namespace {

enum PropertyId : uint64_t { TimePos = 1, Duration, Pause, Fps, DisplayWidth, DisplayHeight };

void *getProcAddress(void *, const char *name)
{
    QOpenGLContext *ctx = QOpenGLContext::currentContext();
    return ctx ? reinterpret_cast<void *>(ctx->getProcAddress(QByteArray(name))) : nullptr;
}

} // namespace

// Lives on the scene graph's render thread and owns the mpv render context,
// which must be created and destroyed with the OpenGL context current.
class MpvRenderer : public QQuickFramebufferObject::Renderer
{
public:
    explicit MpvRenderer(MpvItem *item)
        : m_item(item), m_mpv(item->m_mpv)
    {
    }

    ~MpvRenderer() override
    {
        if (m_gl) {
            mpv_render_context_set_update_callback(m_gl, nullptr, nullptr);
            mpv_render_context_free(m_gl);
        }
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override
    {
        if (!m_gl) {
            mpv_opengl_init_params glInit{getProcAddress, nullptr};
            mpv_render_param params[]{
                {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
                {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit},
                {MPV_RENDER_PARAM_INVALID, nullptr},
            };
            if (mpv_render_context_create(&m_gl, m_mpv.get(), params) < 0)
                throw std::runtime_error("failed to initialise the mpv OpenGL renderer");
            mpv_render_context_set_update_callback(m_gl, &MpvRenderer::onUpdate, this);
            QMetaObject::invokeMethod(m_item.data(), &MpvItem::onRendererReady, Qt::QueuedConnection);
        }
        return QQuickFramebufferObject::Renderer::createFramebufferObject(size);
    }

    void render() override
    {
        QOpenGLFramebufferObject *fbo = framebufferObject();
        mpv_opengl_fbo mpfbo{static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), 0};
        int flipY = 0;
        mpv_render_param params[]{
            {MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flipY},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        mpv_render_context_render(m_gl, params);
    }

private:
    // Called by mpv on one of its own threads when a new frame is ready.
    static void onUpdate(void *ctx)
    {
        auto *self = static_cast<MpvRenderer *>(ctx);
        QMetaObject::invokeMethod(self->m_item.data(), "update", Qt::QueuedConnection);
    }

    QPointer<MpvItem> m_item;
    std::shared_ptr<mpv_handle> m_mpv;
    mpv_render_context *m_gl = nullptr;
};

MpvItem::MpvItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    mpv_handle *handle = mpv_create();
    if (!handle)
        throw std::runtime_error("failed to create mpv instance");
    m_mpv.reset(handle, mpv_terminate_destroy);

    mpv_set_option_string(handle, "vo", "libmpv");
    mpv_set_option_string(handle, "hwdec", "auto-safe");
    mpv_set_option_string(handle, "keep-open", "always");
    mpv_set_option_string(handle, "idle", "yes");
    mpv_set_option_string(handle, "pause", "yes");
    mpv_set_option_string(handle, "hr-seek", "default");
    mpv_set_option_string(handle, "hr-seek-framedrop", "no");
    mpv_set_option_string(handle, "input-default-bindings", "no");
    mpv_set_option_string(handle, "terminal", "no");

    if (mpv_initialize(handle) < 0)
        throw std::runtime_error("failed to initialise mpv");

    // Set MXCUT_MPV_LOG=v (or debug, info, ...) to see mpv's log.
    const QByteArray logLevel = qgetenv("MXCUT_MPV_LOG");
    if (!logLevel.isEmpty())
        mpv_request_log_messages(handle, logLevel.constData());

    mpv_observe_property(handle, TimePos, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(handle, Duration, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(handle, Pause, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(handle, Fps, "container-fps", MPV_FORMAT_DOUBLE);
    mpv_observe_property(handle, DisplayWidth, "dwidth", MPV_FORMAT_INT64);
    mpv_observe_property(handle, DisplayHeight, "dheight", MPV_FORMAT_INT64);

    mpv_set_wakeup_callback(handle, [](void *ctx) {
        QMetaObject::invokeMethod(static_cast<MpvItem *>(ctx), &MpvItem::processEvents,
                                  Qt::QueuedConnection);
    }, this);

}

MpvItem::~MpvItem()
{
    mpv_set_wakeup_callback(m_mpv.get(), nullptr, nullptr);
}

QQuickFramebufferObject::Renderer *MpvItem::createRenderer() const
{
    window()->setPersistentGraphics(true);
    window()->setPersistentSceneGraph(true);
    return new MpvRenderer(const_cast<MpvItem *>(this));
}

void MpvItem::setSource(const QUrl &source)
{
    if (source == m_source)
        return;
    m_source = source;
    emit sourceChanged();

    setErrorString({});
    setLoaded(false);
    if (m_rendererReady)
        loadSource();
}

void MpvItem::onRendererReady()
{
    m_rendererReady = true;
    if (!m_source.isEmpty())
        loadSource();
}

void MpvItem::loadSource()
{
    if (m_source.isEmpty()) {
        command({QStringLiteral("stop")});
        return;
    }
    const QString path = m_source.isLocalFile() ? m_source.toLocalFile() : m_source.toString();
    command({QStringLiteral("loadfile"), path});
}

void MpvItem::setPaused(bool paused)
{
    int flag = paused ? 1 : 0;
    mpv_set_property_async(m_mpv.get(), 0, "pause", MPV_FORMAT_FLAG, &flag);
}

void MpvItem::seek(double seconds, bool exact)
{
    command({QStringLiteral("seek"), QString::number(seconds, 'f', 6),
             exact ? QStringLiteral("absolute+exact") : QStringLiteral("absolute+keyframes")});
}

void MpvItem::togglePause()
{
    command({QStringLiteral("cycle"), QStringLiteral("pause")});
}

void MpvItem::frameStep()
{
    command({QStringLiteral("frame-step")});
}

void MpvItem::frameBackStep()
{
    command({QStringLiteral("frame-back-step")});
}

void MpvItem::command(const QStringList &args)
{
    std::vector<QByteArray> utf8;
    utf8.reserve(args.size());
    for (const QString &arg : args)
        utf8.push_back(arg.toUtf8());
    std::vector<const char *> argv;
    for (const QByteArray &arg : utf8)
        argv.push_back(arg.constData());
    argv.push_back(nullptr);
    mpv_command_async(m_mpv.get(), 0, argv.data());
}

void MpvItem::processEvents()
{
    while (m_mpv) {
        mpv_event *event = mpv_wait_event(m_mpv.get(), 0);
        if (event->event_id == MPV_EVENT_NONE)
            break;

        switch (event->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            auto *prop = static_cast<mpv_event_property *>(event->data);
            const bool hasValue = prop->data != nullptr;
            switch (event->reply_userdata) {
            case TimePos:
                m_position = hasValue ? *static_cast<double *>(prop->data) : 0;
                emit positionChanged();
                break;
            case Duration:
                m_duration = hasValue ? *static_cast<double *>(prop->data) : 0;
                emit durationChanged();
                break;
            case Pause:
                m_paused = hasValue && *static_cast<int *>(prop->data);
                emit pausedChanged();
                break;
            case Fps:
                m_fps = hasValue ? *static_cast<double *>(prop->data) : 0;
                emit fpsChanged();
                break;
            case DisplayWidth:
                m_videoWidth = hasValue ? int(*static_cast<int64_t *>(prop->data)) : 0;
                emit videoSizeChanged();
                break;
            case DisplayHeight:
                m_videoHeight = hasValue ? int(*static_cast<int64_t *>(prop->data)) : 0;
                emit videoSizeChanged();
                break;
            }
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            auto *msg = static_cast<mpv_event_log_message *>(event->data);
            qInfo().noquote() << "mpv:" << msg->prefix << QString::fromUtf8(msg->text).trimmed();
            break;
        }
        case MPV_EVENT_FILE_LOADED:
            setLoaded(true);
            break;
        case MPV_EVENT_END_FILE: {
            auto *end = static_cast<mpv_event_end_file *>(event->data);
            if (end->reason == MPV_END_FILE_REASON_ERROR) {
                setLoaded(false);
                setErrorString(QString::fromUtf8(mpv_error_string(end->error)));
            }
            break;
        }
        default:
            break;
        }
    }
}

void MpvItem::setLoaded(bool loaded)
{
    if (loaded == m_loaded)
        return;
    m_loaded = loaded;
    emit loadedChanged();
}

void MpvItem::setErrorString(const QString &error)
{
    if (error == m_errorString)
        return;
    m_errorString = error;
    emit errorStringChanged();
}
