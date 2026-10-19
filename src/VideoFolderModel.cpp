#include "VideoFolderModel.h"

#include "ExportQueue.h"

#include <QDir>
#include <QFileInfo>

#include <algorithm>

namespace {

// "clip 2" sorts before "clip 10", ignoring case. QCollator's numeric mode
// does this too, but not in every locale (it is a no-op in the C locale).
bool naturalLess(const QString &a, const QString &b)
{
    qsizetype i = 0, j = 0;
    while (i < a.size() && j < b.size()) {
        if (a[i].isDigit() && b[j].isDigit()) {
            qsizetype ei = i, ej = j;
            while (ei < a.size() && a[ei].isDigit())
                ++ei;
            while (ej < b.size() && b[ej].isDigit())
                ++ej;
            // Compare digit runs by value: strip leading zeros, then length, then digits.
            QStringView da = QStringView(a).mid(i, ei - i), db = QStringView(b).mid(j, ej - j);
            while (da.size() > 1 && da.front() == u'0')
                da = da.mid(1);
            while (db.size() > 1 && db.front() == u'0')
                db = db.mid(1);
            if (da.size() != db.size())
                return da.size() < db.size();
            if (const int c = da.compare(db); c != 0)
                return c < 0;
            i = ei;
            j = ej;
            continue;
        }
        const QChar ca = a[i].toCaseFolded(), cb = b[j].toCaseFolded();
        if (ca != cb)
            return ca < cb;
        ++i;
        ++j;
    }
    if ((a.size() - i) != (b.size() - j))
        return (a.size() - i) < (b.size() - j);
    return a < b;
}

} // namespace

VideoFolderModel::VideoFolderModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

const QStringList &VideoFolderModel::videoExtensions()
{
    static const QStringList extensions{
        QStringLiteral("mp4"), QStringLiteral("m4v"), QStringLiteral("mkv"), QStringLiteral("mov"),
        QStringLiteral("avi"), QStringLiteral("webm"), QStringLiteral("ts"), QStringLiteral("mts"),
        QStringLiteral("m2ts"), QStringLiteral("flv"), QStringLiteral("wmv"), QStringLiteral("mpg"),
        QStringLiteral("mpeg"), QStringLiteral("3gp"), QStringLiteral("ogv"),
    };
    return extensions;
}

int VideoFolderModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_files.size());
}

QVariant VideoFolderModel::data(const QModelIndex &index, int role) const
{
    if (!checkIndex(index, CheckIndexOption::IndexIsValid | CheckIndexOption::ParentIsInvalid))
        return {};
    const Entry &entry = m_files.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
        return entry.name;
    case UrlRole:
        return QUrl::fromLocalFile(entry.path);
    case SizeRole:
        return entry.size;
    case QueueStateRole: {
        const TrimJob *job = m_queue ? m_queue->jobFor(QUrl::fromLocalFile(entry.path)) : nullptr;
        return job ? int(job->state()) : -1;
    }
    }
    return {};
}

QHash<int, QByteArray> VideoFolderModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {UrlRole, "url"},
        {SizeRole, "size"},
        {QueueStateRole, "queueState"},
    };
}

void VideoFolderModel::setFolder(const QUrl &folder)
{
    if (folder == m_folder)
        return;
    m_folder = folder;
    emit folderChanged();
    refresh();
}

QString VideoFolderModel::folderName() const
{
    return QDir(m_folder.toLocalFile()).dirName();
}

void VideoFolderModel::setQueue(ExportQueue *queue)
{
    if (queue == m_queue)
        return;
    if (m_queue)
        m_queue->disconnect(this);
    m_queue = queue;
    if (m_queue)
        connect(m_queue, &ExportQueue::sourceChanged, this, &VideoFolderModel::onQueueSourceChanged);
    emit queueChanged();
    if (!m_files.isEmpty())
        emit dataChanged(index(0), index(int(m_files.size()) - 1), {QueueStateRole});
}

void VideoFolderModel::refresh()
{
    QList<Entry> files;
    const QString path = m_folder.toLocalFile();
    if (!path.isEmpty()) {
        QStringList filters;
        for (const QString &ext : videoExtensions())
            filters << QStringLiteral("*.") + ext;
        const QDir dir(path);
        const QFileInfoList infos = dir.entryInfoList(filters, QDir::Files | QDir::Readable);
        for (const QFileInfo &info : infos)
            files.append({info.fileName(), info.absoluteFilePath(), info.size()});
    }

    std::sort(files.begin(), files.end(),
              [](const Entry &a, const Entry &b) { return naturalLess(a.name, b.name); });

    beginResetModel();
    m_files = files;
    endResetModel();
    emit countChanged();
}

QUrl VideoFolderModel::urlAt(int row) const
{
    if (row < 0 || row >= m_files.size())
        return {};
    return QUrl::fromLocalFile(m_files.at(row).path);
}

int VideoFolderModel::indexOf(const QUrl &url) const
{
    const QString path = url.toLocalFile();
    for (int row = 0; row < m_files.size(); ++row) {
        if (m_files.at(row).path == path)
            return row;
    }
    return -1;
}

bool VideoFolderModel::isFolder(const QUrl &url) const
{
    return url.isLocalFile() && QFileInfo(url.toLocalFile()).isDir();
}

void VideoFolderModel::onQueueSourceChanged(const QUrl &source)
{
    const int row = indexOf(source);
    if (row >= 0)
        emit dataChanged(index(row), index(row), {QueueStateRole});
}
