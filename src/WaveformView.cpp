#include "WaveformView.h"

#include <QPainter>

#include <cmath>

WaveformView::WaveformView(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

void WaveformView::setPeaks(const QList<qreal> &peaks)
{
    m_peaks = peaks;
    emit peaksChanged();
    update();
}

void WaveformView::setColor(const QColor &color)
{
    if (color == m_color)
        return;
    m_color = color;
    emit colorChanged();
    update();
}

void WaveformView::paint(QPainter *painter)
{
    if (m_peaks.isEmpty() || width() <= 0)
        return;

    const qreal mid = height() / 2;
    const int columns = qMax(1, int(std::ceil(width())));
    const qsizetype n = m_peaks.size();
    painter->setPen(QPen(m_color, 1));

    // Scale so the loudest moment fills the track, like a normalised view;
    // capped so near-silence doesn't turn into a wall of noise.
    qreal loudest = 0;
    for (qreal p : std::as_const(m_peaks))
        loudest = qMax(loudest, p);
    const qreal gain = loudest > 0 ? qMin(1 / loudest, 20.0) : 1;

    for (int x = 0; x < columns; ++x) {
        // Loudest peak among the samples this pixel column covers.
        const qsizetype from = qsizetype(x) * n / columns;
        const qsizetype to = qMax(from + 1, qsizetype(x + 1) * n / columns);
        qreal peak = 0;
        for (qsizetype i = from; i < to && i < n; ++i)
            peak = qMax(peak, m_peaks.at(i));
        // A gentle curve keeps quiet passages visible, as editors do.
        const qreal h = std::sqrt(qMin(1.0, peak * gain)) * (mid - 1);
        painter->drawLine(QPointF(x + 0.5, mid - h), QPointF(x + 0.5, mid + h));
    }
}
