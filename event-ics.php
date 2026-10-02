<?php
// Calendar file (.ics) for an event the user is registered for.

require_once "config.php";

$user = require_login();
$id = (int)($_GET["id"] ?? 0);

$ev = row("SELECT e.* FROM events e JOIN event_regs r ON r.event_id = e.id
           WHERE e.id = ? AND r.user_id = ? AND r.status = 'registered'", [$id, (int)$user["id"]]);

if (!$ev) {
    http_response_code(404);
    die("Не найдено.");
}

function ics_text($s)
{
    return str_replace(["\\", ";", ",", "\r\n", "\n"], ["\\\\", "\;", "\\,", "\\n", "\\n"], (string)$s);
}

$start = strtotime($ev["starts_at"]);
$end = $start + $ev["duration_min"] * 60;
$desc = trim($ev["description"] . ($ev["zoom_url"] ? "\n\nZoom: " . $ev["zoom_url"] : ""));

header("Content-Type: text/calendar; charset=utf-8");
header("Content-Disposition: attachment; filename=nii-event-" . $id . ".ics");

echo "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//NII App//RU\r\nBEGIN:VEVENT\r\n";
echo "UID:nii-event-" . $id . "@nii-app\r\n";
echo "DTSTAMP:" . gmdate("Ymd\THis\Z") . "\r\n";
echo "DTSTART:" . gmdate("Ymd\THis\Z", $start) . "\r\n";
echo "DTEND:" . gmdate("Ymd\THis\Z", $end) . "\r\n";
echo "SUMMARY:" . ics_text($ev["title"]) . "\r\n";
echo "DESCRIPTION:" . ics_text($desc) . "\r\n";
if ($ev["zoom_url"] || $ev["location"]) {
    echo "LOCATION:" . ics_text($ev["location"] ?: $ev["zoom_url"]) . "\r\n";
}
echo "END:VEVENT\r\nEND:VCALENDAR\r\n";
