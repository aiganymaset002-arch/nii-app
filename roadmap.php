<?php
// "90 days to a large-scale result": the plan as tasks grouped by week.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");

$plan = require __DIR__ . "/roadmap-data.php";
$loaded = (int)row("SELECT COUNT(*) n FROM tasks WHERE week IS NOT NULL")["n"];

if (is_post()) {
    if (post("action") === "load" && !$loaded) {
        $start = strtotime(post("start") ?: date("Y-m-d"));

        foreach ($plan as $week => $items) {
            // Week N ends on day N*7 (week 12 covers days 78–90)
            $due = date("Y-m-d", strtotime("+" . ($week === 12 ? 89 : $week * 7 - 1) . " days", $start));
            foreach ($items as $title) {
                q("INSERT INTO tasks (title, due_date, week, created_by) VALUES (?, ?, ?, ?)", [$title, $due, $week, (int)$user["id"]]);
            }
        }

        flash("План на 90 дней загружен в задачи.");
    }

    if (post("action") === "assign") {
        q("UPDATE tasks SET assignee_id = ? WHERE id = ? AND week IS NOT NULL", [(int)post("assignee_id") ?: null, (int)post("id")]);
    }

    redirect("roadmap.php");
}

$tasks = rows("SELECT t.*, u.name AS assignee FROM tasks t LEFT JOIN users u ON u.id = t.assignee_id WHERE t.week IS NOT NULL ORDER BY t.week, t.id");
$by_week = [];
foreach ($tasks as $t) {
    $by_week[(int)$t["week"]][] = $t;
}

$done = count(array_filter($tasks, fn($t) => $t["status"] === "done"));
$team = rows("SELECT id, name FROM users WHERE role IN ('admin', 'team') ORDER BY name");
$colors = ["bg-blue-600", "bg-sky-600", "bg-teal-600", "bg-green-600", "bg-lime-600", "bg-amber-500", "bg-orange-600", "bg-red-600", "bg-rose-600", "bg-pink-600", "bg-fuchsia-600", "bg-purple-700"];

page_header("План 90 дней", $user);
?>
<div class="rounded-2xl p-6 text-white bg-gradient-to-r from-blue-900 via-indigo-800 to-fuchsia-700">
    <p class="opacity-80">Точка А → Точка Б</p>
    <h1 class="text-2xl md:text-3xl font-bold">90 дней до масштабного результата</h1>
    <p class="opacity-90 mt-1">От исследования — к прототипу, от идеи — к реальному решению.</p>
    <?php if ($loaded): $p = round($done * 100 / max(1, count($tasks))); ?>
        <p class="mt-4 font-semibold"><?= $done ?> из <?= count($tasks) ?> задач · <?= $p ?>%</p>
        <div class="h-3 bg-white/25 rounded-full mt-2"><div class="h-3 bg-white rounded-full" style="width: <?= $p ?>%"></div></div>
    <?php endif; ?>
</div>

<?php if (!$loaded): ?>
<form method="POST" class="card p-6 mt-6 max-w-xl">
    <?= csrf_field() ?><input type="hidden" name="action" value="load">
    <h2 class="text-xl font-bold">Запустить план</h2>
    <p class="text-slate-600 mt-1">Все <?= array_sum(array_map("count", $plan)) ?> задач с карты появятся в «Задачах» со сроками по неделям. Их можно будет назначать команде, переносить и редактировать.</p>
    <label class="label mt-4">День 1 (дата старта)</label>
    <input class="field" type="date" name="start" value="<?= date("Y-m-d") ?>" required>
    <button class="btn btn-primary mt-4">🚀 Загрузить план в задачи</button>
</form>
<?php endif; ?>

<div class="grid md:grid-cols-2 xl:grid-cols-3 gap-4 mt-6">
<?php foreach ($plan as $week => $items): $list = $by_week[$week] ?? []; ?>
    <section class="card overflow-hidden">
        <div class="<?= $colors[$week - 1] ?> text-white px-4 py-2 flex justify-between">
            <strong>Неделя <?= $week ?></strong>
            <span class="opacity-90 text-sm">Дни <?= ($week - 1) * 7 + 1 ?>–<?= $week === 12 ? 90 : $week * 7 ?></span>
        </div>
        <div class="divide-y">
        <?php if (!$list): ?>
            <?php foreach ($items as $title): ?><p class="p-3 text-sm text-slate-600">• <?= e($title) ?></p><?php endforeach; ?>
        <?php endif; ?>
        <?php foreach ($list as $t): ?>
            <div class="p-3 text-sm">
                <div class="flex gap-2 items-start">
                    <form method="POST" action="tasks.php">
                        <?= csrf_field() ?><input type="hidden" name="action" value="toggle"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>"><input type="hidden" name="back" value="roadmap.php">
                        <button class="w-5 h-5 mt-0.5 rounded border-2 flex items-center justify-center text-xs <?= $t["status"] === "done" ? "bg-green-600 border-green-600 text-white" : "border-slate-300" ?>"><?= $t["status"] === "done" ? "✓" : "" ?></button>
                    </form>
                    <span class="<?= $t["status"] === "done" ? "line-through text-slate-400" : "" ?>"><?= e($t["title"]) ?></span>
                </div>
                <form method="POST" class="mt-1 ml-7">
                    <?= csrf_field() ?><input type="hidden" name="action" value="assign"><input type="hidden" name="id" value="<?= (int)$t["id"] ?>">
                    <select name="assignee_id" onchange="this.form.submit()" class="text-xs border rounded px-1 py-0.5 text-slate-600">
                        <option value="">👤 Не назначено</option>
                        <?php foreach ($team as $m): ?><option value="<?= (int)$m["id"] ?>" <?= (int)$t["assignee_id"] === (int)$m["id"] ? "selected" : "" ?>><?= e($m["name"]) ?></option><?php endforeach; ?>
                    </select>
                    <span class="text-xs text-slate-400 ml-1">до <?= fmt_date($t["due_date"]) ?></span>
                </form>
            </div>
        <?php endforeach; ?>
        </div>
    </section>
<?php endforeach; ?>
</div>
<?php page_footer();
