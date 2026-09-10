using Toybox.Graphics;
using Toybox.WatchUi;

module ScreenStyle {
    const TITLE_FONT = Graphics.FONT_XTINY;
    // Pixels from the display top for custom full-screen headings.
    const TITLE_TOP = 50;
    // Native menu heading offset within Garmin's title region.
    const MENU_TITLE_OFFSET = 0;
    function title(dc, text) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            TITLE_TOP,
            TITLE_FONT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}
class ScreenTitle extends WatchUi.Drawable {
    var text;
    function initialize(text) {
        Drawable.initialize({});
        self.text = text;
    }
    function draw(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 + ScreenStyle.MENU_TITLE_OFFSET,
            ScreenStyle.TITLE_FONT,
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
