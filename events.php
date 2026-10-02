<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();

$types = [
    ""           => "Все",
    "conference" => "Конференции",
    "seminar"    => "Семинары",
    "lab"        => "Онлайн-лаборатория",
    "meeting"    => "Встречи",
];
$type = isset($types[$_GET["type"] ?? ""]) ? ($_GET["type"] ?? "") : "";

$events = rows("
    SELECT e.*,
        (SELECT COUNT(*) FROM event_regs r WHERE r.event_id = e.id AND r.status = 'registered') AS regs,
        (SELECT status FROM event_regs r WHERE r.event_id = e.id AND r.user_id = ?) AS my_status
    FROM events e
    WHERE e.published = 1 AND e.starts_at >= NOW() - INTERVAL 3 HOUR " . ($type ? "AND e.type = ?" : "") . "
    ORDER BY e.starts_at", $type ? [(int)$user["id"], $type] : [(int)$user["id"]]);

page_header("События", $user);
?>
<h1 class="text-2xl font-bold">Конференции, семинары и онлайн-лаборатория</h1>

<div class="flex gap-2 overflow-x-auto my-4 text-sm">
<?php foreach ($types as $k => $label): ?>
    <a href="events.php?type=<?= $k ?>" class="px-3 py-1.5 rounded-full whitespace-nowrap <?= $type === $k ? "bg-blue-900 text-white" : "bg-white" ?>"><?= $label ?></a>
<?php endforeach; ?>
</div>

<?php if (!$events): ?><div class="card p-6 text-slate-500">Пока нет запланированных мероприятий.</div><?php endif; ?>

<div class="grid md:grid-cols-2 gap-4">
<?php foreach ($events as $ev): $full = $ev["capacity"] && $ev["regs"] >= $ev["capacity"]; ?>
    <a href="event.php?id=<?= (int)$ev["id"] ?>" class="card p-5 block">
        <div class="flex justify-between gap-2">
            <span class="chip bg-blue-100 text-blue-900"><?= e($types[$ev["type"]] ?? $ev["type"]) ?></span>
            <span class="flex gap-1">
                <?php if ($ev["pro_only"]): ?><span class="chip bg-amber-200 text-amber-900">PRO</span><?php endif; ?>
                <?php if ($ev["my_status"] === "registered"): ?><span class="chip bg-green-100 text-green-800">Вы записаны</span><?php endif; ?>
            </span>
        </div>
        <h2 class="font-bold text-lg mt-2"><?= e($ev["title"]) ?></h2>
        <p class="text-slate-600 text-sm mt-1">📅 <?= fmt_dt($ev["starts_at"]) ?> · <?= (int)$ev["duration_min"] ?> мин</p>
        <p class="text-sm mt-1">
            <?= $ev["price"] > 0 ? "💳 " . e(money($ev["price"])) : "Бесплатно" ?>
            <?php if ($ev["capacity"]): ?> · <?= $full ? '<span class="text-red-600">мест нет</span>' : "свободно " . ((int)$ev["capacity"] - (int)$ev["regs"]) ?><?php endif; ?>
        </p>
    </a>
<?php endforeach; ?>
</div>
<?php page_footer();
