<?php
// Admin: merch products and orders.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");

if (is_post()) {
    $id = (int)post("id");

    if (post("action") === "delete") {
        q("DELETE FROM products WHERE id = ?", [$id]);
        flash("Товар удалён.");
        redirect("manage-shop.php");
    }

    $image = save_upload("image", ["jpg", "jpeg", "png", "webp"], 8);
    $image = $image ? upload_url($image) : (safe_url(post("image_url")) ?: post("old_image"));
    $data = [post("title"), post("description"), $image, max(0, (float)post("price")), isset($_POST["active"]) ? 1 : 0];

    if (post("title") === "") {
        flash("Укажите название.", "error");
    } elseif ($id) {
        q("UPDATE products SET title = ?, description = ?, image_url = ?, price = ?, active = ? WHERE id = ?", array_merge($data, [$id]));
        flash("Товар сохранён.");
    } else {
        q("INSERT INTO products (title, description, image_url, price, active) VALUES (?, ?, ?, ?, ?)", $data);
        flash("Товар добавлен.");
    }
    redirect("manage-shop.php");
}

$edit = isset($_GET["edit"]) ? row("SELECT * FROM products WHERE id = ?", [(int)$_GET["edit"]]) : null;
$v = $edit ?: ["id" => 0, "title" => "", "description" => "", "image_url" => "", "price" => 0, "active" => 1];
$products = rows("SELECT * FROM products ORDER BY id");
$orders = rows("SELECT p.*, u.name, u.phone, u.email FROM payments p JOIN users u ON u.id = p.user_id WHERE p.item_type = 'product' ORDER BY p.created_at DESC LIMIT 50");

page_header("Мерч", $user);
?>
<h1 class="text-2xl font-bold mb-4">Мерч НИИ</h1>

<div class="grid lg:grid-cols-2 gap-6">
<form method="POST" enctype="multipart/form-data" class="card p-6 space-y-4 h-fit">
    <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int)$v["id"] ?>"><input type="hidden" name="old_image" value="<?= e($v["image_url"]) ?>">
    <h2 class="text-xl font-bold"><?= $edit ? "Редактировать товар" : "Новый товар" ?></h2>
    <div><label class="label">Название</label><input class="field" name="title" value="<?= e($v["title"]) ?>" required placeholder="Худи NII"></div>
    <div><label class="label">Описание</label><input class="field" name="description" value="<?= e($v["description"]) ?>"></div>
    <div><label class="label">Цена, <?= e($settings["currency"]) ?></label><input class="field" type="number" step="0.01" min="0" name="price" value="<?= e($v["price"]) ?>"></div>
    <div class="grid grid-cols-2 gap-3">
        <div><label class="label">Фото</label><input class="field" type="file" name="image" accept="image/*"></div>
        <div><label class="label">или ссылка</label><input class="field" type="url" name="image_url"></div>
    </div>
    <label class="flex gap-2 items-center"><input type="checkbox" name="active" <?= $v["active"] ? "checked" : "" ?>> В продаже</label>
    <div class="flex gap-3"><button class="btn btn-primary">Сохранить</button><?php if ($edit): ?><a href="manage-shop.php" class="btn btn-light">Отмена</a><?php endif; ?></div>
</form>

<div class="card divide-y h-fit">
    <h2 class="text-xl font-bold p-4">Товары</h2>
    <?php if (!$products): ?><p class="p-4 text-slate-500">Пока пусто: футболка, худи, блокнот, термос, бейдж Researcher…</p><?php endif; ?>
    <?php foreach ($products as $p): ?>
    <div class="p-3 flex gap-3 items-center">
        <?php if ($p["image_url"]): ?><img src="<?= e($p["image_url"]) ?>" alt="" class="w-12 h-12 rounded-lg object-cover"><?php endif; ?>
        <div class="flex-1"><p class="font-semibold"><?= e($p["title"]) ?><?= $p["active"] ? "" : " · скрыт" ?></p><p class="text-sm text-slate-500"><?= e(money($p["price"])) ?></p></div>
        <a href="manage-shop.php?edit=<?= (int)$p["id"] ?>" class="btn btn-light !py-1">✏️</a>
        <form method="POST" onsubmit="return confirm('Удалить товар?')"><?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$p["id"] ?>"><button class="btn btn-danger !py-1">🗑️</button></form>
    </div>
    <?php endforeach; ?>
</div>
</div>

<h2 class="text-xl font-bold mt-8 mb-3">Заказы</h2>
<div class="card divide-y">
    <?php if (!$orders): ?><p class="p-5 text-slate-500">Заказов пока нет.</p><?php endif; ?>
    <?php foreach ($orders as $o): ?>
    <div class="p-4 flex flex-wrap justify-between gap-2">
        <div><p class="font-semibold">#<?= (int)$o["id"] ?> · <?= e($o["title"]) ?><?= $o["note"] ? " · " . e($o["note"]) : "" ?></p><p class="text-sm text-slate-500"><?= e($o["name"]) ?> · <?= e($o["phone"]) ?> · <?= e($o["email"]) ?></p></div>
        <div class="text-right"><p><?= e(money($o["amount"], $o["currency"])) ?></p><p class="text-sm"><?= e($o["status"]) ?> · <?= fmt_date($o["created_at"]) ?></p></div>
    </div>
    <?php endforeach; ?>
</div>
<?php page_footer();
