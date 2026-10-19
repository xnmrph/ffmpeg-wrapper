#pragma once

#include <QColor>
#include <QList>
#include <QQuickPaintedItem>
#include <QtQml/qqmlregistration.h>

// Draws audio peaks as a mirrored waveform across the item's width.
class WaveformView : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QList<qreal> peaks READ peaks WRITE setPeaks NOTIFY peaksChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)

public:
    explicit WaveformView(QQuickItem *parent = nullptr);

    QList<qreal> peaks() const { return m_peaks; }
    void setPeaks(const QList<qreal> &peaks);
    QColor color() const { return m_color; }
    void setColor(const QColor &color);

    void paint(QPainter *painter) override;

signals:
    void peaksChanged();
    void colorChanged();

private:
    QList<qreal> m_peaks;
    QColor m_color{0x3d, 0xd6, 0x6b};
};
