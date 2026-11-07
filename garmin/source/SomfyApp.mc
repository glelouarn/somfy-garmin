import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class SomfyApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Vue complète, ouverte en appuyant sur l'aperçu.
    function getInitialView() {
        var view = new MainView();
        return [view, new MainDelegate(view)];
    }

    // Aperçu affiché dans la liste des glances.
    (:glance)
    function getGlanceView() {
        return [new SomfyGlanceView()];
    }
}
