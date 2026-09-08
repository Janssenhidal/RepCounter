using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Native menu scrolling handles drag/flick gestures and physical buttons.
class HistoryView extends WatchUi.CustomMenu {
    var history as Lang.Array;
    function initialize(sets as Lang.Array) {
        history = sets;
        var focus = sets.size() > 0 ? sets.size() - 1 : 0;
        CustomMenu.initialize(125, Graphics.COLOR_BLACK, {
            :title => new HistoryLabel("HISTORY"),
            :titleItemHeight => 20,
            :footerItemHeight => 85,
            :focus => focus,
        });
        if (sets.size() == 0) {
            addItem(
                new WatchUi.CustomMenuItem(:empty, {
                    :drawable => new HistoryLabel("NO SETS"),
                })
            );
        }
        for (var i = 0; i < sets.size(); i += 1) {
            addItem(
                new WatchUi.CustomMenuItem(i, {
                    :drawable => new HistorySetDrawable(
                        sets[i] as Lang.Dictionary,
                        i == sets.size() - 1
                    ),
                })
            );
        }
    }
}

class HistoryLabel extends WatchUi.Drawable {
    var text;
    function initialize(label) {
        Drawable.initialize({});
        text = label;
    }
    function draw(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        // Keep the heading close to the first row even when the native menu
        // reserves a taller title region on a round display.
        if (text.equals("HISTORY")) {
            var y = dc.getHeight() - dc.getFontHeight(Graphics.FONT_SMALL) - 20;
            if (y < 0) {
                y = 0;
            }
            dc.drawText(
                dc.getWidth() / 2,
                y,
                Graphics.FONT_SMALL,
                text,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2,
                Graphics.FONT_SMALL,
                text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }
}

class HistoryDeleteLabel extends WatchUi.Drawable {
    function initialize() {
        Drawable.initialize({});
    }
    function draw(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2 - 8,
            Graphics.FONT_XTINY,
            "Delete Workout",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class HistorySetDrawable extends WatchUi.Drawable {
    var entry as Lang.Dictionary;
    var isLatest;
    const SIDE_PADDING = 20;
    function initialize(set as Lang.Dictionary, latest) {
        Drawable.initialize({});
        entry = set;
        isLatest = latest;
    }
    function draw(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var y = 8;
        var accentColor = isLatest
            ? Graphics.COLOR_YELLOW
            : Graphics.COLOR_BLUE;
        var detailColor = isLatest
            ? Graphics.COLOR_WHITE
            : Graphics.COLOR_LT_GRAY;
        var totalColor = isLatest
            ? Graphics.COLOR_YELLOW
            : Graphics.COLOR_WHITE;
        var separatorColor = isLatest
            ? Graphics.COLOR_YELLOW
            : Graphics.COLOR_DK_GRAY;
        var info = Gregorian.info(
            new Time.Moment(entry["timestamp"]),
            Time.FORMAT_SHORT
        );

        var timeText =
            info.hour.format("%02d") +
            ":" +
            info.min.format("%02d") +
            ":" +
            info.sec.format("%02d");

        var restMinutes = entry["rest"] / 60;

        var restSeconds = entry["rest"] % 60;

        var restText =
            restMinutes.format("%d") + ":" + restSeconds.format("%02d");

        // SET NUMBER
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            SIDE_PADDING,
            y,
            Graphics.FONT_XTINY,
            "SET " + entry["setNumber"].format("%d"),
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // TIME
        dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            dc.getWidth() - SIDE_PADDING,
            y,
            Graphics.FONT_XTINY,
            timeText,
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        y += 28;

        // INCREMENT
        dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            SIDE_PADDING,
            y,
            Graphics.FONT_XTINY,
            "+" + entry["increment"].format("%d") + " reps",
            Graphics.TEXT_JUSTIFY_LEFT
        );

        // REST
        dc.setColor(detailColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            dc.getWidth() - SIDE_PADDING,
            y,
            Graphics.FONT_XTINY,
            restText + " rest",
            Graphics.TEXT_JUSTIFY_RIGHT
        );

        y += 32;

        // TOTAL COUNTER
        dc.setColor(totalColor, Graphics.COLOR_TRANSPARENT);

        dc.drawText(
            SIDE_PADDING,
            y,
            Graphics.FONT_XTINY,
            "TOTAL " + entry["counter"].format("%d"),
            Graphics.TEXT_JUSTIFY_LEFT
        );

        y += 45;

        // SEPARATOR
        dc.setColor(separatorColor, Graphics.COLOR_TRANSPARENT);

        dc.setPenWidth(isLatest ? 2 : 1);

        dc.drawLine(SIDE_PADDING, y, dc.getWidth() - SIDE_PADDING, y);
    }
}
