import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Écran d'action : les trois cadenas, l'état actuel sur rond jaune,
// un anneau blanc autour de l'état sélectionné.
class MainView extends WatchUi.View {

    // Ordre d'affichage, de gauche à droite.
    static const STATES = ["armed", "disarmed", "partial"];
    static const PATHS = ["/arm", "/disarm", "/partial"];

    private var _status as String or Null;
    private var _site as String or Null;
    private var _sel as Number = 1;
    private var _message as String = "";
    private var _busy as Boolean = false;
    private var _started as Boolean = false;
    private var _target as String or Null;   // état demandé par l'action en cours

    // Géométrie calculée dans onUpdate, réutilisée pour le tactile.
    private var _xs as Array<Number> = [0, 0, 0];
    private var _cy as Number = 0;
    private var _d as Number = 0;

    function initialize() {
        View.initialize();
        _status = Application.Storage.getValue("status") as String or Null;
        _site = Application.Storage.getValue("site") as String or Null;
        selectCurrent();
    }

    function onShow() as Void {
        // Actualise une seule fois à l'ouverture (onShow revient aussi après la confirmation).
        if (!_started) {
            _started = true;
            refresh();
        }
    }

    // --- sélection -----------------------------------------------------------
    private function selectCurrent() as Void {
        if (_status != null) {
            var i = STATES.indexOf(_status);
            if (i >= 0) { _sel = i; }
        }
    }

    function move(step as Number) as Void {
        if (_busy) { return; }
        _sel = (_sel + step + STATES.size()) % STATES.size();
        _message = "";
        WatchUi.requestUpdate();
    }

    // Index de l'icône sous le point touché, ou -1.
    function indexAt(x as Number, y as Number) as Number {
        var half = _d / 2 + 10;
        if (y < _cy - half - 10 || y > _cy + half + 10) { return -1; }
        for (var i = 0; i < _xs.size(); i++) {
            if (x >= _xs[i] - half && x <= _xs[i] + half) { return i; }
        }
        return -1;
    }

    // Zone du titre « Alarme · site », au-dessus des icônes.
    function isTitleArea(y as Number) as Boolean {
        return y < _cy - _d / 2 - 20;
    }

    function choose(i as Number) as Void {
        if (_busy) { return; }
        _sel = i;
        activate();
    }

    // Applique l'état sélectionné.
    function activate() as Void {
        if (_busy) { return; }
        var st = STATES[_sel];
        if (_status != null && st.equals(_status)) {
            _message = "Déjà actif";
            WatchUi.requestUpdate();
            return;
        }
        if (st.equals("disarmed")) {
            var confirm = new ConfirmView("Désarmer l'alarme ?", "Désarmer");
            WatchUi.pushView(confirm, new ConfirmDelegate(confirm, method(:confirmDisarm)),
                WatchUi.SLIDE_UP);
            return;
        }
        runAction(PATHS[_sel], st);
    }

    function confirmDisarm() as Void {
        runAction("/disarm", "disarmed");
    }

    // --- réseau ----------------------------------------------------------------
    function refresh() as Void {
        send("/status", false, null, "Actualisation…");
    }

    function runAction(path as String, target as String) as Void {
        send(path, true, target, "Envoi…");
    }

    private function send(path as String, isPost as Boolean, target as String or Null, busyText as String) as Void {
        if (_busy) { return; }
        _target = target;
        var err = SomfyApi.request(path, isPost, method(:onResponse));
        if (err != null) {
            _message = err;
        } else {
            _busy = true;
            _message = busyText;
        }
        WatchUi.requestUpdate();
    }

    function onResponse(code as Number, data as Dictionary or String or Null) as Void {
        _busy = false;
        if (code == 200 && data instanceof Dictionary && data["status"] != null) {
            _status = data["status"] as String;
            Application.Storage.setValue("status", _status);
            Application.Storage.setValue("updated", Time.now().value());
            if (data["site"] != null) {
                _site = data["site"].toString();
                Application.Storage.setValue("site", _site);
            }
            selectCurrent();
            if (_target == null) {
                _message = "";
            } else if (_target.equals(_status)) {
                _message = "Confirmé";
                buzz();
            } else {
                _message = "Pas encore confirmé";
            }
        } else {
            _message = SomfyApi.errorText(code, data);
        }
        _target = null;
        WatchUi.requestUpdate();
    }

    private function buzz() as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, 300)]);
        }
    }

    // --- dessin ----------------------------------------------------------------
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        _d = w * 22 / 100;
        _cy = h * 47 / 100;
        _xs = [w * 19 / 100, w / 2, w * 81 / 100];   // plus d'écart entre icônes
        var r = _d / 2;
        var ring = w / 90;
        if (ring < 2) { ring = 2; }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var title = (_site != null && _site.length() > 0) ? "Alarme · " + _site : "Alarme";
        dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_SMALL, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < STATES.size(); i++) {
            var st = STATES[i];
            var x = _xs[i];
            if (_status != null && st.equals(_status)) {
                dc.setColor(LockIcon.YELLOW, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, _cy, r);
                LockIcon.draw(dc, st, x, _cy, _d, LockIcon.NAVY, LockIcon.YELLOW);
            } else {
                LockIcon.draw(dc, st, x, _cy, _d, 0xDDDDDD, Graphics.COLOR_BLACK);
            }
            if (i == _sel) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(ring);
                dc.drawCircle(x, _cy, r + ring * 4);   // espace net entre rond et anneau
                dc.setPenWidth(1);
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 69 / 100, Graphics.FONT_SMALL, Labels.text(STATES[_sel]),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_message.length() > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY, _message,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
