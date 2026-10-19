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

    QUrl initialSource;
    const QStringList args = app.arguments();
    if (args.size() > 1)
        initialSource = QUrl::fromLocalFile(QFileInfo(args.at(1)).absoluteFilePath());

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/"));
    engine.setInitialProperties({{QStringLiteral("initialSource"), initialSource}});
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/Trimmer/qml/Main.qml")));

    return app.exec();
}
