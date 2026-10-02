<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];
$id = (int)($_GET["id"] ?? 0);

$p = row("SELECT * FROM programs WHERE id = ? AND (published = 1 OR ? = 1)", [$id, is_staff($user) ? 1 : 0]);

if (!$p) {
    http_response_code(404);
    die("Программа не найдена.");
}

$app = row("SELECT * FROM applications WHERE program_id = ? AND user_id = ?", [$id, $uid]);
$closed = $p["deadline"] && $p["deadline"] < date("Y-m-d");

if (is_post() && !$app && !$closed) {
    if (post("motivation") === "") {
        flash("Расскажите немного о себе и почему вы хотите участвовать.", "error");
    } else {
        $file = null;
        if (isset($_FILES["file"]) && $_FILES["file"]["error"] !== UPLOAD_ERR_NO_FILE) {
            $file = save_upload("file", ["pdf", "doc", "docx"], 10);
            if (!$file) {
                flash("Файл должен быть PDF, DOC или DOCX до 10 МБ.", "error");
                redirect("program.php?id=" . $id);
            }
        }
        q("INSERT INTO applications (program_id, user_id, motivation, file) VALUES (?, ?, ?, ?)", [$id, $uid, post("motivation"), $file]);
        flash("Заявка отправлена! Статус можно смотреть здесь и в профиле.");
    }
    redirect("program.php?id=" . $id);
}

page_header($p["title"], $user);
?>
<a href="programs.php" class="text-blue-800 font-semibold">← Все программы</a>

<div class="card p-6 md:p-8 mt-4">
    <span class="chip bg-fuchsia-100 text-fuchsia-800"><?= e($p["kind"]) ?></span>
    <h1 class="text-2xl md:text-3xl font-bold mt-2"><?= e($p["title"]) ?></h1>
    <p class="text-slate-500 mt-1"><?= $p["deadline"] ? "Приём заявок до " . fmt_date($p["deadline"]) : "Без дедлайна" ?></p>
    <div class="mt-5 leading-7 whitespace-pre-line"><?= e($p["description"]) ?></div>

    <div class="mt-8 p-5 rounded-xl bg-slate-50">
    <?php if ($app): ?>
        <?php $labels = ["submitted" => "⏳ Заявка на рассмотрении", "accepted" => "🎉 Заявка принята!", "rejected" => "Заявка отклонена"]; ?>
        <p class="font-bold text-lg"><?= $labels[$app["status"]] ?></p>
        <p class="text-sm text-slate-500">Отправлена <?= fmt_dt($app["created_at"]) ?></p>
        <?php if ($app["admin_note"]): ?><div class="mt-3 p-3 bg-white rounded-lg"><strong>Комментарий НИИ:</strong> <?= nl2br(e($app["admin_note"])) ?></div><?php endif; ?>
    <?php elseif ($closed): ?>
        <p class="font-semibold">Приём заявок закрыт.</p>
    <?php else: ?>
        <form method="POST" enctype="multipart/form-data" class="space-y-4">
            <?= csrf_field() ?>
            <h2 class="text-lg font-bold">Подать заявку</h2>
            <div><label class="label">О себе и мотивация</label><textarea class="field" name="motivation" rows="6" required placeholder="Кто вы, чем занимаетесь, почему хотите участвовать"></textarea></div>
            <div><label class="label">Резюме / CV / проект (PDF, DOC — необязательно)</label><input type="file" name="file" accept=".pdf,.doc,.docx" class="field"></div>
            <button class="btn btn-primary">Отправить заявку</button>
        </form>
    <?php endif; ?>
    </div>
</div>
<?php page_footer();
