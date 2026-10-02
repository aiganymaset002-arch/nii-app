<?php
// Organizer dashboard: today's tasks, key results, things waiting for action.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");
$uid = (int)$user["id"];

if (is_post() && post("action") === "kpi") {
    foreach ($_POST["kpi"] ?? [] as $id => $value) {
        q("UPDATE kpis SET current = ? WHERE id = ?", [max(0, (int)$value), (int)$id]);
    }
    flash("Ключевые результаты обновлены.");
    redirect("admin.php");
}

$today_tasks = rows("
    SELECT t.*, u.name AS assignee FROM tasks t LEFT JOIN users u ON u.id = t.assignee_id
    WHERE t.status = 'todo' AND (t.due_date IS NULL OR t.due_date <= CURDATE())
    AND (t.assignee_id IS NULL OR t.assignee_id = ?)
    ORDER BY t.due_date IS NULL, t.due_date, FIELD(t.priority, 'high', 'normal', 'low') LIMIT 12", [$uid]);

$team_open = row("SELECT COUNT(*) n FROM tasks WHERE status = 'todo' AND assignee_id IS NOT NULL AND assignee_id <> ?", [$uid])["n"];
$overdue = row("SELECT COUNT(*) n FROM tasks WHERE status = 'todo' AND due_date < CURDATE()")["n"];
$kpis = rows("SELECT * FROM kpis ORDER BY sort, id");

$stats = [
    ["Участники", row("SELECT COUNT(*) n FROM users WHERE role = 'user'")["n"], "manage-users.php", "👥"],
    ["Pro-подписки", row("SELECT COUNT(*) n FROM users WHERE role = 'user' AND (is_family = 1 OR pro_until >= CURDATE())")["n"], "manage-users.php", "⭐"],
    ["Оплаты на проверке", row("SELECT COUNT(*) n FROM payments WHERE status = 'review'")["n"], "manage-payments.php", "💳"],
    ["Новые заявки", row("SELECT COUNT(*) n FROM applications WHERE status = 'submitted'")["n"], "manage-programs.php", "📝"],
];

$events = rows("
    SELECT e.*, (SELECT COUNT(*) FROM event_regs r WHERE r.event_id = e.id AND r.status = 'registered') AS regs
    FROM events e WHERE e.starts_at >= NOW() - INTERVAL 3 HOUR ORDER BY e.starts_at LIMIT 5");

$roadmap_total = row("SELECT COUNT(*) n, SUM(status = 'done') d FROM tasks WHERE week IS NOT NULL");

page_header("Панель организатора", $user);
?>
<h1 class="text-2xl font-bold">Добрый день, <?= e($user["name"]) ?> 👋</h1>
<p class="text-slate-500"><?= date("d.m.Y") ?> · <?= e($settings["org_name"]) ?></p>

<div class="grid grid-cols-2 md:grid-cols-4 gap-3 mt-5">
<?php foreach ($stats as [$label, $n, $href, $icon]): ?>
    <a href="<?= $href ?>" class="card p-4 block">
        <div class="text-2xl"><?= $icon ?></div>
        <div class="text-3xl font-bold mt-1 <?= ($label === "Оплаты на проверке" || $label === "Новые заявки") && $n > 0 ? "text-orange-600" : "" ?>"><?= (int)$n ?></div>
        <div class="text-sm text-slate-500"><?= $label ?></div>
    </a>
<?php endforeach; ?>
</div>

<div class="grid lg:grid-cols-5 gap-6 mt-6">

    <section class="lg:col-span-3">
        <div class="flex justify-between items-center mb-3">
            <h2 class="text-xl font-bold">Мои задачи на сегодня</h2>
            <a href="tasks.php" class="text-blue-800 text-sm font-semibold">Все задачи →</a>
        </div>

        <form method="POST" action="tasks.php" class="flex gap-2 mb-3">
            <?= csrf_field() ?><input type="hidden" name="action" value="add"><input type="hidden" name="back" value="admin.php">
            <input type="hidden" name="due_date" value="<?= date("Y-m-d") ?>">
            <input class="field" name="title" placeholder="Быстро добавить задачу на сегодня…" required>
            <button class="btn btn-primary">＋</button>
        </form>

        <div class="card divide-y">
            <?php if (!$today_tasks): ?><p class="p-5 text-slate-500">На сегодня всё сделано 🎉</p><?php endif; ?>
            <?php foreach ($today_tasks as $t): $late = $t["due_date"] && $t["due_date"] < date("Y-m-d"); ?>
            <div class="p-3 flex gap-3 items-center">
                <form method="POST" action="tasks.php">
                    <?= csrf_field() ?><input type="hidden" name="action" value="toggle"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>"><input type="hidden" name="back" value="admin.php">
                    <button class="w-6 h-6 rounded-md border-2 border-slate-300" title="Готово"></button>
                </form>
                <div class="flex-1"><?= $t["priority"] === "high" ? "🔥 " : "" ?><?= e($t["title"]) ?>
                    <?php if ($t["week"] !== null): ?><span class="chip bg-indigo-100 text-indigo-800"><?= week_label($t["week"]) ?></span><?php endif; ?>
                </div>
                <?php if ($late): ?><span class="text-xs text-red-600 font-bold"><?= fmt_date($t["due_date"]) ?></span><?php endif; ?>
            </div>
            <?php endforeach; ?>
        </div>

        <p class="text-sm text-slate-500 mt-2">
            У команды открыто задач: <strong><?= (int)$team_open ?></strong>
            <?php if ($overdue): ?> · <span class="text-red-600 font-semibold">просрочено всего: <?= (int)$overdue ?></span><?php endif; ?>
        </p>

        <h2 class="text-xl font-bold mt-8 mb-3">Ближайшие мероприятия</h2>
        <div class="card divide-y">
            <?php if (!$events): ?><p class="p-5 text-slate-500">Нет запланированных. <a href="manage-events.php" class="text-blue-800 font-semibold">Создать →</a></p><?php endif; ?>
            <?php foreach ($events as $ev): ?>
            <a href="manage-events.php?edit=<?= (int)$ev["id"] ?>" class="p-3 flex justify-between gap-3">
                <span><span class="text-slate-500 text-sm"><?= fmt_dt($ev["starts_at"]) ?></span><br><strong><?= e($ev["title"]) ?></strong></span>
                <span class="text-sm text-slate-500 whitespace-nowrap">👥 <?= (int)$ev["regs"] ?><?= $ev["capacity"] ? " / " . (int)$ev["capacity"] : "" ?></span>
            </a>
            <?php endforeach; ?>
        </div>
    </section>

    <section class="lg:col-span-2">
        <div class="flex justify-between items-center mb-3">
            <h2 class="text-xl font-bold">Ключевые результаты · 90 дней</h2>
        </div>

        <a href="roadmap.php" class="card p-4 block mb-4 bg-gradient-to-r from-blue-900 to-fuchsia-700 text-white">
            <p class="text-sm opacity-80">План «90 дней до масштабного результата»</p>
            <?php if ($roadmap_total["n"]): $p = round($roadmap_total["d"] * 100 / $roadmap_total["n"]); ?>
                <p class="text-2xl font-bold"><?= $p ?>% выполнено</p>
                <div class="h-2 bg-white/30 rounded-full mt-2"><div class="h-2 bg-white rounded-full" style="width: <?= $p ?>%"></div></div>
            <?php else: ?>
                <p class="font-bold mt-1">Загрузить план в задачи →</p>
            <?php endif; ?>
        </a>

        <form method="POST" class="card p-4 space-y-4">
            <?= csrf_field() ?><input type="hidden" name="action" value="kpi">
            <?php foreach ($kpis as $k): $p = $k["goal"] ? min(100, round($k["current"] * 100 / $k["goal"])) : 0; ?>
            <div>
                <div class="flex justify-between items-center gap-2 text-sm">
                    <span class="font-semibold"><?= e($k["title"]) ?></span>
                    <span class="whitespace-nowrap"><input type="number" min="0" name="kpi[<?= (int)$k["id"] ?>]" value="<?= (int)$k["current"] ?>" class="w-16 border rounded px-1 text-right"> / <?= (int)$k["goal"] ?></span>
                </div>
                <div class="h-2 bg-slate-200 rounded-full mt-1"><div class="h-2 rounded-full <?= $p >= 100 ? "bg-green-600" : "bg-blue-800" ?>" style="width: <?= $p ?>%"></div></div>
            </div>
            <?php endforeach; ?>
            <button class="btn btn-light w-full">Сохранить прогресс</button>
        </form>
    </section>
</div>
<?php page_footer();
