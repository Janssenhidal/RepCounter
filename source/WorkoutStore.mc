using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

// Kept separate so storage failures and restart recovery can be tested.
class WorkoutStorage {
    function initialize() { }
    function get(key) { return Application.Storage.getValue(key); }
    function put(key, value) { Application.Storage.setValue(key, value); }
    function remove(key) { Application.Storage.deleteValue(key); }
}

class WorkoutStore {
    const INDEX_KEY = "workouts.v1";
    const CHUNK_SIZE = 100;
    const PAGE_SIZE = 100;
    var storage as WorkoutStorage;

    function initialize(backend as WorkoutStorage) {
        storage = backend;
    }

    function readIndex() as Lang.Dictionary {
        var saved = storage.get(INDEX_KEY);
        if (saved == null) {
            return emptyIndex(1, 0);
        }
        var index = saved as Lang.Dictionary;
        if (index["version"] == 1) { return migrate(index); }
        if (index["version"] != 2) {
            throw new Lang.InvalidValueException("Unsupported workout history version");
        }
        return index;
    }

    function emptyIndex(nextId, count) as Lang.Dictionary {
        return { "version" => 2, "nextId" => nextId, "count" => count,
            "writing" => null, "publishing" => null, "deleting" => null,
            "clearCurrent" => false };
    }

    function pageNumber(id) { return (id - 1) / PAGE_SIZE; }
    function pageKey(page) { return "workouts.page.v2." + page.format("%d"); }
    function readPage(page) as Lang.Array {
        var saved = storage.get(pageKey(page));
        return saved == null ? [] : saved as Lang.Array;
    }
    function putSummary(summary as Lang.Dictionary) as Void {
        var page = pageNumber(summary["id"]);
        var entries = readPage(page);
        for (var i = 0; i < entries.size(); i += 1) {
            if ((entries[i] as Lang.Dictionary)["id"] == summary["id"]) { return; }
        }
        entries.add(summary);
        storage.put(pageKey(page), entries);
    }
    function getSummary(id) {
        var entries = readPage(pageNumber(id));
        for (var i = 0; i < entries.size(); i += 1) {
            var entry = entries[i] as Lang.Dictionary;
            if (entry["id"] == id) { return entry; }
        }
        return null;
    }
    function removeSummary(id) as Void {
        var page = pageNumber(id);
        var entries = readPage(page);
        var kept = [];
        for (var i = 0; i < entries.size(); i += 1) {
            if ((entries[i] as Lang.Dictionary)["id"] != id) { kept.add(entries[i]); }
        }
        if (kept.size() == entries.size()) { return; }
        if (kept.size() == 0) { storage.remove(pageKey(page)); }
        else { storage.put(pageKey(page), kept); }
    }
    function count() { return readIndex()["count"]; }
    function nextId() { return readIndex()["nextId"]; }

    // Bounded reads in both directions keep the on-screen list independent of archive size.
    function before(id, limit) as Lang.Array {
        var result = [];
        for (var page = pageNumber(id - 1); page >= 0; page -= 1) {
            var entries = readPage(page);
            for (var i = entries.size() - 1; i >= 0; i -= 1) {
                var entry = entries[i] as Lang.Dictionary;
                if (entry["id"] < id) { result.add(entry); }
                if (result.size() == limit) { return result; }
            }
        }
        return result;
    }
    function after(id, limit) as Lang.Array {
        var result = [];
        var lastPage = pageNumber(nextId() - 1);
        for (var page = pageNumber(id); page <= lastPage; page += 1) {
            var entries = readPage(page);
            for (var i = 0; i < entries.size(); i += 1) {
                var entry = entries[i] as Lang.Dictionary;
                if (entry["id"] > id) { result.add(entry); }
                if (result.size() == limit) { return result.reverse(); }
            }
        }
        return result.reverse();
    }

    // Version 1 remains authoritative until every page is written and version 2 commits.
    function migrate(index as Lang.Dictionary) as Lang.Dictionary {
        if (index["writing"] != null) { removeChunks(index["writing"] as Lang.Dictionary); }
        if (index["clearCurrent"] == true) { clearCurrent(); }
        var garbage = index["garbage"] as Lang.Array;
        for (var i = 0; i < garbage.size(); i += 1) { removeChunks(garbage[i] as Lang.Dictionary); }
        var entries = index["workouts"] as Lang.Array;
        for (var i = 0; i < entries.size(); i += 1) { putSummary(entries[i] as Lang.Dictionary); }
        var updated = emptyIndex(index["nextId"], entries.size());
        storage.put(INDEX_KEY, updated);
        return updated;
    }

    function clearCurrent() as Void {
        storage.put("goalStart", 0);
        storage.put("pullUps", 0);
        storage.put("totalSets", 0);
        storage.put("restEndTime", 0);
        storage.put("history", []);
    }

    function chunkKey(id, chunk) as Lang.String {
        return "workout.v1." + id.format("%d") + "." + chunk.format("%d");
    }

    function removeChunks(summary as Lang.Dictionary) as Void {
        for (var i = 0; i < summary["chunks"]; i += 1) {
            storage.remove(chunkKey(summary["id"], i));
        }
    }

    // A committed archive is never cleared until it is discoverable in the index.
    // Recovery is idempotent if the app exits between any of these writes.
    function recover() as Void {
        var index = readIndex();
        var changed = false;
        if (index["writing"] != null) {
            var aborted = index["writing"] as Lang.Dictionary;
            removeSummary(aborted["id"]);
            removeChunks(aborted);
            index["writing"] = null;
            changed = true;
        }
        if (index["clearCurrent"] == true) {
            // Publish first: current sets are cleared only after their summary is readable.
            if (index["publishing"] != null) {
                putSummary(index["publishing"] as Lang.Dictionary);
                index["publishing"] = null;
            }
            clearCurrent();
            index["clearCurrent"] = false;
            changed = true;
        }
        if (index["deleting"] != null) {
            var deleted = index["deleting"] as Lang.Dictionary;
            removeSummary(deleted["id"]);
            removeChunks(deleted);
            index["deleting"] = null;
            changed = true;
        }
        if (changed) { storage.put(INDEX_KEY, index); }
    }

    function finish(sets as Lang.Array, reps, setCount) as Lang.Boolean {
        recover();
        if (sets.size() == 0 || setCount <= 0 || reps <= 0) { return false; }
        var index = readIndex();
        var id = index["nextId"];
        var first = sets[0] as Lang.Dictionary;
        var summary = { "id" => id, "start" => first["timestamp"],
            "end" => Time.now().value(), "reps" => reps, "sets" => setCount,
            "chunks" => (sets.size() + CHUNK_SIZE - 1) / CHUNK_SIZE };

        index["writing"] = summary;
        storage.put(INDEX_KEY, index);
        // Five numbers per set; dictionary field names are not repeated on disk.
        for (var start = 0; start < sets.size(); start += CHUNK_SIZE) {
            var rows = [];
            var end = start + CHUNK_SIZE;
            if (end > sets.size()) { end = sets.size(); }
            for (var i = start; i < end; i += 1) {
                var entry = sets[i] as Lang.Dictionary;
                rows.add(AppData.encodeSet(entry));
            }
            storage.put(chunkKey(id, start / CHUNK_SIZE), rows);
        }
        // Allocate the summary before committing, so a full store can still roll back.
        putSummary(summary);
        index["count"] += 1;
        index["nextId"] = id + 1;
        index["writing"] = null;
        index["clearCurrent"] = true;
        storage.put(INDEX_KEY, index);
        recover();
        return true;
    }

    function load(id) as Lang.Array {
        var found = getSummary(id);
        if (found != null) {
            var summary = found as Lang.Dictionary;
            var sets = [];
            for (var chunk = 0; chunk < summary["chunks"]; chunk += 1) {
                var saved = storage.get(chunkKey(id, chunk));
                if (!(saved instanceof Lang.Array)) {
                    throw new Lang.InvalidValueException("Workout data is unavailable");
                }
                var rows = saved as Lang.Array;
                for (var row = 0; row < rows.size(); row += 1) {
                    var values = rows[row] as Lang.Array;
                    sets.add(AppData.decodeSet(values));
                }
            }
            return sets;
        }
        throw new Lang.InvalidValueException("Workout not found");
    }

    function deleteWorkout(id) as Void {
        recover();
        var index = readIndex();
        var summary = getSummary(id);
        if (summary == null) { return; }
        index["deleting"] = summary;
        index["count"] -= 1;
        storage.put(INDEX_KEY, index);
        recover();
    }
}

