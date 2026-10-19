#pragma once

#include <QQuickFramebufferObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <memory>

struct mpv_handle;

// Video preview backed by libmpv's OpenGL render API. Plays anything FFmpeg
// can decode and supports frame-exact seeking, which the trim scrubber needs.
class MpvItem : public QQuickFramebufferObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double fps READ fps NOTIFY fpsChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit MpvItem(QQuickItem *parent = nullptr);
    ~MpvItem() override;

    Renderer *createRenderer() const override;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    bool loaded() const { return m_loaded; }
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    double fps() const { return m_fps; }
    bool paused() const { return m_paused; }
    void setPaused(bool paused);
    QString errorString() const { return m_errorString; }

    Q_INVOKABLE void seek(double seconds, bool exact = true);
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void frameStep();
    Q_INVOKABLE void frameBackStep();

signals:
    void sourceChanged();
    void loadedChanged();
    void positionChanged();
    void durationChanged();
    void fpsChanged();
    void pausedChanged();
    void errorStringChanged();

private:
    friend class MpvRenderer;

    // mpv cannot open video until the render context exists, which happens on
    // the first frame, so a source set before that is loaded here.
    void onRendererReady();
    void loadSource();
    void processEvents();
    void command(const QStringList &args);
    void setLoaded(bool loaded);
    void setErrorString(const QString &error);

    std::shared_ptr<mpv_handle> m_mpv;
    bool m_rendererReady = false;
    QUrl m_source;
    bool m_loaded = false;
    double m_position = 0;
    double m_duration = 0;
    double m_fps = 0;
    bool m_paused = true;
    QString m_errorString;
};
