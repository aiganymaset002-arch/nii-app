<?php
// Course page: enrol, lessons, progress, certificate.

require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];
$id = (int)($_GET["id"] ?? 0);

$course = row("SELECT * FROM courses WHERE id = ? AND (published = 1 OR ? = 1)", [$id, is_staff($user) ? 1 : 0]);

if (!$course) {
    http_response_code(404);
    die("Курс не найден.");
}

$enrolled = (bool)row("SELECT id FROM enrollments WHERE user_id = ? AND course_id = ?", [$uid, $id]);

// Access: free course, Pro course with Pro, bought course, staff, family
$needs_pro = $course["is_premium"] && !has_pro($user);
$needs_payment = !$course["is_premium"] && $course["price"] > 0 && !$user["is_family"] && !is_staff($user);
// A premium course with a price can be either included in Pro or bought separately
$can_buy = $course["price"] > 0 && !$user["is_family"] && !is_staff($user);

if (is_post()) {
    $action = post("action");

    if ($action === "enroll" && !$enrolled) {
        if ($needs_pro && !$can_buy) {
            redirect("pro.php");
        }
        if ($needs_pro || $needs_payment) {
            redirect("pay.php?type=course&id=" . $id);
        }
        q("INSERT IGNORE INTO enrollments (user_id, course_id) VALUES (?, ?)", [$uid, $id]);
        flash("Вы записаны на курс!");
    }

    if ($action === "done" && $enrolled) {
        $lesson = (int)post("lesson");
        if (row("SELECT id FROM lessons WHERE id = ? AND course_id = ?", [$lesson, $id])) {
            q("INSERT IGNORE INTO lesson_progress (user_id, lesson_id) VALUES (?, ?)", [$uid, $lesson]);
        }
        $next = row("SELECT id FROM lessons WHERE course_id = ? AND id NOT IN (SELECT lesson_id FROM lesson_progress WHERE user_id = ?) ORDER BY sort, id LIMIT 1", [$id, $uid]);
        redirect("course.php?id=" . $id . ($next ? "&lesson=" . $next["id"] : "&finished=1"));
    }

    redirect("course.php?id=" . $id);
}

$lessons = rows("SELECT l.*, (lp.lesson_id IS NOT NULL) AS done FROM lessons l
                 LEFT JOIN lesson_progress lp ON lp.lesson_id = l.id AND lp.user_id = ?
                 WHERE l.course_id = ? ORDER BY l.sort, l.id", [$uid, $id]);
$done = count(array_filter($lessons, fn($l) => $l["done"]));
$total = count($lessons);
$finished = $total > 0 && $done === $total;

$current = null;
if ($enrolled && isset($_GET["lesson"])) {
    foreach ($lessons as $l) {
        if ((int)$l["id"] === (int)$_GET["lesson"]) {
            $current = $l;
        }
    }
}

page_header($course["title"], $user);
?>
<a href="courses.php" class="text-blue-800 font-semibold">← Все курсы</a>

<div class="grid lg:grid-cols-3 gap-6 mt-4">
    <div class="lg:col-span-2">
    <?php if ($current): ?>
        <div class="card p-6">
            <p class="text-sm text-slate-500"><?= e($course["title"]) ?></p>
            <h1 class="text-2xl font-bold"><?= e($current["title"]) ?></h1>
            <?php if (safe_url($current["video_url"])): ?>
                <div class="aspect-video mt-4 rounded-xl overflow-hidden bg-black">
                    <iframe src="<?= e(video_embed_url($current["video_url"])) ?>" class="w-full h-full" allowfullscreen allow="autoplay; encrypted-media; picture-in-picture"></iframe>
                </div>
            <?php endif; ?>
            <div class="mt-5 leading-7 whitespace-pre-line"><?= e($current["content"]) ?></div>
            <form method="POST" class="mt-6">
                <?= csrf_field() ?><input type="hidden" name="action" value="done"><input type="hidden" name="lesson" value="<?= (int)$current["id"] ?>">
                <button class="btn btn-green"><?= $current["done"] ? "Дальше →" : "✓ Урок пройден, дальше" ?></button>
            </form>
        </div>
    <?php else: ?>
        <div class="card overflow-hidden">
            <?php if (safe_url($course["image_url"])): ?><img src="<?= e($course["image_url"]) ?>" alt="" class="w-full h-56 object-cover"><?php endif; ?>
            <div class="p-6">
                <div class="flex gap-1">
                    <?php if ($course["is_premium"]): ?><span class="chip bg-amber-200 text-amber-900">PRO</span><?php endif; ?>
                    <?php if ($course["price"] > 0): ?><span class="chip bg-slate-100"><?= e(money($course["price"])) ?></span><?php endif; ?>
                </div>
                <h1 class="text-2xl md:text-3xl font-bold mt-2"><?= e($course["title"]) ?></h1>
                <div class="mt-4 leading-7 whitespace-pre-line text-slate-700"><?= e($course["description"]) ?></div>

                <?php if (isset($_GET["finished"]) || $finished): ?>
                    <div class="mt-6 p-5 rounded-xl bg-green-50 border border-green-200">
                        <p class="font-bold text-green-800">🎉 Курс пройден!</p>
                        <a href="certificate.php?course=<?= $id ?>" class="btn btn-green mt-3">📜 Получить сертификат</a>
                    </div>
                <?php elseif ($enrolled): ?>
                    <?php $next = array_values(array_filter($lessons, fn($l) => !$l["done"]))[0] ?? null; ?>
                    <?php if ($next): ?><a href="course.php?id=<?= $id ?>&lesson=<?= (int)$next["id"] ?>" class="btn btn-primary mt-6"><?= $done ? "Продолжить" : "Начать обучение" ?> →</a><?php endif; ?>
                <?php else: ?>
                    <form method="POST" class="mt-6 flex flex-wrap gap-3 items-center">
                        <?= csrf_field() ?><input type="hidden" name="action" value="enroll">
                        <?php if ($needs_pro): ?>
                            <a href="pro.php" class="btn bg-amber-300 text-amber-900">⭐ Входит в NII Pro — <?= e(money($settings["pro_price"])) ?>/мес</a>
                            <?php if ($can_buy): ?><button class="btn btn-light">или купить курс за <?= e(money($course["price"])) ?></button><?php endif; ?>
                        <?php elseif ($needs_payment): ?>
                            <button class="btn btn-primary">Купить курс — <?= e(money($course["price"])) ?></button>
                        <?php else: ?>
                            <button class="btn btn-primary">Записаться на курс</button>
                        <?php endif; ?>
                    </form>
                <?php endif; ?>
            </div>
        </div>
    <?php endif; ?>
    </div>

    <aside class="card p-5 h-fit">
        <h2 class="font-bold">Программа курса</h2>
        <?php if ($enrolled && $total): ?>
            <div class="h-2 bg-slate-200 rounded-full mt-2"><div class="h-2 bg-blue-800 rounded-full" style="width: <?= round($done * 100 / $total) ?>%"></div></div>
            <p class="text-xs text-slate-500 mt-1"><?= $done ?> из <?= $total ?></p>
        <?php endif; ?>
        <ol class="mt-3 space-y-1">
        <?php foreach ($lessons as $i => $l): ?>
            <li>
            <?php if ($enrolled): ?>
                <a href="course.php?id=<?= $id ?>&lesson=<?= (int)$l["id"] ?>" class="flex gap-2 p-2 rounded-lg <?= $current && (int)$current["id"] === (int)$l["id"] ? "bg-blue-50 font-semibold" : "" ?>">
                    <span><?= $l["done"] ? "✅" : ($i + 1) . "." ?></span><span><?= e($l["title"]) ?></span>
                </a>
            <?php else: ?>
                <span class="flex gap-2 p-2 text-slate-500"><span>🔒</span><span><?= e($l["title"]) ?></span></span>
            <?php endif; ?>
            </li>
        <?php endforeach; ?>
        <?php if (!$lessons): ?><li class="text-slate-500 text-sm">Уроки скоро появятся.</li><?php endif; ?>
        </ol>
    </aside>
</div>
<?php page_footer();
