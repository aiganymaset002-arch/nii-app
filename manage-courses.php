<?php
// Admin: create courses and their lessons.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");

if (is_post()) {
    $action = post("action");
    $id = (int)post("id");

    if ($action === "save_course") {
        $data = [post("title"), post("description"), safe_url(post("image_url")), isset($_POST["is_premium"]) ? 1 : 0,
                 max(0, (float)post("price")), isset($_POST["published"]) ? 1 : 0];

        if (post("title") === "") {
            flash("Укажите название курса.", "error");
        } elseif ($id) {
            q("UPDATE courses SET title = ?, description = ?, image_url = ?, is_premium = ?, price = ?, published = ? WHERE id = ?", array_merge($data, [$id]));
            flash("Курс сохранён.");
        } else {
            q("INSERT INTO courses (title, description, image_url, is_premium, price, published) VALUES (?, ?, ?, ?, ?, ?)", $data);
            $id = insert_id();
            flash("Курс создан. Теперь добавьте уроки.");
        }
        redirect("manage-courses.php?edit=" . $id);
    }

    if ($action === "delete_course") {
        q("DELETE FROM courses WHERE id = ?", [$id]);
        flash("Курс удалён.");
        redirect("manage-courses.php");
    }

    $course_id = (int)post("course_id");

    if ($action === "save_lesson" && post("title") !== "") {
        $lesson = (int)post("lesson_id");
        $data = [post("title"), post("content"), safe_url(post("video_url")), (int)post("sort")];

        if ($lesson) {
            q("UPDATE lessons SET title = ?, content = ?, video_url = ?, sort = ? WHERE id = ? AND course_id = ?", array_merge($data, [$lesson, $course_id]));
        } else {
            $next = (int)row("SELECT COALESCE(MAX(sort), 0) + 1 n FROM lessons WHERE course_id = ?", [$course_id])["n"];
            $data[3] = $data[3] ?: $next;
            q("INSERT INTO lessons (title, content, video_url, sort, course_id) VALUES (?, ?, ?, ?, ?)", array_merge($data, [$course_id]));
        }
        flash("Урок сохранён.");
    }

    if ($action === "delete_lesson") {
        q("DELETE FROM lessons WHERE id = ? AND course_id = ?", [(int)post("lesson_id"), $course_id]);
        flash("Урок удалён.");
    }

    redirect("manage-courses.php?edit=" . $course_id);
}

$edit = isset($_GET["edit"]) ? row("SELECT * FROM courses WHERE id = ?", [(int)$_GET["edit"]]) : null;
$new = isset($_GET["new"]);
$lessons = $edit ? rows("SELECT * FROM lessons WHERE course_id = ? ORDER BY sort, id", [(int)$edit["id"]]) : [];
$edit_lesson = $edit && isset($_GET["lesson"]) ? row("SELECT * FROM lessons WHERE id = ? AND course_id = ?", [(int)$_GET["lesson"], (int)$edit["id"]]) : null;

$courses = rows("SELECT c.*, (SELECT COUNT(*) FROM lessons l WHERE l.course_id = c.id) AS lessons,
                 (SELECT COUNT(*) FROM enrollments en WHERE en.course_id = c.id) AS students
                 FROM courses c ORDER BY c.created_at DESC");

page_header("Курсы", $user);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold">Курсы</h1>
    <a href="manage-courses.php?new=1" class="btn btn-primary">＋ Новый курс</a>
</div>

<?php if ($edit || $new): $v = $edit ?: ["id" => 0, "title" => "", "description" => "", "image_url" => "", "is_premium" => 0, "price" => 0, "published" => 1]; ?>
<div class="grid lg:grid-cols-2 gap-6 mb-8">
    <form method="POST" class="card p-6 space-y-4 h-fit">
        <?= csrf_field() ?><input type="hidden" name="action" value="save_course"><input type="hidden" name="id" value="<?= (int)$v["id"] ?>">
        <h2 class="text-xl font-bold"><?= $edit ? "Курс" : "Новый курс" ?></h2>
        <div><label class="label">Название</label><input class="field" name="title" value="<?= e($v["title"]) ?>" required></div>
        <div><label class="label">Описание (о чём курс, для кого, что получит ученик)</label><textarea class="field" name="description" rows="6"><?= e($v["description"]) ?></textarea></div>
        <div><label class="label">Ссылка на обложку (картинку)</label><input class="field" type="url" name="image_url" value="<?= e($v["image_url"]) ?>" placeholder="https://..."></div>
        <div class="grid grid-cols-2 gap-4 items-end">
            <label class="flex gap-2 items-center"><input type="checkbox" name="is_premium" <?= $v["is_premium"] ? "checked" : "" ?>> ⭐ Входит в NII Pro</label>
            <div><label class="label">Цена отдельно, <?= e($settings["currency"]) ?></label><input class="field" type="number" step="0.01" min="0" name="price" value="<?= e($v["price"]) ?>"></div>
        </div>
        <p class="text-xs text-slate-500">Без галочки и с ценой 0 — бесплатный курс. С галочкой — доступен подписчикам Pro (и можно купить отдельно, если указана цена).</p>
        <label class="flex gap-2 items-center"><input type="checkbox" name="published" <?= $v["published"] ? "checked" : "" ?>> Опубликован</label>
        <div class="flex gap-3">
            <button class="btn btn-primary">Сохранить курс</button>
            <?php if ($edit): ?><a href="course.php?id=<?= (int)$edit["id"] ?>" class="btn btn-light">👁️ Посмотреть</a><?php endif; ?>
        </div>
    </form>

    <?php if ($edit): $lv = $edit_lesson ?: ["id" => 0, "title" => "", "content" => "", "video_url" => "", "sort" => 0]; ?>
    <div class="space-y-4">
        <div class="card divide-y">
            <h2 class="text-xl font-bold p-4">Уроки (<?= count($lessons) ?>)</h2>
            <?php foreach ($lessons as $i => $l): ?>
            <div class="p-3 flex gap-2 items-center">
                <span class="text-slate-400 w-6"><?= $i + 1 ?>.</span>
                <span class="flex-1"><?= e($l["title"]) ?> <?= $l["video_url"] ? "🎬" : "" ?></span>
                <a href="manage-courses.php?edit=<?= (int)$edit["id"] ?>&lesson=<?= (int)$l["id"] ?>" class="btn btn-light !py-1">✏️</a>
                <form method="POST" onsubmit="return confirm('Удалить урок?')">
                    <?= csrf_field() ?><input type="hidden" name="action" value="delete_lesson"><input type="hidden" name="course_id" value="<?= (int)$edit["id"] ?>"><input type="hidden" name="lesson_id" value="<?= (int)$l["id"] ?>">
                    <button class="btn btn-danger !py-1">🗑️</button>
                </form>
            </div>
            <?php endforeach; ?>
        </div>

        <form method="POST" class="card p-6 space-y-4">
            <?= csrf_field() ?><input type="hidden" name="action" value="save_lesson"><input type="hidden" name="course_id" value="<?= (int)$edit["id"] ?>"><input type="hidden" name="lesson_id" value="<?= (int)$lv["id"] ?>">
            <h3 class="font-bold"><?= $edit_lesson ? "Редактировать урок" : "Добавить урок" ?></h3>
            <div><label class="label">Название урока</label><input class="field" name="title" value="<?= e($lv["title"]) ?>" required></div>
            <div><label class="label">Видео (YouTube или другая ссылка)</label><input class="field" type="url" name="video_url" value="<?= e($lv["video_url"]) ?>" placeholder="https://www.youtube.com/watch?v=..."></div>
            <div><label class="label">Текст урока</label><textarea class="field" name="content" rows="8"><?= e($lv["content"]) ?></textarea></div>
            <div class="w-32"><label class="label">Порядок</label><input class="field" type="number" name="sort" value="<?= (int)$lv["sort"] ?>"></div>
            <div class="flex gap-3">
                <button class="btn btn-primary"><?= $edit_lesson ? "Сохранить" : "＋ Добавить урок" ?></button>
                <?php if ($edit_lesson): ?><a href="manage-courses.php?edit=<?= (int)$edit["id"] ?>" class="btn btn-light">Отмена</a><?php endif; ?>
            </div>
        </form>
    </div>
    <?php endif; ?>
</div>
<?php endif; ?>

<div class="card divide-y">
    <?php if (!$courses): ?><p class="p-6 text-slate-500">Курсов пока нет.</p><?php endif; ?>
    <?php foreach ($courses as $c): ?>
    <div class="p-4 flex flex-wrap gap-3 items-center">
        <div class="flex-1 min-w-48">
            <p class="font-bold"><?= e($c["title"]) ?>
                <?php if ($c["is_premium"]): ?><span class="chip bg-amber-200 text-amber-900">PRO</span><?php endif; ?>
                <?php if (!$c["published"]): ?><span class="chip bg-slate-200">черновик</span><?php endif; ?>
            </p>
            <p class="text-sm text-slate-500"><?= (int)$c["lessons"] ?> уроков · <?= (int)$c["students"] ?> учеников · <?= $c["price"] > 0 ? e(money($c["price"])) : ($c["is_premium"] ? "в подписке Pro" : "бесплатно") ?></p>
        </div>
        <a href="manage-courses.php?edit=<?= (int)$c["id"] ?>" class="btn btn-light">✏️ Редактировать</a>
        <form method="POST" onsubmit="return confirm('Удалить курс вместе с уроками и прогрессом учеников?')">
            <?= csrf_field() ?><input type="hidden" name="action" value="delete_course"><input type="hidden" name="id" value="<?= (int)$c["id"] ?>">
            <button class="btn btn-danger">🗑️</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>
<?php page_footer();
