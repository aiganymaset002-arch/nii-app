<?php
// Tasks. Admin: all tasks, create/assign/delete. Team: own tasks, mark done.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin", "team");
$is_admin = $user["role"] === "admin";
$uid = (int)$user["id"];

if (is_post()) {
    $action = post("action");
    $id = (int)post("id");

    // Team members may only touch their own tasks
    $task = $id ? row("SELECT * FROM tasks WHERE id = ?", [$id]) : null;
    $can_edit = $task && ($is_admin || (int)$task["assignee_id"] === $uid);

    if ($action === "add" && post("title") !== "") {
        $assignee = $is_admin ? ((int)post("assignee_id") ?: null) : $uid;
        $priority = in_array(post("priority"), ["low", "normal", "high"], true) ? post("priority") : "normal";
        q("INSERT INTO tasks (title, description, due_date, priority, assignee_id, created_by) VALUES (?, ?, NULLIF(?, ''), ?, ?, ?)",
          [post("title"), post("description"), post("due_date"), $priority, $assignee, $uid]);
        flash("Задача добавлена.");
    } elseif ($action === "toggle" && $can_edit) {
        q("UPDATE tasks SET status = IF(status = 'done', 'todo', 'done'), done_at = IF(status = 'done', NOW(), NULL) WHERE id = ?", [$id]);
    } elseif ($action === "delete" && $can_edit && $is_admin) {
        q("DELETE FROM tasks WHERE id = ?", [$id]);
        flash("Задача удалена.");
    } elseif ($action === "move" && $can_edit) {
        q("UPDATE tasks SET due_date = NULLIF(?, '') WHERE id = ?", [post("due_date"), $id]);
    }

    $back = $_POST["back"] ?? "";
    redirect(preg_match('/^[a-z\-]+\.php(\?[\w=&%\-]*)?$/', $back) ? $back : "tasks.php");
}

$view = $_GET["view"] ?? "today";
$who = $is_admin ? ($_GET["who"] ?? "all") : "me";

$where = [];
$params = [];

if ($who === "me") { $where[] = "(t.assignee_id = ? OR (t.assignee_id IS NULL AND t.created_by = ?))"; $params[] = $uid; $params[] = $uid; }
elseif (ctype_digit((string)$who)) { $where[] = "t.assignee_id = ?"; $params[] = (int)$who; }

switch ($view) {
    case "today":   $where[] = "t.status = 'todo' AND (t.due_date IS NULL OR t.due_date <= CURDATE())"; break;
    case "week":    $where[] = "t.status = 'todo' AND t.due_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 7 DAY"; break;
    case "open":    $where[] = "t.status = 'todo'"; break;
    case "done":    $where[] = "t.status = 'done'"; break;
}

$tasks = rows("
    SELECT t.*, u.name AS assignee
    FROM tasks t LEFT JOIN users u ON u.id = t.assignee_id
    " . ($where ? "WHERE " . implode(" AND ", $where) : "") . "
    ORDER BY t.status, t.due_date IS NULL, t.due_date, FIELD(t.priority, 'high', 'normal', 'low'), t.id
    LIMIT 300", $params);

$team = $is_admin ? rows("SELECT id, name, role FROM users WHERE role IN ('admin', 'team') ORDER BY role, name") : [];
$today = date("Y-m-d");
$self = "tasks.php?view=" . urlencode($view) . "&who=" . urlencode($who);

page_header("Задачи", $user);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold"><?= $is_admin ? "Задачи НИИ" : "Мои задачи" ?></h1>
    <?php if ($is_admin): ?><a href="roadmap.php" class="btn btn-light">🗺️ План 90 дней</a><?php endif; ?>
</div>

<div class="flex flex-wrap gap-2 mb-4 text-sm">
    <?php foreach (["today" => "На сегодня", "week" => "Неделя", "open" => "Все открытые", "done" => "Выполненные", "all" => "Все"] as $k => $label): ?>
        <a href="tasks.php?view=<?= $k ?>&who=<?= e($who) ?>" class="px-3 py-1.5 rounded-full <?= $view === $k ? "bg-blue-900 text-white" : "bg-white" ?>"><?= $label ?></a>
    <?php endforeach; ?>
    <?php if ($is_admin): ?>
        <form method="GET" class="ml-auto">
            <input type="hidden" name="view" value="<?= e($view) ?>">
            <select name="who" class="field !py-1.5 !w-auto" onchange="this.form.submit()">
                <option value="all">Все исполнители</option>
                <option value="me" <?= $who === "me" ? "selected" : "" ?>>Только мои</option>
                <?php foreach ($team as $m): ?><option value="<?= (int)$m["id"] ?>" <?= $who === (string)$m["id"] ? "selected" : "" ?>><?= e($m["name"]) ?></option><?php endforeach; ?>
            </select>
        </form>
    <?php endif; ?>
</div>

<form method="POST" class="card p-4 mb-6 grid md:grid-cols-12 gap-3 items-end">
    <?= csrf_field() ?>
    <input type="hidden" name="action" value="add">
    <input type="hidden" name="back" value="<?= e($self) ?>">
    <div class="md:col-span-5"><label class="label">Новая задача</label><input class="field" name="title" required placeholder="Что нужно сделать?"></div>
    <div class="md:col-span-2"><label class="label">Срок</label><input class="field" type="date" name="due_date" value="<?= $today ?>"></div>
    <?php if ($is_admin): ?>
    <div class="md:col-span-2"><label class="label">Исполнитель</label>
        <select class="field" name="assignee_id"><option value="">Я</option><?php foreach ($team as $m): if ((int)$m["id"] === $uid) continue; ?><option value="<?= (int)$m["id"] ?>"><?= e($m["name"]) ?></option><?php endforeach; ?></select>
    </div>
    <?php endif; ?>
    <div class="md:col-span-2"><label class="label">Приоритет</label>
        <select class="field" name="priority"><option value="normal">Обычный</option><option value="high">🔥 Высокий</option><option value="low">Низкий</option></select>
    </div>
    <div class="<?= $is_admin ? "md:col-span-1" : "md:col-span-3" ?>"><button class="btn btn-primary w-full">＋</button></div>
    <div class="md:col-span-12"><input class="field" name="description" placeholder="Описание (необязательно)"></div>
</form>

<?php if (!$tasks): ?><div class="card p-6 text-center text-slate-500">Задач нет 🎉</div><?php endif; ?>

<div class="card divide-y">
<?php foreach ($tasks as $t): $overdue = $t["status"] === "todo" && $t["due_date"] && $t["due_date"] < $today; ?>
    <div class="p-4 flex gap-3 items-start">
        <form method="POST">
            <?= csrf_field() ?><input type="hidden" name="action" value="toggle"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>"><input type="hidden" name="back" value="<?= e($self) ?>">
            <button class="w-7 h-7 rounded-lg border-2 flex items-center justify-center <?= $t["status"] === "done" ? "bg-green-600 border-green-600 text-white" : "border-slate-300" ?>" title="Готово"><?= $t["status"] === "done" ? "✓" : "" ?></button>
        </form>
        <div class="flex-1 min-w-0">
            <p class="font-semibold <?= $t["status"] === "done" ? "line-through text-slate-400" : "" ?>">
                <?= $t["priority"] === "high" ? "🔥 " : "" ?><?= e($t["title"]) ?>
                <?php if ($t["week"] !== null): ?><span class="chip bg-indigo-100 text-indigo-800 ml-1"><?= week_label($t["week"]) ?></span><?php endif; ?>
            </p>
            <?php if ($t["description"]): ?><p class="text-sm text-slate-500"><?= e($t["description"]) ?></p><?php endif; ?>
            <p class="text-xs mt-1 <?= $overdue ? "text-red-600 font-bold" : "text-slate-500" ?>">
                <?= $t["due_date"] ? ($overdue ? "Просрочено: " : "Срок: ") . fmt_date($t["due_date"]) : "Без срока" ?>
                <?php if ($is_admin && $t["assignee"]): ?> · 👤 <?= e($t["assignee"]) ?><?php endif; ?>
            </p>
        </div>
        <?php if ($t["status"] === "todo"): ?>
        <form method="POST" class="hidden sm:block">
            <?= csrf_field() ?><input type="hidden" name="action" value="move"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>"><input type="hidden" name="back" value="<?= e($self) ?>">
            <input type="date" name="due_date" value="<?= e($t["due_date"]) ?>" class="field !py-1 !w-36 text-sm" onchange="this.form.submit()" title="Перенести">
        </form>
        <?php endif; ?>
        <?php if ($is_admin): ?>
        <form method="POST" onsubmit="return confirm('Удалить задачу?')">
            <?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>"><input type="hidden" name="back" value="<?= e($self) ?>">
            <button class="text-slate-400 hover:text-red-600 px-1" title="Удалить">✕</button>
        </form>
        <?php endif; ?>
    </div>
<?php endforeach; ?>
</div>
<?php page_footer();
