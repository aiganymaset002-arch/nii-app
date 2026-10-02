<?php
// Printable certificate for a finished course.

require_once "config.php";

$user = require_login();
$id = (int)($_GET["course"] ?? 0);

$course = row("SELECT * FROM courses WHERE id = ?", [$id]);
$total = (int)row("SELECT COUNT(*) n FROM lessons WHERE course_id = ?", [$id])["n"];
$done = (int)row("SELECT COUNT(*) n FROM lesson_progress lp JOIN lessons l ON l.id = lp.lesson_id WHERE l.course_id = ? AND lp.user_id = ?", [$id, (int)$user["id"]])["n"];
$last = row("SELECT MAX(lp.done_at) d FROM lesson_progress lp JOIN lessons l ON l.id = lp.lesson_id WHERE l.course_id = ? AND lp.user_id = ?", [$id, (int)$user["id"]])["d"];

if (!$course || !$total || $done < $total) {
    die("Сертификат будет доступен после прохождения всех уроков.");
}

$number = sprintf("NII-C%03d-U%05d", $id, (int)$user["id"]);
?>
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Сертификат — <?= e($course["title"]) ?></title>
<style>
    @page { size: A4 landscape; margin: 0; }
    body { margin: 0; background: #e2e8f0; font-family: Georgia, "Times New Roman", serif; color: #0f172a; }
    .bar { text-align: center; padding: 16px; font-family: Arial, sans-serif; }
    .bar button { background: #1e3a8a; color: #fff; border: 0; padding: 12px 22px; border-radius: 8px; font-size: 16px; cursor: pointer; }
    .cert { width: 297mm; height: 210mm; margin: 0 auto 24px; background: #fff; box-sizing: border-box; padding: 18mm; position: relative; }
    .frame { border: 3px solid #1e3a8a; outline: 1px solid #a21caf; outline-offset: 6px; height: 100%; box-sizing: border-box; padding: 14mm; text-align: center; }
    .org { letter-spacing: 3px; text-transform: uppercase; color: #1e3a8a; font-family: Arial, sans-serif; font-weight: bold; }
    h1 { font-size: 46px; margin: 14mm 0 4mm; color: #1e3a8a; }
    .name { font-size: 36px; margin: 8mm 0 2mm; border-bottom: 1px solid #94a3b8; display: inline-block; padding: 0 14mm 2mm; }
    .course { font-size: 24px; font-style: italic; margin-top: 4mm; }
    .foot { position: absolute; left: 32mm; right: 32mm; bottom: 30mm; display: flex; justify-content: space-between; font-family: Arial, sans-serif; font-size: 13px; color: #475569; }
    @media print { body { background: #fff; } .bar { display: none; } .cert { margin: 0; } }
</style>
</head>
<body>
<div class="bar"><button onclick="window.print()">🖨 Распечатать / сохранить PDF</button></div>
<div class="cert">
    <div class="frame">
        <div class="org"><?= e($settings["org_name"]) ?> · NII Inclusive Engineering</div>
        <h1>СЕРТИФИКАТ</h1>
        <div>подтверждает, что</div>
        <div class="name"><?= e($user["name"]) ?></div>
        <div style="margin-top:4mm">успешно прошёл(а) курс</div>
        <div class="course">«<?= e($course["title"]) ?>»</div>
        <div style="margin-top:6mm">(<?= $total ?> уроков)</div>
    </div>
    <div class="foot">
        <span>Дата: <?= fmt_date($last) ?></span>
        <span>Science × Technology × Inclusion × Impact</span>
        <span>№ <?= e($number) ?></span>
    </div>
</div>
</body>
</html>
