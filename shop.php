<?php
// NII merch shop.

require_once "config.php";
require_once "layout.php";

$user = require_login();

if (is_post()) {
    $product = row("SELECT * FROM products WHERE id = ? AND active = 1", [(int)post("id")]);
    if ($product) {
        redirect("pay.php?type=product&id=" . (int)$product["id"] . "&note=" . urlencode(post("note")));
    }
}

$products = rows("SELECT * FROM products WHERE active = 1 ORDER BY id");

page_header("Мерч НИИ", $user);
?>
<div class="rounded-2xl p-6 text-white bg-gradient-to-r from-blue-950 to-blue-800 mb-6">
    <h1 class="text-2xl md:text-3xl font-bold">Мерч НИИ</h1>
    <p class="opacity-90">Science. Innovation. Inclusion. Знания. Технологии. Возможности — для всех.</p>
</div>

<?php if (!$products): ?><div class="card p-6 text-slate-500">Мерч скоро появится.</div><?php endif; ?>

<div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
<?php foreach ($products as $p): ?>
    <form method="POST" class="card overflow-hidden flex flex-col">
        <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int)$p["id"] ?>">
        <?php if (img_url($p["image_url"])): ?><img src="<?= e(img_url($p["image_url"])) ?>" alt="" class="w-full aspect-square object-cover"><?php else: ?><div class="aspect-square bg-blue-50 flex items-center justify-center text-5xl">👕</div><?php endif; ?>
        <div class="p-4 flex flex-col flex-1">
            <h2 class="font-bold"><?= e($p["title"]) ?></h2>
            <p class="text-sm text-slate-500 flex-1"><?= e($p["description"]) ?></p>
            <p class="text-lg font-bold text-blue-900 mt-2"><?= e(money($p["price"])) ?></p>
            <input class="field mt-2 text-sm" name="note" placeholder="Размер / цвет / комментарий">
            <button class="btn btn-primary mt-2">Купить</button>
        </div>
    </form>
<?php endforeach; ?>
</div>
<?php page_footer();
