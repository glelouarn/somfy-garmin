import Toybox.Graphics;
import Toybox.Lang;

// Cadenas façon Somfy, dessinés en vectoriel pour rester nets sur tous les écrans.
//   armed    -> cadenas fermé, corps plein
//   disarmed -> cadenas ouvert, corps en contour
//   partial  -> cadenas fermé, corps à moitié plein (diagonale)
(:glance)
module LockIcon {

    const YELLOW = 0xF2B843;
    const NAVY = 0x22394A;

    // s : diamètre de la zone de l'icône (le rond jaune) ; fg : couleur du trait ;
    // bg : couleur du fond sous l'icône (sert à « creuser » la moitié du cadenas partiel).
    function draw(dc as Graphics.Dc, status as String, cx as Number, cy as Number,
                  s as Number, fg as Number, bg as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var t = s * 6 / 100;            // épaisseur du trait
        if (t < 2) { t = 2; }
        var bw = s * 40 / 100;          // largeur du corps
        var bh = s * 30 / 100;          // hauteur du corps
        var rr = s * 5 / 100;           // arrondi des coins
        var r = s * 12 / 100;           // rayon de l'anse
        var by = cy - s * 4 / 100;      // haut du corps
        var ay = by - s * 7 / 100;      // centre de l'arc de l'anse
        var bx = cx - bw / 2;

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(t);

        if (status.equals("disarmed")) {
            // Corps décalé à droite, en contour ; anse relevée et ouverte à gauche.
            bx += s * 6 / 100;
            dc.drawRoundedRectangle(bx + t / 2, by + t / 2, bw - t, bh - t, rr);
            var acx = bx + s * 1 / 100;
            var ayo = ay - s * 2 / 100;
            dc.drawArc(acx, ayo, r, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            dc.drawLine(acx - r, ayo, acx - r, by - s * 1 / 100);
        } else {
            // Anse fermée.
            dc.drawArc(cx, ay, r, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
            dc.drawLine(cx - r, ay, cx - r, by + t);
            dc.drawLine(cx + r, ay, cx + r, by + t);
            // Corps plein.
            dc.fillRoundedRectangle(bx, by, bw, bh, rr);
            if (status.equals("partial")) {
                // Moitié basse droite « creusée » à la couleur du fond.
                dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([
                    [bx + bw - t, by + t],
                    [bx + bw - t, by + bh - t],
                    [bx + t, by + bh - t]
                ]);
            }
        }
        dc.setPenWidth(1);
    }
}
