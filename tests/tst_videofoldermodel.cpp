#include "ExportQueue.h"
#include "VideoFolderModel.h"

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class TestVideoFolderModel : public QObject
{
    Q_OBJECT

private slots:
    void listsOnlyVideosInNaturalOrder();
    void reportsQueueState();

private:
    static void touch(const QString &path)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
    }
};

void TestVideoFolderModel::listsOnlyVideosInNaturalOrder()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    for (const char *name : {"clip 10.mp4", "clip 2.MKV", "Clip 1.mov", "notes.txt", "cover.jpg"})
        touch(dir.filePath(name));
    QVERIFY(QDir(dir.path()).mkdir("sub.mp4"));

    VideoFolderModel model;
    model.setFolder(QUrl::fromLocalFile(dir.path()));

    QCOMPARE(model.count(), 3);
    QStringList names;
    for (int i = 0; i < model.count(); ++i)
        names << model.data(model.index(i), VideoFolderModel::NameRole).toString();
    QCOMPARE(names, QStringList({"Clip 1.mov", "clip 2.MKV", "clip 10.mp4"}));
    QCOMPARE(model.indexOf(model.urlAt(2)), 2);
    QCOMPARE(model.urlAt(5), QUrl());
}

void TestVideoFolderModel::reportsQueueState()
{
    QTemporaryDir dir;
    touch(dir.filePath("a.mp4"));
    touch(dir.filePath("b.mp4"));

    ExportQueue queue;
    VideoFolderModel model;
    model.setQueue(&queue);
    model.setFolder(QUrl::fromLocalFile(dir.path()));
    QCOMPARE(model.data(model.index(0), VideoFolderModel::QueueStateRole).toInt(), -1);

    QSignalSpy changed(&model, &QAbstractItemModel::dataChanged);
    queue.add(model.urlAt(1), 0.0, 1.0, TrimJob::Fast);
    QVERIFY(!changed.isEmpty());
    QCOMPARE(changed.last().at(0).toModelIndex().row(), 1);
    QCOMPARE(model.data(model.index(1), VideoFolderModel::QueueStateRole).toInt(), int(TrimJob::Idle));
    QCOMPARE(model.data(model.index(0), VideoFolderModel::QueueStateRole).toInt(), -1);

    queue.remove(0);
    QCOMPARE(model.data(model.index(1), VideoFolderModel::QueueStateRole).toInt(), -1);
}

QTEST_GUILESS_MAIN(TestVideoFolderModel)
#include "tst_videofoldermodel.moc"
