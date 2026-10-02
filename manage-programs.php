<?php
// Admin: programs (internships, contests, grants) and their applications.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");
$kinds = ["Стажировка", "Конкурс", "Грант", "Исследовательская программа", "Летняя школа", "Программа"];

if (is_post()) {
    $action = post("action");
    $id = (int)post("id");

    if ($action === "save") {
        $data = [in_array(post("kind"), $kinds, true) ? post("kind") : "Программа", post("title"), post("description"), post("deadline"), isset($_POST["published"]) ? 1 : 0];
        if ($id) {
            q("UPDATE programs SET kind = ?, title = ?, description = ?, deadline = NULLIF(?, ''), published = ? WHERE id = ?", array_merge($data, [$id]));
        } else {
            q("INSERT INTO programs (kind, title, description, deadline, published) VALUES (?, ?, ?, NULLIF(?, ''), ?)", $data);
        }
        flash("Программа сохранена.");
        redirect("manage-programs.php");
    }

    if ($action === "delete") {
        q("DELETE FROM programs WHERE id = ?", [$id]);
        flash("Программа удалена.");
        redirect("manage-programs.php");
    }

    if ($action === "decide") {
        $status = in_array(post("status"), ["submitted", "accepted", "rejected"], true) ? post("status") : "submitted";
        q("UPDATE applications SET status = ?, admin_note = ? WHERE id = ?", [$status, post("admin_note"), (int)post("app_id")]);
        flash("Решение сохранено. Участник увидит его в приложении.");
        redirect("manage-programs.php?apps=" . (int)post("program_id"));
    }
}

$edit = isset($_GET["edit"]) ? row("SELECT * FROM programs WHERE id = ?", [(int)$_GET["edit"]]) : null;
$show_form = $edit || isset($_GET["new"]);
$apps_for = isset($_GET["apps"]) ? row("SELECT * FROM programs WHERE id = ?", [(int)$_GET["apps"]]) : null;
$apps = $apps_for ? rows("SELECT a.*, u.name, u.email, u.phone, u.organization FROM applications a JOIN users u ON u.id = a.user_id
                          WHERE a.program_id = ? ORDER BY FIELD(a.status, 'submitted', 'accepted', 'rejected'), a.created_at", [(int)$apps_for["id"]]) : [];

$programs = rows("SELECT p.*, (SELECT COUNT(*) FROM applications a WHERE a.program_id = p.id) AS total,
                  (SELECT COUNT(*) FROM applications a WHERE a.program_id = p.id AND a.status = 'submitted') AS fresh
                  FROM programs p ORDER BY p.created_at DESC");

page_header("Программы и заявки", $user);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold">Программы и заявки</h1>
    <a href="manage-programs.php?new=1" class="btn btn-primary">＋ Новая программа</a>
</div>

<?php if ($show_form): $v = $edit ?: ["id" => 0, "kind" => "Стажировка", "title" => "", "description" => "", "deadline" => "", "published" => 1]; ?>
<form method="POST" class="card p-6 mb-6 space-y-4">
    <?= csrf_field() ?><input type="hidden" name="action" value="save"><input type="hidden" name="id" value="<?= (int)$v["id"] ?>">
    <div class="grid md:grid-cols-4 gap-4">
        <div><label class="label">Вид</label><select class="field" name="kind"><?php foreach ($kinds as $k): ?><option <?= $v["kind"] === $k ? "selected" : "" ?>><?= $k ?></option><?php endforeach; ?></select></div>
        <div class="md:col-span-2"><label class="label">Название</label><input class="field" name="title" value="<?= e($v["title"]) ?>" required></div>
        <div><label class="label">Дедлайн</label><input class="field" type="date" name="deadline" value="<?= e($v["deadline"]) ?>"></div>
    </div>
    <div><label class="label">Описание: условия, требования, что получат участники</label><textarea class="field" name="description" rows="7"><?= e($v["description"]) ?></textarea></div>
    <label class="flex gap-2 items-center"><input type="checkbox" name="published" <?= $v["published"] ? "checked" : "" ?>> Опубликовано</label>
    <div class="flex gap-3"><button class="btn btn-primary">Сохранить</button><a href="manage-programs.php" class="btn btn-light">Отмена</a></div>
</form>
<?php endif; ?>

<?php if ($apps_for): ?>
<div class="mb-6">
    <div class="flex justify-between gap-3 mb-3"><h2 class="text-xl font-bold">Заявки: <?= e($apps_for["title"]) ?></h2><a href="manage-programs.php" class="text-slate-500">✕</a></div>
    <?php if (!$apps): ?><div class="card p-5 text-slate-500">Заявок пока нет.</div><?php endif; ?>
    <div class="space-y-3">
    <?php foreach ($apps as $a): ?>
        <form method="POST" class="card p-5">
            <?= csrf_field() ?><input type="hidden" name="action" value="decide"><input type="hidden" name="app_id" value="<?= (int)$a["id"] ?>"><input type="hidden" name="program_id" value="<?= (int)$apps_for["id"] ?>">
            <div class="flex flex-wrap justify-between gap-2">
                <div><p class="font-bold"><?= e($a["name"]) ?></p><p class="text-sm text-slate-500"><?= e($a["email"]) ?> · <?= e($a["phone"]) ?> · <?= e($a["organization"]) ?></p></div>
                <p class="text-sm text-slate-500"><?= fmt_dt($a["created_at"]) ?></p>
            </div>
            <p class="mt-3 whitespace-pre-line"><?= e($a["motivation"]) ?></p>
            <?php if ($a["file"]): ?><a href="<?= e(upload_url($a["file"])) ?>" target="_blank" class="text-blue-800 font-semibold text-sm">📎 Файл заявки</a><?php endif; ?>
            <div class="grid md:grid-cols-4 gap-3 mt-3 items-end">
                <div><label class="label">Решение</label>
                    <select class="field" name="status">
                        <option value="submitted" <?= $a["status"] === "submitted" ? "selected" : "" ?>>⏳ На рассмотрении</option>
                        <option value="accepted" <?= $a["status"] === "accepted" ? "selected" : "" ?>>✅ Принять</option>
                        <option value="rejected" <?= $a["status"] === "rejected" ? "selected" : "" ?>>❌ Отклонить</option>
                    </select>
                </div>
                <div class="md:col-span-2"><label class="label">Комментарий участнику</label><input class="field" name="admin_note" value="<?= e($a["admin_note"]) ?>"></div>
                <button class="btn btn-primary">Сохранить</button>
            </div>
        </form>
    <?php endforeach; ?>
    </div>
</div>
<?php endif; ?>

<div class="card divide-y">
    <?php if (!$programs): ?><p class="p-6 text-slate-500">Программ пока нет. Например: «Research Internship», «100 Young Researchers».</p><?php endif; ?>
    <?php foreach ($programs as $p): ?>
    <div class="p-4 flex flex-wrap gap-3 items-center">
        <div class="flex-1 min-w-48">
            <p class="text-sm text-slate-500"><?= e($p["kind"]) ?> · <?= $p["deadline"] ? "до " . fmt_date($p["deadline"]) : "без дедлайна" ?><?= $p["published"] ? "" : " · черновик" ?></p>
            <p class="font-bold"><?= e($p["title"]) ?></p>
        </div>
        <a href="manage-programs.php?apps=<?= (int)$p["id"] ?>" class="btn btn-light">📝 <?= (int)$p["total"] ?><?= $p["fresh"] ? ' <span class="chip bg-orange-500 text-white">' . (int)$p["fresh"] . ' новых</span>' : "" ?></a>
        <a href="manage-programs.php?edit=<?= (int)$p["id"] ?>" class="btn btn-light">✏️</a>
        <form method="POST" onsubmit="return confirm('Удалить программу и все заявки?')">
            <?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$p["id"] ?>">
            <button class="btn btn-danger">🗑️</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>
<?php page_footer();
