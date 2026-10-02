<?php
// Admin: people, roles, Pro and family access.

require_once "config.php";
require_once "layout.php";

$admin = require_role("admin");

if (is_post()) {
    $id = (int)post("id");
    $target = row("SELECT * FROM users WHERE id = ?", [$id]);

    if ($target) {
        switch (post("action")) {
            case "role":
                if ($id !== (int)$admin["id"] && in_array(post("role"), ["admin", "team", "user"], true)) {
                    q("UPDATE users SET role = ? WHERE id = ?", [post("role"), $id]);
                    flash("Роль изменена.");
                }
                break;
            case "pro":
                q("UPDATE users SET pro_until = DATE_ADD(GREATEST(COALESCE(pro_until, CURDATE()), CURDATE()), INTERVAL ? DAY) WHERE id = ?", [max(1, (int)post("days")), $id]);
                flash("Pro продлён.");
                break;
            case "family":
                q("UPDATE users SET is_family = 1 - is_family WHERE id = ?", [$id]);
                flash("Семейный доступ изменён.");
                break;
        }
    }
    redirect("manage-users.php?" . http_build_query(["q" => $_GET["q"] ?? ""]));
}

$search = trim($_GET["q"] ?? "");
$users = $search !== ""
    ? rows("SELECT * FROM users WHERE name LIKE ? OR email LIKE ? OR phone LIKE ? ORDER BY created_at DESC LIMIT 200", ["%$search%", "%$search%", "%$search%"])
    : rows("SELECT * FROM users ORDER BY FIELD(role, 'admin', 'team', 'user'), created_at DESC LIMIT 200");
$roles = ["admin" => "Организатор", "team" => "Команда", "user" => "Участник"];

page_header("Люди", $admin);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold">Люди</h1>
    <form method="GET" class="flex gap-2"><input class="field" name="q" value="<?= e($search) ?>" placeholder="Имя, email, телефон"><button class="btn btn-light">🔍</button></form>
</div>

<div class="card p-4 mb-4 text-sm text-slate-600">
    Коды для регистрации — в файле <code>config.local.php</code> на сервере: <strong>организатор</strong> (admin_code) и <strong>команда НИИ</strong> (team_code). Участникам код не нужен.
</div>

<div class="card divide-y">
<?php foreach ($users as $u): ?>
    <div class="p-4 flex flex-wrap gap-3 items-center">
        <div class="flex-1 min-w-56">
            <p class="font-bold"><?= e($u["name"]) ?>
                <?php if ($u["is_family"]): ?><span class="chip bg-pink-100 text-pink-800">семья</span><?php endif; ?>
                <?php if ($u["pro_until"] && $u["pro_until"] >= date("Y-m-d")): ?><span class="chip bg-amber-200 text-amber-900">PRO до <?= fmt_date($u["pro_until"]) ?></span><?php endif; ?>
            </p>
            <p class="text-sm text-slate-500"><?= e($u["email"]) ?> · <?= e($u["phone"]) ?> · <?= e($u["organization"]) ?> · с <?= fmt_date($u["created_at"]) ?></p>
        </div>
        <form method="POST" class="flex gap-1">
            <?= csrf_field() ?><input type="hidden" name="action" value="role"><input type="hidden" name="id" value="<?= (int)$u["id"] ?>">
            <select name="role" class="field !py-1.5 !w-auto text-sm" onchange="this.form.submit()" <?= (int)$u["id"] === (int)$admin["id"] ? "disabled" : "" ?>>
                <?php foreach ($roles as $k => $label): ?><option value="<?= $k ?>" <?= $u["role"] === $k ? "selected" : "" ?>><?= $label ?></option><?php endforeach; ?>
            </select>
        </form>
        <form method="POST" class="flex gap-1">
            <?= csrf_field() ?><input type="hidden" name="action" value="pro"><input type="hidden" name="id" value="<?= (int)$u["id"] ?>">
            <select name="days" class="field !py-1.5 !w-auto text-sm"><option value="30">+30 дн.</option><option value="90">+90 дн.</option><option value="365">+1 год</option></select>
            <button class="btn btn-light !py-1.5 text-sm">⭐ Pro</button>
        </form>
        <form method="POST">
            <?= csrf_field() ?><input type="hidden" name="action" value="family"><input type="hidden" name="id" value="<?= (int)$u["id"] ?>">
            <button class="btn btn-light !py-1.5 text-sm"><?= $u["is_family"] ? "Убрать семью" : "👪 Семья" ?></button>
        </form>
    </div>
<?php endforeach; ?>
</div>
<?php page_footer();
