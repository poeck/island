#include <QCoreApplication>
#include <QObject>
#include <QQmlEngine>
#include <qqml.h>
class ScreenProbe: public QObject {
    Q_OBJECT
public:
    Q_INVOKABLE bool invalidate(QObject* screen) {
        return screen && QMetaObject::invokeMethod(screen, "screenDestroyed", Qt::DirectConnection);
    }
};
static void registerProbe() {
    qmlRegisterSingletonType<ScreenProbe>("Island.Test", 1, 0, "ScreenProbe",
        [](QQmlEngine*, QJSEngine*) -> QObject* { return new ScreenProbe; });
}
Q_COREAPP_STARTUP_FUNCTION(registerProbe)
#include "screen-probe.moc"
