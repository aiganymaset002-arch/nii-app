<?php
// Admin: confirm or reject payments. Confirming gives the user what they paid for.

require_once "config.php";
require_once "layout.php";

$user = require_role("admin");

if (is_post()) {
    $payment = row("SELECT * FROM payments WHERE id = ?", [(int)post("id")]);

    if ($payment && in_array($payment["status"], ["pending", "review"], true)) {
        if (post("action") === "confirm") {
            q("UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = ?", [(int)$payment["id"]]);
            fulfil_payment($payment);
            flash("Оплата №" . (int)$payment["id"] . " подтверждена, доступ открыт.");
        } elseif (post("action") === "reject") {
            q("UPDATE payments SET status = 'rejected' WHERE id = ?", [(int)$payment["id"]]);
            flash("Оплата №" . (int)$payment["id"] . " отклонена.");
        }
    }
    redirect("manage-payments.php");
}

$filter = $_GET["status"] ?? "open";
$where = $filter === "open" ? "WHERE p.status IN ('review', 'pending')" : ($filter === "all" ? "" : "WHERE p.status = 'paid'");
$payments = rows("SELECT p.*, u.name, u.email, u.phone FROM payments p JOIN users u ON u.id = p.user_id $where
                  ORDER BY FIELD(p.status, 'review', 'pending', 'paid', 'rejected'), p.created_at DESC LIMIT 200");
$month = row("SELECT COALESCE(SUM(amount), 0) s FROM payments WHERE status = 'paid' AND paid_at >= DATE_FORMAT(CURDATE(), '%Y-%m-01')")["s"];

page_header("Оплаты", $user);
?>
<div class="flex flex-wrap justify-between items-center gap-3 mb-4">
    <h1 class="text-2xl font-bold">Оплаты</h1>
    <p class="card px-4 py-2">Получено в этом месяце: <strong><?= e(money($month)) ?></strong></p>
</div>

<div class="flex gap-2 mb-4 text-sm">
    <?php foreach (["open" => "Ждут проверки", "paid" => "Оплаченные", "all" => "Все"] as $k => $label): ?>
        <a href="manage-payments.php?status=<?= $k ?>" class="px-3 py-1.5 rounded-full <?= $filter === $k ? "bg-blue-900 text-white" : "bg-white" ?>"><?= $label ?></a>
    <?php endforeach; ?>
</div>

<div class="space-y-3">
<?php if (!$payments): ?><div class="card p-6 text-slate-500">Ничего нет.</div><?php endif; ?>
<?php foreach ($payments as $p): ?>
    <div class="card p-5 flex flex-wrap gap-4 justify-between">
        <div>
            <p class="font-bold">№<?= (int)$p["id"] ?> · <?= e($payment_types[$p["item_type"]]) ?>: <?= e($p["title"]) ?></p>
            <?php if ($p["note"]): ?><p class="text-sm">📝 <?= e($p["note"]) ?></p><?php endif; ?>
            <p class="text-sm text-slate-500"><?= e($p["name"]) ?> · <?= e($p["email"]) ?> · <?= e($p["phone"]) ?></p>
            <p class="text-sm text-slate-500"><?= fmt_dt($p["created_at"]) ?> · комментарий к переводу: NII-<?= (int)$p["id"] ?></p>
            <?php if ($p["receipt_file"]): ?><a href="<?= e(upload_url($p["receipt_file"])) ?>" target="_blank" class="text-blue-800 font-semibold text-sm">🧾 Открыть чек</a><?php else: ?><span class="text-sm text-slate-400">Чек ещё не загружен</span><?php endif; ?>
        </div>
        <div class="text-right">
            <p class="text-2xl font-bold"><?= e(money($p["amount"], $p["currency"])) ?></p>
            <p class="text-sm"><?= ["pending" => "ждёт оплаты", "review" => "🟡 чек на проверке", "paid" => "✅ оплачено", "rejected" => "❌ отклонено"][$p["status"]] ?></p>
            <?php if (in_array($p["status"], ["pending", "review"], true)): ?>
            <div class="flex gap-2 mt-2 justify-end">
                <form method="POST"><?= csrf_field() ?><input type="hidden" name="action" value="confirm"><input type="hidden" name="id" value="<?= (int)$p["id"] ?>">
                    <button class="btn btn-green" <?= $p["receipt_file"] ? "" : "onclick=\"return confirm('Чека нет. Подтвердить всё равно?')\"" ?>>Подтвердить</button></form>
                <form method="POST" onsubmit="return confirm('Отклонить оплату?')"><?= csrf_field() ?><input type="hidden" name="action" value="reject"><input type="hidden" name="id" value="<?= (int)$p["id"] ?>">
                    <button class="btn btn-danger">Отклонить</button></form>
            </div>
            <?php endif; ?>
        </div>
    </div>
<?php endforeach; ?>
</div>
<?php page_footer();
