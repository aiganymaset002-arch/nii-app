<?php
require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];

if (is_post()) {
    $action = post("action");

    if ($action === "profile") {
        if (post("name") === "") {
            flash("Имя не может быть пустым.", "error");
        } else {
            q("UPDATE users SET name = ?, phone = ?, organization = ? WHERE id = ?", [post("name"), post("phone"), post("organization"), $uid]);
            flash("Профиль сохранён.");
        }
    }

    if ($action === "password") {
        if (!password_verify($_POST["current"] ?? "", $user["password"])) {
            flash("Текущий пароль неверный.", "error");
        } elseif (strlen($_POST["new"] ?? "") < 6) {
            flash("Новый пароль — минимум 6 символов.", "error");
        } else {
            q("UPDATE users SET password = ? WHERE id = ?", [password_hash($_POST["new"], PASSWORD_DEFAULT), $uid]);
            flash("Пароль изменён.");
        }
    }

    if ($action === "family") {
        if (is_free_access_code($_POST["family_code"] ?? "")) {
            q("UPDATE users SET is_family = 1 WHERE id = ?", [$uid]);
            flash("Семейный доступ включён: Pro, курсы и мероприятия бесплатно.");
        } else {
            sleep(1);
            flash("Неверный семейный пароль.", "error");
        }
    }

    redirect("profile.php");
}

$payments = rows("SELECT * FROM payments WHERE user_id = ? ORDER BY created_at DESC LIMIT 30", [$uid]);
$apps = rows("SELECT a.*, p.title FROM applications a JOIN programs p ON p.id = a.program_id WHERE a.user_id = ? ORDER BY a.created_at DESC", [$uid]);
$roles = ["admin" => "Организатор", "team" => "Команда НИИ", "user" => "Участник"];

page_header("Профиль", $user);
?>
<h1 class="text-2xl font-bold mb-1"><?= e($user["name"]) ?></h1>
<p class="text-slate-500 mb-5"><?= e($roles[$user["role"]]) ?> · <?= e($user["email"]) ?></p>

<div class="grid lg:grid-cols-2 gap-6">
    <div class="space-y-6">
        <div class="card p-6">
            <h2 class="font-bold text-lg">⭐ NII Pro</h2>
            <?php if (has_pro($user)): ?>
                <p class="mt-1 text-green-700 font-semibold">Активен <?= $user["is_family"] ? "· семейный доступ" : (is_staff($user) ? "· команда НИИ" : "до " . fmt_date($user["pro_until"])) ?></p>
            <?php else: ?>
                <p class="mt-1 text-slate-500">Не подключён.</p>
            <?php endif; ?>
            <a href="pro.php" class="btn btn-light mt-3"><?= has_pro($user) ? "Подробнее" : "Подключить Pro" ?></a>
        </div>

        <form method="POST" class="card p-6 space-y-4">
            <?= csrf_field() ?><input type="hidden" name="action" value="profile">
            <h2 class="font-bold text-lg">Мои данные</h2>
            <div><label class="label">Имя и фамилия</label><input class="field" name="name" value="<?= e($user["name"]) ?>" required></div>
            <div class="grid sm:grid-cols-2 gap-4">
                <div><label class="label">Телефон</label><input class="field" name="phone" value="<?= e($user["phone"]) ?>"></div>
                <div><label class="label">Организация</label><input class="field" name="organization" value="<?= e($user["organization"]) ?>"></div>
            </div>
            <button class="btn btn-primary">Сохранить</button>
        </form>

        <form method="POST" class="card p-6 space-y-4">
            <?= csrf_field() ?><input type="hidden" name="action" value="password">
            <h2 class="font-bold text-lg">Сменить пароль</h2>
            <div class="grid sm:grid-cols-2 gap-4">
                <div><label class="label">Текущий</label><input class="field" type="password" name="current" required></div>
                <div><label class="label">Новый</label><input class="field" type="password" name="new" minlength="6" required></div>
            </div>
            <button class="btn btn-light">Сменить</button>
        </form>

        <?php if (!$user["is_family"]): ?>
        <form method="POST" class="card p-6 space-y-3">
            <?= csrf_field() ?><input type="hidden" name="action" value="family">
            <h2 class="font-bold text-lg">Семейный доступ</h2>
            <input class="field" type="password" name="family_code" placeholder="Семейный пароль" autocomplete="off" required>
            <button class="btn btn-light">Активировать</button>
        </form>
        <?php endif; ?>
    </div>

    <div class="space-y-6">


        <div class="card p-6">
            <h2 class="font-bold text-lg mb-3">Мои заявки</h2>
            <?php if (!$apps): ?><p class="text-slate-500">Заявок нет. <a href="programs.php" class="text-blue-800 font-semibold">Программы →</a></p><?php endif; ?>
            <?php foreach ($apps as $a): ?>
                <a href="program.php?id=<?= (int)$a["program_id"] ?>" class="flex justify-between gap-2 py-2 border-b last:border-0">
                    <span><?= e($a["title"]) ?></span>
                    <span class="text-sm whitespace-nowrap"><?= ["submitted" => "⏳ рассматривается", "accepted" => "✅ принята", "rejected" => "❌ отклонена"][$a["status"]] ?></span>
                </a>
            <?php endforeach; ?>
        </div>

        <div class="card p-6" id="payments">
            <h2 class="font-bold text-lg mb-3">Мои платежи</h2>
            <?php if (!$payments): ?><p class="text-slate-500">Платежей нет.</p><?php endif; ?>
            <?php foreach ($payments as $p): ?>
                <a href="pay.php?payment=<?= (int)$p["id"] ?>" class="flex justify-between gap-2 py-2 border-b last:border-0">
                    <span>№<?= (int)$p["id"] ?> · <?= e($p["title"]) ?></span>
                    <span class="text-sm whitespace-nowrap"><?= e(money($p["amount"], $p["currency"])) ?> · <?= ["pending" => "ждёт оплаты", "review" => "на проверке", "paid" => "✅", "rejected" => "❌"][$p["status"]] ?></span>
                </a>
            <?php endforeach; ?>
        </div>
    </div>
</div>
<?php page_footer();
