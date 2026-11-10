import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// État relu en tâche de fond toutes les 5 min (minimum imposé par Garmin).
const REFRESH_SECONDS = 5 * 60;

(:background, :glance)
class SomfyApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Vue complète, ouverte en appuyant sur l'aperçu.
    (:typecheck(disableBackgroundCheck))
    function getInitialView() {
        registerRefresh();
        var view = new MainView();
        return [view, new MainDelegate(view)];
    }

    // Aperçu affiché dans la liste des glances.
    (:glance, :typecheck(disableBackgroundCheck))
    function getGlanceView() {
        registerRefresh();
        return [new SomfyGlanceView()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new SomfyService()];
    }

    // État reçu de la tâche de fond.
    (:typecheck(disableBackgroundCheck))
    function onBackgroundData(data as Application.PersistableType) as Void {
        if (data instanceof Dictionary && data["status"] != null) {
            try {
                Application.Storage.setValue("status", data["status"]);
                Application.Storage.setValue("updated", data["updated"]);
                if (data["site"] != null) {
                    Application.Storage.setValue("site", data["site"]);
                }
            } catch (e) {
            }
        }
        WatchUi.requestUpdate();
    }

    (:glance)
    function registerRefresh() as Void {
        var reg = Background.getTemporalEventRegisteredTime();
        if (reg == null || !(reg instanceof Time.Duration) || reg.value() != REFRESH_SECONDS) {
            Background.registerForTemporalEvent(new Time.Duration(REFRESH_SECONDS));
        }
    }
}
