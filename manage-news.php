<?php
// Admin: write news. Image can be uploaded from the phone or given as a link.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");

if (is_post()) {
    $id = (int)post("id");

    if (post("action") === "delete") {
        q("DELETE FROM news WHERE id = ?", [$id]);
        flash("Новость удалена.");
        redirect("manage-news.php");
    }

    $image = save_upload("image", ["jpg", "jpeg", "png", "webp", "gif"], 8);
    $image = $image ? upload_url($image) : (safe_url(post("image_url")) ?: post("old_image"));

    if (post("title") === "") {
        flash("Укажите заголовок.", "error");
    } elseif ($id) {
        q("UPDATE news SET title = ?, body = ?, image_url = ?, published = ? WHERE id = ?", [post("title"), post("body"), $image, isset($_POST["published"]) ? 1 : 0, $id]);
        flash("Новость сохранена.");
    } else {
        q("INSERT INTO news (title, body, image_url, published, author_id) VALUES (?, ?, ?, ?, ?)", [post("title"), post("body"), $image, isset($_POST["published"]) ? 1 : 0, (int)$user["id"]]);
        flash("Новость опубликована.");
    }
    redirect("manage-news.php");
}

$edit = isset($_GET["edit"]) ? row("SELECT * FROM news WHERE id = ?", [(int)$_GET["edit"]]) : null;
$v = $edit ?: ["id" => 0, "title" => "", "body" => "", "image_url" => "", "published" => 1];
$news = rows("SELECT * FROM news ORDER BY created_at DESC");

page_header("Новости", $user);
?>
<h1 class="text-2xl font-bold mb-4">Новости</h1>

<form method="POST" enctype="multipart/form-data" class="card p-6 mb-6 space-y-4">
    <?= csrf_field() ?><input type="hidden" name="id" value="<?= (int)$v["id"] ?>"><input type="hidden" name="old_image" value="<?= e($v["image_url"]) ?>">
    <h2 class="text-xl font-bold"><?= $edit ? "Редактировать новость" : "Новая новость" ?></h2>
    <div><label class="label">Заголовок</label><input class="field" name="title" value="<?= e($v["title"]) ?>" required></div>
    <div><label class="label">Текст</label><textarea class="field" name="body" rows="7"><?= e($v["body"]) ?></textarea></div>
    <div class="grid md:grid-cols-2 gap-4">
        <div><label class="label">Фото с телефона / компьютера</label><input class="field" type="file" name="image" accept="image/*"></div>
        <div><label class="label">или ссылка на картинку</label><input class="field" type="url" name="image_url" placeholder="https://..."></div>
    </div>
    <?php if ($v["image_url"]): ?><img src="<?= e($v["image_url"]) ?>" alt="" class="h-24 rounded-lg"><?php endif; ?>
    <label class="flex gap-2 items-center"><input type="checkbox" name="published" <?= $v["published"] ? "checked" : "" ?>> Опубликовать сразу</label>
    <div class="flex gap-3"><button class="btn btn-primary">Сохранить</button><?php if ($edit): ?><a href="manage-news.php" class="btn btn-light">Отмена</a><?php endif; ?></div>
</form>

<div class="card divide-y">
    <?php if (!$news): ?><p class="p-6 text-slate-500">Новостей пока нет.</p><?php endif; ?>
    <?php foreach ($news as $n): ?>
    <div class="p-4 flex gap-3 items-center">
        <div class="flex-1"><p class="text-sm text-slate-500"><?= fmt_date($n["created_at"]) ?><?= $n["published"] ? "" : " · черновик" ?></p><p class="font-bold"><?= e($n["title"]) ?></p></div>
        <a href="manage-news.php?edit=<?= (int)$n["id"] ?>" class="btn btn-light">✏️</a>
        <form method="POST" onsubmit="return confirm('Удалить новость?')">
            <?= csrf_field() ?><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<?= (int)$n["id"] ?>">
            <button class="btn btn-danger">🗑️</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>
<?php page_footer();
