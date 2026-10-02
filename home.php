<?php
// Main screen for participants and team members (admin can preview it too).

require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];

$my_events = rows("
    SELECT events.* FROM event_regs
    JOIN events ON events.id = event_regs.event_id
    WHERE event_regs.user_id = ? AND event_regs.status = 'registered'
    AND events.starts_at >= NOW() - INTERVAL 3 HOUR
    ORDER BY events.starts_at LIMIT 5", [$uid]);

$my_courses = rows("
    SELECT courses.*,
        (SELECT COUNT(*) FROM lessons WHERE lessons.course_id = courses.id) AS total,
        (SELECT COUNT(*) FROM lesson_progress lp JOIN lessons l ON l.id = lp.lesson_id
            WHERE l.course_id = courses.id AND lp.user_id = ?) AS done
    FROM enrollments JOIN courses ON courses.id = enrollments.course_id
    WHERE enrollments.user_id = ? ORDER BY enrollments.created_at DESC LIMIT 4", [$uid, $uid]);

$upcoming = rows("SELECT * FROM events WHERE published = 1 AND starts_at >= NOW() AND type IN ('conference','seminar') ORDER BY starts_at LIMIT 3");
$news = rows("SELECT * FROM news WHERE published = 1 ORDER BY created_at DESC LIMIT 3");
$programs = rows("SELECT * FROM programs WHERE published = 1 AND (deadline IS NULL OR deadline >= CURDATE()) ORDER BY deadline IS NULL, deadline LIMIT 3");

$my_tasks = $user["role"] === "team"
    ? rows("SELECT * FROM tasks WHERE assignee_id = ? AND status = 'todo' ORDER BY due_date IS NULL, due_date LIMIT 5", [$uid])
    : [];

page_header("Главная", $user);
?>
<section class="rounded-2xl p-6 text-white bg-gradient-to-br from-blue-900 via-indigo-800 to-fuchsia-700">
    <p class="opacity-80">Здравствуйте,</p>
    <h1 class="text-2xl md:text-3xl font-bold"><?= e($user["name"]) ?></h1>
    <p class="mt-2 opacity-90">Science creates opportunities for everyone.</p>

    <div class="mt-4 flex flex-wrap gap-2">
        <?php if (has_pro($user)): ?>
            <span class="chip bg-amber-300 text-amber-900 text-sm">
                PRO <?= $user["is_family"] ? "· семейный доступ" : (is_staff($user) ? "· команда" : "до " . fmt_date($user["pro_until"])) ?>
            </span>
        <?php else: ?>
            <a href="pro.php" class="btn bg-amber-300 text-amber-900">⭐ Подключить NII Pro — <?= e(money($settings["pro_price"])) ?>/мес</a>
        <?php endif; ?>
    </div>
</section>

<?php if ($my_tasks): ?>
<section class="mt-6">
    <div class="flex justify-between items-center mb-3"><h2 class="text-xl font-bold">Мои задачи</h2><a href="tasks.php" class="text-blue-800 text-sm font-semibold">Все →</a></div>
    <div class="card divide-y">
    <?php foreach ($my_tasks as $t): ?>
        <div class="p-4 flex justify-between gap-3">
            <span><?= e($t["title"]) ?></span>
            <span class="text-sm whitespace-nowrap <?= $t["due_date"] && $t["due_date"] < date("Y-m-d") ? "text-red-600 font-bold" : "text-slate-500" ?>"><?= fmt_date($t["due_date"]) ?></span>
        </div>
    <?php endforeach; ?>
    </div>
</section>
<?php endif; ?>

<section class="mt-6 grid md:grid-cols-2 gap-6">
    <div>
        <div class="flex justify-between items-center mb-3"><h2 class="text-xl font-bold">Мои события</h2><a href="events.php" class="text-blue-800 text-sm font-semibold">Все →</a></div>
        <?php if (!$my_events): ?>
            <div class="card p-5 text-slate-500">Вы пока не записаны на мероприятия. <a href="events.php" class="text-blue-800 font-semibold">Посмотреть →</a></div>
        <?php endif; ?>
        <div class="space-y-3">
        <?php foreach ($my_events as $ev): ?>
            <a href="event.php?id=<?= (int)$ev["id"] ?>" class="card p-4 block">
                <p class="text-sm text-blue-800 font-semibold"><?= fmt_dt($ev["starts_at"]) ?></p>
                <p class="font-bold"><?= e($ev["title"]) ?></p>
                <?php if ($ev["zoom_url"]): ?><p class="text-sm text-green-700 mt-1">🎥 Ссылка на Zoom внутри</p><?php endif; ?>
            </a>
        <?php endforeach; ?>
        </div>
    </div>

    <div>
        <div class="flex justify-between items-center mb-3"><h2 class="text-xl font-bold">Мои курсы</h2><a href="courses.php" class="text-blue-800 text-sm font-semibold">Все →</a></div>
        <?php if (!$my_courses): ?>
            <div class="card p-5 text-slate-500">Вы ещё не записаны на курсы. <a href="courses.php" class="text-blue-800 font-semibold">Выбрать →</a></div>
        <?php endif; ?>
        <div class="space-y-3">
        <?php foreach ($my_courses as $c): $pct = $c["total"] ? round($c["done"] * 100 / $c["total"]) : 0; ?>
            <a href="course.php?id=<?= (int)$c["id"] ?>" class="card p-4 block">
                <p class="font-bold"><?= e($c["title"]) ?></p>
                <div class="h-2 bg-slate-200 rounded-full mt-2"><div class="h-2 bg-blue-800 rounded-full" style="width: <?= $pct ?>%"></div></div>
                <p class="text-xs text-slate-500 mt-1"><?= (int)$c["done"] ?> из <?= (int)$c["total"] ?> уроков</p>
            </a>
        <?php endforeach; ?>
        </div>
    </div>
</section>

<section class="mt-6 grid md:grid-cols-3 gap-6">
    <div class="md:col-span-2">
        <h2 class="text-xl font-bold mb-3">Ближайшие конференции</h2>
        <?php if (!$upcoming): ?><div class="card p-5 text-slate-500">Скоро здесь появятся новые мероприятия.</div><?php endif; ?>
        <div class="space-y-3">
        <?php foreach ($upcoming as $ev): ?>
            <a href="event.php?id=<?= (int)$ev["id"] ?>" class="card p-4 flex gap-4 items-center">
                <div class="text-center bg-blue-50 text-blue-900 rounded-xl px-3 py-2 min-w-16">
                    <div class="text-2xl font-bold"><?= date("d", strtotime($ev["starts_at"])) ?></div>
                    <div class="text-xs"><?= date("m.Y", strtotime($ev["starts_at"])) ?></div>
                </div>
                <div><p class="font-bold"><?= e($ev["title"]) ?></p><p class="text-sm text-slate-500"><?= date("H:i", strtotime($ev["starts_at"])) ?> · <?= $ev["price"] > 0 ? e(money($ev["price"])) : "бесплатно" ?></p></div>
            </a>
        <?php endforeach; ?>
        </div>
    </div>

    <div>
        <h2 class="text-xl font-bold mb-3">Открытые программы</h2>
        <?php if (!$programs): ?><div class="card p-5 text-slate-500">Сейчас нет открытых наборов.</div><?php endif; ?>
        <div class="space-y-3">
        <?php foreach ($programs as $p): ?>
            <a href="program.php?id=<?= (int)$p["id"] ?>" class="card p-4 block">
                <span class="chip bg-fuchsia-100 text-fuchsia-800"><?= e($p["kind"]) ?></span>
                <p class="font-bold mt-1"><?= e($p["title"]) ?></p>
                <?php if ($p["deadline"]): ?><p class="text-sm text-slate-500">до <?= fmt_date($p["deadline"]) ?></p><?php endif; ?>
            </a>
        <?php endforeach; ?>
        </div>
    </div>
</section>

<?php if ($news): ?>
<section class="mt-6">
    <div class="flex justify-between items-center mb-3"><h2 class="text-xl font-bold">Новости НИИ</h2><a href="news.php" class="text-blue-800 text-sm font-semibold">Все →</a></div>
    <div class="grid md:grid-cols-3 gap-4">
    <?php foreach ($news as $n): ?>
        <a href="news.php#n<?= (int)$n["id"] ?>" class="card overflow-hidden block">
            <?php if (img_url($n["image_url"])): ?><img src="<?= e(img_url($n["image_url"])) ?>" alt="" class="w-full h-36 object-cover"><?php endif; ?>
            <div class="p-4"><p class="text-xs text-slate-500"><?= fmt_date($n["created_at"]) ?></p><p class="font-bold"><?= e($n["title"]) ?></p></div>
        </a>
    <?php endforeach; ?>
    </div>
</section>
<?php endif; ?>
<?php page_footer();
