#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QUrl>

#include <clocale>

int main(int argc, char *argv[])
{
    // libmpv renders through OpenGL, so Qt Quick must use the OpenGL backend
    // on every platform (Windows would otherwise default to Direct3D 11).
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QGuiApplication app(argc, argv);
    // The name settings are saved under; kept from before the app was renamed.
    app.setApplicationName(QStringLiteral("Video Trimmer"));
    app.setOrganizationName(QStringLiteral("video-trimmer"));
    app.setApplicationVersion(QStringLiteral(APP_VERSION));
    // Matches the .desktop file, so Linux desktops group the window under it.
    app.setDesktopFileName(QStringLiteral("video-trimmer"));
    app.setWindowIcon(QIcon(QStringLiteral(":/packaging/icons/video-trimmer-256.png")));

    // libmpv refuses to initialise unless numbers are parsed the "C" way.
    std::setlocale(LC_NUMERIC, "C");

    // Material in its dark, dense variant; the colours come from Theme.qml.
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense");
    QQuickStyle::setStyle(QStringLiteral("Material"));

    // --check-startup loads the window and quits, for CI to prove a packaged
    // build finds everything it needs.
    QStringList args = app.arguments();
    const bool checkStartup = args.removeAll(QStringLiteral("--check-startup")) > 0;
    QUrl initialSource;
    if (args.size() > 1)
        initialSource = QUrl::fromLocalFile(QFileInfo(args.at(1)).absoluteFilePath());

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/"));
    // Packaged builds ship Qt's QML modules in a qml folder beside the app.
    // Put it first: Qt also finds these modules' qmldir files built into its
    // own libraries, and looking for their plugins there fails on Windows.
    const QString bundledQml = QCoreApplication::applicationDirPath() + QStringLiteral("/qml");
    if (QFileInfo(bundledQml).isDir())
        engine.addImportPath(bundledQml);
    engine.setInitialProperties({{QStringLiteral("initialSource"), initialSource}});
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/Trimmer/qml/Main.qml")));
    if (checkStartup)
        return engine.rootObjects().isEmpty() ? 1 : 0;

    return app.exec();
}
