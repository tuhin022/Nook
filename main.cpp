#include <QApplication>
#include <QFileInfo>
#include <QMessageBox>
#include <QUrl>
#include <QWebEngineProfile>
#include <QWebEngineSettings>
#include <QWebEngineView>
#include <QWebEnginePage>
#include <QMainWindow>
#include <QStandardPaths>
#include <QDir>

class NookWindow final : public QMainWindow {
public:
    explicit NookWindow(QWidget *parent = nullptr) : QMainWindow(parent) {
        setWindowTitle(QStringLiteral("Nook — chats first, posts second"));
        resize(1180, 820);
        setMinimumSize(900, 640);

        view = new QWebEngineView(this);
        setCentralWidget(view);

        auto *settings = view->settings();
        settings->setAttribute(QWebEngineSettings::JavascriptEnabled, true);
        settings->setAttribute(QWebEngineSettings::LocalContentCanAccessFileUrls, false);
        settings->setAttribute(QWebEngineSettings::LocalContentCanAccessRemoteUrls, true);
        settings->setAttribute(QWebEngineSettings::FullScreenSupportEnabled, true);
        settings->setAttribute(QWebEngineSettings::PlaybackRequiresUserGesture, false);

        // Keep the authenticated web session and Supabase browser state between launches
        // without treating local browser state as the application's source of truth.
        auto *profile = view->page()->profile();
        const QString dataRoot = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
        QDir().mkpath(dataRoot);
        profile->setPersistentStoragePath(dataRoot + QStringLiteral("/web-storage"));
        profile->setCachePath(dataRoot + QStringLiteral("/cache"));
        profile->setPersistentCookiesPolicy(QWebEngineProfile::ForcePersistentCookies);

        const QString htmlPath = QDir(QCoreApplication::applicationDirPath())
                                      .filePath(QStringLiteral("web/nook.html"));
        if (!QFileInfo::exists(htmlPath)) {
            QMessageBox::critical(this, QStringLiteral("Nook"),
                                  QStringLiteral("web/nook.html was not found beside the application.\n\nExpected:\n%1")
                                      .arg(htmlPath));
            return;
        }

        connect(view, &QWebEngineView::titleChanged, this, [this](const QString &title) {
            setWindowTitle(title.isEmpty() ? QStringLiteral("Nook") : title);
        });
        connect(view, &QWebEngineView::renderProcessTerminated, this,
                [this](QWebEnginePage::RenderProcessTerminationStatus status, int code) {
            Q_UNUSED(status);
            ++renderCrashCount;
            if (renderCrashCount <= 2) {
                QMessageBox::warning(this, QStringLiteral("Nook"),
                                     QStringLiteral("The web UI process stopped (code %1). Nook will try to recover.").arg(code));
                view->reload();
                return;
            }
            view->setHtml(QStringLiteral(
                "<main style='font:16px system-ui;padding:32px;max-width:760px;margin:auto'>"
                "<h1>Nook stopped unexpectedly</h1>"
                "<p>The embedded web process failed repeatedly. Close and reopen Nook after checking the backend configuration.</p>"
                "<button onclick='location.reload()' style='padding:10px 16px'>Try again</button>"
                "</main>"));
        });
        connect(view, &QWebEngineView::loadFinished, this, [this](bool ok) {
            if (ok) renderCrashCount = 0;
        });

        view->load(QUrl::fromLocalFile(htmlPath));
    }

private:
    QWebEngineView *view = nullptr;
    int renderCrashCount = 0;
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    QApplication::setApplicationName(QStringLiteral("Nook"));
    QApplication::setOrganizationName(QStringLiteral("Nook"));
    QApplication::setApplicationVersion(QStringLiteral("1.0"));

    NookWindow window;
    window.show();
    return app.exec();
}
