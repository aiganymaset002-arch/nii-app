<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();
$news = rows("SELECT * FROM news WHERE published = 1 ORDER BY created_at DESC LIMIT 50");

page_header("Новости", $user);
?>
<h1 class="text-2xl font-bold mb-5">Новости НИИ</h1>

<?php if (!$news): ?><div class="card p-6 text-slate-500">Новостей пока нет.</div><?php endif; ?>

<div class="space-y-5 max-w-3xl">
<?php foreach ($news as $n): $img = img_url($n["image_url"]); ?>
    <article id="n<?= (int)$n["id"] ?>" class="card overflow-hidden">
        <?php if ($img): ?><img src="<?= e($img) ?>" alt="" class="w-full max-h-96 object-cover"><?php endif; ?>
        <div class="p-6">
            <p class="text-sm text-slate-500"><?= fmt_date($n["created_at"]) ?></p>
            <h2 class="text-xl font-bold mt-1"><?= e($n["title"]) ?></h2>
            <div class="mt-3 leading-7 whitespace-pre-line text-slate-700"><?= e($n["body"]) ?></div>
        </div>
    </article>
<?php endforeach; ?>
</div>
<?php page_footer();
