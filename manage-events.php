<?php
// Create and edit conferences, seminars, meetings and online-lab sessions.
// Admin: everything. Team: online-lab sessions and meetings.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin", "team");
$is_admin = $user["role"] === "admin";

$all_types = ["conference" => "Конференция", "seminar" => "Семинар", "lab" => "Онлайн-лаборатория", "meeting" => "Встреча"];
$types = $is_admin ? $all_types : array_intersect_key($all_types, ["lab" => 1, "meeting" => 1]);

function can_manage($ev, $types)
{
    return $ev && isset($types[$ev["type"]]);
}

if (is_post()) {
    $id = (int)post("id");
    $existing = $id ? row("SELECT * FROM events WHERE id = ?", [$id]) : null;

    if ($id && !can_manage($existing, $types)) {
        die("Доступ запрещён.");
    }

    if (post("action") === "delete" && $existing) {
        q("DELETE FROM events WHERE id = ?", [$id]);
        flash("Мероприятие удалено.");
        redirect("manage-events.php");
    }

    if (post("action") === "save") {
        $type = isset($types[post("type")]) ? post("type") : array_key_first($types);
        $starts = str_replace("T", " ", post("starts_at"));

        if (post("title") === "" || !strtotime($starts)) {
            flash("Укажите название и дату начала.", "error");
            redirect("manage-events.php" . ($id ? "?edit=" . $id : "?new=1"));
        }

        $data = [
            $type, post("title"), post("description"), date("Y-m-d H:i:s", strtotime($starts)),
            max(5, (int)post("duration_min", "60")), post("location"), safe_url(post("zoom_url")),
            max(0, (int)post("capacity")), max(0, (float)post("price")),
            isset($_POST["pro_only"]) ? 1 : 0, isset($_POST["published"]) ? 1 : 0,
            (int)post("host_id") ?: null,
        ];

        if ($existing) {
            q("UPDATE events SET type = ?, title = ?, description = ?, starts_at = ?, duration_min = ?, location = ?, zoom_url = ?,
               capacity = ?, price = ?, pro_only = ?, published = ?, host_id = ? WHERE id = ?", array_merge($data, [$id]));
        } else {
            q("INSERT INTO events (type, title, description, starts_at, duration_min, location, zoom_url, capacity, price, pro_only, published, host_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", $data);
            $id = insert_id();
        }

        flash("Сохранено.");
        redirect("manage-events.php");
    }
}

$edit = null;
if (isset($_GET["edit"])) {
    $edit = row("SELECT * FROM events WHERE id = ?", [(int)$_GET["edit"]]);
    if (!can_manage($edit, $types)) {
        $edit = null;
    }
}
$show_form = $edit || isset($_GET["new"]);

$regs_for = isset($_GET["regs"]) ? row("SELECT * FROM events WHERE id = ?", [(int)$_GET["regs"]]) : null;
$regs = $regs_for ? rows("SELECT u.name, u.email, u.phone, u.organization, r.created_at FROM event_regs r JOIN users u ON u.id = r.user_id
                          WHERE r.event_id = ? AND r.status = 'registered' ORDER BY r.created_at", [(int)$regs_for["id"]]) : [];

$type_list = "'" . implode("','", array_keys($types)) . "'";
$events = rows("
    SELECT e.*, (SELECT COUNT(*) FROM event_regs r WHERE r.event_id = e.id AND r.status = 'registered') AS regs
    FROM events e WHERE e.type IN ($type_list)
    ORDER BY e.starts_at < NOW() - INTERVAL 3 HOUR, e.starts_at");

$staff = rows("SELECT id, name FROM users WHERE role IN ('admin', 'team') ORDER BY name");
$v = $edit ?: ["type" => $is_admin ? "conference" : "lab", "title" => "", "description" => "", "starts_at" => date("Y-m-d 10:00", strtotime("+7 days")),
               "duration_min" => 90, "location" => "Онлайн (Zoom)", "zoom_url" => "", "capacity" => 0, "price" => 0, "pro_only" => 0, "published" => 1, "host_id" => $user["id"]];

page_header("Конференции и встречи", $user);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold"><?= $is_admin ? "Конференции, семинары и встречи" : "Онлайн-лаборатория и встречи" ?></h1>
    <a href="manage-events.php?new=1" class="btn btn-primary">＋ Создать</a>
</div>

<?php if ($show_form): ?>
<form method="POST" class="card p-6 mb-6 space-y-4">
    <?= csrf_field() ?><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<?= (int)($edit["id"] ?? 0) ?>">
    <h2 class="text-xl font-bold"><?= $edit ? "Редактировать" : "Новое мероприятие" ?></h2>

    <div class="grid md:grid-cols-3 gap-4">
        <div><label class="label">Тип</label>
            <select class="field" name="type"><?php foreach ($types as $k => $label): ?><option value="<?= $k ?>" <?= $v["type"] === $k ? "selected" : "" ?>><?= $label ?></option><?php endforeach; ?></select>
        </div>
        <div class="md:col-span-2"><label class="label">Название</label><input class="field" name="title" value="<?= e($v["title"]) ?>" required></div>
    </div>

    <div><label class="label">Описание (программа, спикеры, для кого)</label><textarea class="field" name="description" rows="6"><?= e($v["description"]) ?></textarea></div>

    <div class="grid md:grid-cols-4 gap-4">
        <div><label class="label">Начало</label><input class="field" type="datetime-local" name="starts_at" value="<?= e(date("Y-m-d\TH:i", strtotime($v["starts_at"]))) ?>" required></div>
        <div><label class="label">Длительность, мин</label><input class="field" type="number" name="duration_min" value="<?= (int)$v["duration_min"] ?>" min="5"></div>
        <div><label class="label">Мест (0 = без лимита)</label><input class="field" type="number" name="capacity" value="<?= (int)$v["capacity"] ?>" min="0"></div>
        <div><label class="label">Цена, <?= e($settings["currency"]) ?> (0 = бесплатно)</label><input class="field" type="number" step="0.01" name="price" value="<?= e($v["price"]) ?>" min="0"></div>
    </div>

    <div class="grid md:grid-cols-3 gap-4">
        <div><label class="label">Ссылка Zoom / Meet</label><input class="field" type="url" name="zoom_url" value="<?= e($v["zoom_url"]) ?>" placeholder="https://zoom.us/j/..."></div>
        <div><label class="label">Место</label><input class="field" name="location" value="<?= e($v["location"]) ?>"></div>
        <div><label class="label">Ведущий</label>
            <select class="field" name="host_id"><option value="">—</option><?php foreach ($staff as $s): ?><option value="<?= (int)$s["id"] ?>" <?= (int)$v["host_id"] === (int)$s["id"] ? "selected" : "" ?>><?= e($s["name"]) ?></option><?php endforeach; ?></select>
        </div>
    </div>

    <p class="text-sm text-slate-500">Ссылку Zoom видят только записавшиеся участники.</p>

    <div class="flex flex-wrap gap-6">
        <label class="flex gap-2 items-center"><input type="checkbox" name="pro_only" <?= $v["pro_only"] ? "checked" : "" ?>> Только для NII Pro</label>
        <label class="flex gap-2 items-center"><input type="checkbox" name="published" <?= $v["published"] ? "checked" : "" ?>> Опубликовано (видно участникам)</label>
    </div>

    <div class="flex gap-3">
        <button class="btn btn-primary">Сохранить</button>
        <a href="manage-events.php" class="btn btn-light">Отмена</a>
    </div>
</form>
<?php endif; ?>

<?php if ($regs_for): ?>
<div class="card p-6 mb-6">
    <div class="flex justify-between gap-3"><h2 class="text-xl font-bold">Участники: <?= e($regs_for["title"]) ?></h2><a href="manage-events.php" class="text-slate-500">✕</a></div>
    <p class="text-slate-500 mb-3">Всего: <?= count($regs) ?></p>
    <div class="overflow-x-auto"><table class="w-full text-sm">
        <tr class="text-left text-slate-500 border-b"><th class="py-2 pr-3">Имя</th><th class="pr-3">Email</th><th class="pr-3">Телефон</th><th class="pr-3">Организация</th><th>Записался</th></tr>
        <?php foreach ($regs as $r): ?>
        <tr class="border-b"><td class="py-2 pr-3"><?= e($r["name"]) ?></td><td class="pr-3"><?= e($r["email"]) ?></td><td class="pr-3"><?= e($r["phone"]) ?></td><td class="pr-3"><?= e($r["organization"]) ?></td><td><?= fmt_dt($r["created_at"]) ?></td></tr>
        <?php endforeach; ?>
    </table></div>
</div>
<?php endif; ?>

<div class="card divide-y">
    <?php if (!$events): ?><p class="p-6 text-slate-500">Пока ничего нет. Нажмите «Создать».</p><?php endif; ?>
    <?php foreach ($events as $ev): $past = strtotime($ev["starts_at"]) < time() - 3 * 3600; ?>
    <div class="p-4 flex flex-wrap gap-3 items-center <?= $past ? "opacity-60" : "" ?>">
        <div class="flex-1 min-w-48">
            <p class="text-sm text-slate-500"><?= fmt_dt($ev["starts_at"]) ?> · <?= e($all_types[$ev["type"]]) ?><?= $ev["published"] ? "" : " · черновик" ?><?= $past ? " · прошло" : "" ?></p>
            <p class="font-bold"><?= e($ev["title"]) ?></p>
            <p class="text-sm text-slate-500"><?= $ev["price"] > 0 ? e(money($ev["price"])) : "бесплатно" ?><?= $ev["pro_only"] ? " · PRO" : "" ?><?= $ev["zoom_url"] ? " · Zoom ✓" : " · без ссылки Zoom" ?></p>
        </div>
        <a href="manage-events.php?regs=<?= (int)$ev["id"] ?>" class="btn btn-light">👥 <?= (int)$ev["regs"] ?><?= $ev["capacity"] ? " / " . (int)$ev["capacity"] : "" ?></a>
        <a href="event.php?id=<?= (int)$ev["id"] ?>" class="btn btn-light">👁️</a>
        <a href="manage-events.php?edit=<?= (int)$ev["id"] ?>" class="btn btn-light">✏️</a>
        <form method="POST" onsubmit="return confirm('Удалить мероприятие и все записи на него?')">
            <?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$ev["id"] ?>">
            <button class="btn btn-danger">🗑️</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>
<?php page_footer();
