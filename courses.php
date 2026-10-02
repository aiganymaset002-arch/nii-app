<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();

$courses = rows("
    SELECT c.*,
        (SELECT COUNT(*) FROM lessons l WHERE l.course_id = c.id) AS lessons,
        (SELECT COUNT(*) FROM enrollments en WHERE en.course_id = c.id AND en.user_id = ?) AS enrolled
    FROM courses c WHERE c.published = 1 ORDER BY c.created_at DESC", [(int)$user["id"]]);

page_header("Курсы", $user);
?>
<h1 class="text-2xl font-bold mb-1">Курсы НИИ</h1>
<p class="text-slate-500 mb-5">Бесплатные курсы открыты всем. Курсы с пометкой PRO входят в подписку NII Pro.</p>

<?php if (!$courses): ?><div class="card p-6 text-slate-500">Курсы скоро появятся.</div><?php endif; ?>

<div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
<?php foreach ($courses as $c): ?>
    <a href="course.php?id=<?= (int)$c["id"] ?>" class="card overflow-hidden block">
        <?php if (safe_url($c["image_url"])): ?>
            <img src="<?= e($c["image_url"]) ?>" alt="" class="w-full h-40 object-cover">
        <?php else: ?>
            <div class="h-40 bg-gradient-to-br from-blue-800 to-fuchsia-600 flex items-center justify-center text-5xl">🎓</div>
        <?php endif; ?>
        <div class="p-4">
            <div class="flex gap-1 mb-1">
                <?php if ($c["is_premium"]): ?><span class="chip bg-amber-200 text-amber-900">PRO</span><?php endif; ?>
                <?php if ($c["price"] > 0): ?><span class="chip bg-slate-100"><?= e(money($c["price"])) ?></span><?php endif; ?>
                <?php if (!$c["is_premium"] && $c["price"] <= 0): ?><span class="chip bg-green-100 text-green-800">Бесплатно</span><?php endif; ?>
                <?php if ($c["enrolled"]): ?><span class="chip bg-blue-100 text-blue-900">Вы учитесь</span><?php endif; ?>
            </div>
            <h2 class="font-bold"><?= e($c["title"]) ?></h2>
            <p class="text-sm text-slate-500 mt-1"><?= (int)$c["lessons"] ?> уроков</p>
        </div>
    </a>
<?php endforeach; ?>
</div>
<?php page_footer();
