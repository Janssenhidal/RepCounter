using Toybox.Communications;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.PersistedContent;
using Toybox.System;

// HTTPS companion service; the /api/transfer route must host the backup API.
// Local simulator override: http://127.0.0.1:3000/api/transfer
module BackupConfig {
    const URL = "https://backup.execureach.co/api/transfer";
}

class BackupTransfer extends WatchUi.View {
    var main as PullUpCounterView;
    var exporter as WorkoutBackup or Null = null;
    var importer;
    var code = "";
    var token = "";
    var message = "Connecting...";
    var sequence = 0;
    var total = 0;
    var action = "";
    var closed = false;
    var started = false;
    var committed = false;
    var busy = true;

    function initialize(view as PullUpCounterView) {
        View.initialize(); main = view;
        if (main.workoutReady) { exporter = new WorkoutBackup(main.workoutStore); }
        main.workoutReady = false;
    }
    function onShow() as Void {
        if (!started) { started = true; request("create", {}); }
    }
    function onUpdate(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        var x = dc.getWidth() / 2;
        dc.drawText(x, 48, Graphics.FONT_XTINY, "BACKUP / RESTORE", Graphics.TEXT_JUSTIFY_CENTER);
        if (!code.equals("")) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK);
            dc.drawText(x, 90, Graphics.FONT_SMALL, code.substring(0, 6) + " " + code.substring(6, 12), Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(x, 140, Graphics.FONT_XTINY, message, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(x, 245, Graphics.FONT_XTINY, busy ? "BACK to cancel" : "MENU to restore", Graphics.TEXT_JUSTIFY_CENTER);
    }
    function request(name as Lang.String, data as Lang.Dictionary) as Void {
        if (closed) { return; }
        action = name; data["action"] = name; data["code"] = code; data["token"] = token;
        try {
            Communications.makeWebRequest(BackupConfig.URL, data,
                { :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON }, method(:response));
        } catch (error) { failed(); }
    }
    function failed() as Void {
        busy = false;
        message = committed ? "Restore applied.\nBACK to reload workout." : "Transfer failed.\nHistory kept.\nReconnect and retry.";
        WatchUi.requestUpdate();
    }
    function response(status as Lang.Number, data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null) as Void {
        if (closed) { return; }
        if (status != 200 || !(data instanceof Lang.Dictionary)) {
            System.println("Backup request " + action + " failed: " + status.format("%d"));
            failed();
            if (!committed) {
                message = "Transfer failed (" + status.format("%d") + ").\nHistory kept.";
                if (status == -1001) { message = "HTTPS required (-1001).\nDisable device HTTPS\nin simulator settings."; }
            }
            WatchUi.requestUpdate();
            return;
        }
        var result = data as Lang.Dictionary;
        try {
            if (action.equals("create")) {
                code = result["code"]; token = result["token"]; sendNext();
            } else if (action.equals("record")) {
                if (result["next"] != sequence + 1) { failed(); return; }
                sequence += 1; sendNext();
            } else if (action.equals("restore-info")) {
                total = result["records"];
                busy = false;
                var menu = new WatchUi.Menu2({ :title => "Replace history?" });
                menu.addItem(new WatchUi.MenuItem("Cancel", "Keep existing workouts", :cancel, {}));
                menu.addItem(new WatchUi.MenuItem("Replace", result["workouts"].format("%d") + " saved workouts", :replace, {}));
                WatchUi.pushView(menu, new BackupConfirm(self), WatchUi.SLIDE_UP);
            } else if (action.equals("restored")) {
                busy = false; message = "Restore complete.\nBACK to workout.";
            } else if (action.equals("restore-record")) {
                (importer as WorkoutRestore).accept(result["record"] as Lang.Dictionary);
                sequence += 1;
                if (sequence == total) {
                    (importer as WorkoutRestore).commit();
                    committed = true;
                    main.workoutStore = new WorkoutStore(new SelectedWorkoutStorage(new WorkoutStorage(), null));
                    main.reloadSettings(); main.reloadCurrentWorkout();
                    busy = false; message = "Restore complete.\nBACK to workout.";
                    request("restored", {});
                } else { request("restore-record", { "sequence" => sequence }); }
            }
        } catch (error) { failed(); }
        WatchUi.requestUpdate();
    }
    function sendNext() as Void {
        if (exporter == null) {
            busy = false;
            message = "Upload backup on webpage.\nMENU to restore.\nCurrent data unavailable.";
            return;
        }
        var record = exporter.next();
        if (record == null) {
            busy = false; message = "Backup ready.\nEnter code on webpage.\nDownload within 15 min.";
        } else {
            message = "Sending backup...\n" + sequence.format("%d") + " records";
            request("record", { "sequence" => sequence, "record" => record });
        }
    }
    function checkRestore() as Void {
        if (!busy && !code.equals("")) { busy = true; request("restore-info", {}); }
    }
    function restore() as Void {
        try {
            importer = new WorkoutRestore(new WorkoutStorage());
            sequence = 0; busy = true; message = "Restoring...\nKeep app open.";
            request("restore-record", { "sequence" => 0 });
        } catch (error) { failed(); }
    }
    function close() as Void {
        closed = true;
        // Reload the authoritative pointer even if a final response was interrupted.
        main.workoutReady = false;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        main.ensureWorkoutReady();
    }
}
class BackupTransferDelegate extends WatchUi.BehaviorDelegate {
    var transfer as BackupTransfer;
    function initialize(view as BackupTransfer) { BehaviorDelegate.initialize(); transfer = view; }
    function onBack() as Lang.Boolean { transfer.close(); return true; }
    function onMenu() as Lang.Boolean { transfer.checkRestore(); return true; }
}
class BackupConfirm extends WatchUi.Menu2InputDelegate {
    var transfer as BackupTransfer;
    function initialize(view as BackupTransfer) { Menu2InputDelegate.initialize(); transfer = view; }
    function onSelect(item) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (item.getId() == :replace) { transfer.restore(); }
    }
}







