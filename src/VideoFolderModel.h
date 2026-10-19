#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class ExportQueue;

// The videos directly inside one folder, in natural order ("clip 2" before
// "clip 10"), each with its state in the export queue for the sidebar.
class VideoFolderModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl folder READ folder WRITE setFolder NOTIFY folderChanged)
    Q_PROPERTY(QString folderName READ folderName NOTIFY folderChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(ExportQueue *queue READ queue WRITE setQueue NOTIFY queueChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        UrlRole,
        SizeRole,
        // -1 when the video is not in the queue, otherwise a TrimJob::State.
        QueueStateRole,
    };

    explicit VideoFolderModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QUrl folder() const { return m_folder; }
    void setFolder(const QUrl &folder);
    QString folderName() const;
    int count() const { return int(m_files.size()); }
    ExportQueue *queue() const { return m_queue; }
    void setQueue(ExportQueue *queue);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QUrl urlAt(int row) const;
    Q_INVOKABLE int indexOf(const QUrl &url) const;
    Q_INVOKABLE bool isFolder(const QUrl &url) const;

    static const QStringList &videoExtensions();

signals:
    void folderChanged();
    void countChanged();
    void queueChanged();

private:
    void onQueueSourceChanged(const QUrl &source);

    struct Entry {
        QString name;
        QString path;
        qint64 size;
    };

    QUrl m_folder;
    QList<Entry> m_files;
    QPointer<ExportQueue> m_queue;
};
