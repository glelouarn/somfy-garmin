import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Confirmation en français, même principe visuel que l'écran d'action :
// deux symboles (✕ refuser, ✓ confirmer), anneau blanc autour de la sélection.
// « Refuser » est sélectionné par défaut.
class ConfirmView extends WatchUi.View {

    private var _question as String;
    private var _yesLabel as String;
    private var _sel as Number = 0;          // 0 = refuser, 1 = confirmer

    private var _xs as Array<Number> = [0, 0];
    private var _cy as Number = 0;
    private var _d as Number = 0;

    function initialize(question as String, yesLabel as String) {
        View.initialize();
        _question = question;
        _yesLabel = yesLabel;
    }

    function isConfirmSelected() as Boolean {
        return _sel == 1;
    }

    function move() as Void {
        _sel = 1 - _sel;
        WatchUi.requestUpdate();
    }

    function select(i as Number) as Void {
        _sel = i;
        WatchUi.requestUpdate();
    }

    function indexAt(x as Number, y as Number) as Number {
        var half = _d / 2 + 14;
        if (y < _cy - half || y > _cy + half) { return -1; }
        for (var i = 0; i < _xs.size(); i++) {
            if (x >= _xs[i] - half && x <= _xs[i] + half) { return i; }
        }
        return -1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        _d = w * 22 / 100;
        _cy = h * 57 / 100;          // symboles plus bas : place pour la question
        _xs = [w * 32 / 100, w * 68 / 100];
        var r = _d / 2;
        var ring = w / 90;
        if (ring < 2) { ring = 2; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 31 / 100, Graphics.FONT_SMALL, _question,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < 2; i++) {
            var x = _xs[i];
            var color = (i == _sel) ? Graphics.COLOR_WHITE : 0x999999;
            if (i == 0) {
                drawCross(dc, x, _cy, _d, color);
            } else {
                drawCheck(dc, x, _cy, _d, color);
            }
            if (i == _sel) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(ring);
                dc.drawCircle(x, _cy, r + ring * 4);
                dc.setPenWidth(1);
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 82 / 100, Graphics.FONT_SMALL,
            _sel == 0 ? "Annuler" : _yesLabel,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawCross(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        var a = s * 20 / 100;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penFor(s));
        dc.drawLine(cx - a, cy - a, cx + a, cy + a);
        dc.drawLine(cx - a, cy + a, cx + a, cy - a);
        dc.setPenWidth(1);
    }

    private function drawCheck(dc as Graphics.Dc, cx as Number, cy as Number, s as Number, color as Number) as Void {
        var mx = cx - s * 6 / 100;
        var my = cy + s * 16 / 100;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(penFor(s));
        dc.drawLine(cx - s * 24 / 100, cy, mx, my);
        dc.drawLine(mx, my, cx + s * 26 / 100, cy - s * 20 / 100);
        dc.setPenWidth(1);
    }

    private function penFor(s as Number) as Number {
        var t = s * 7 / 100;
        return t < 2 ? 2 : t;
    }
}

// Entrées sans BehaviorDelegate (voir Delegates.mc) : le toucher valide le
// symbole touché ; UP / DOWN changent de choix ; START valide le choix ;
// BACK refuse.
class ConfirmDelegate extends WatchUi.InputDelegate {

    private var _view as ConfirmView;
    private var _onConfirm as Method;

    function initialize(view as ConfirmView, onConfirm as Method) {
        InputDelegate.initialize();
        _view = view;
        _onConfirm = onConfirm;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var key = evt.getKey();
        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            _view.move();
        } else if (key == WatchUi.KEY_ENTER) {
            finish(_view.isConfirmSelected());
        } else if (key == WatchUi.KEY_ESC) {
            finish(false);
        } else {
            return false;
        }
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var xy = evt.getCoordinates();
        var i = _view.indexAt(xy[0], xy[1]);
        if (i >= 0) {
            _view.select(i);
            finish(i == 1);
        }
        return true;
    }

    function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
        var dir = evt.getDirection();
        if (dir == WatchUi.SWIPE_UP || dir == WatchUi.SWIPE_DOWN) {
            _view.move();
            return true;
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            finish(false);   // geste « retour » = refuser
            return true;
        }
        return false;
    }

    private function finish(confirmed as Boolean) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (confirmed) {
            _onConfirm.invoke();
        }
    }
}
