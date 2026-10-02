<?php
// Payment for Pro / course / event / merch: Kaspi instructions + receipt upload.

require_once "config.php";
require_once "layout.php";

$user = require_login();
$uid = (int)$user["id"];

// Existing payment (open it by its number)
if (isset($_GET["payment"])) {
    $payment = row("SELECT * FROM payments WHERE id = ? AND user_id = ?", [(int)$_GET["payment"], $uid]);
    if (!$payment) {
        die("Платёж не найден.");
    }
} else {
    $type = $_GET["type"] ?? "";
    $item_id = (int)($_GET["id"] ?? 0);
    $item = isset($payment_types[$type]) ? payable_item($type, $item_id) : null;

    if (!$item) {
        die("Нечего оплачивать.");
    }

    // Family access: digital items are free (merch is still paid)
    if ($user["is_family"] && $type !== "product") {
        fulfil_payment(["user_id" => $uid, "item_type" => $type, "item_id" => $item_id]);
        flash("Семейный доступ: бесплатно, уже доступно!");
        redirect($type === "course" ? "course.php?id=$item_id" : ($type === "event" ? "event.php?id=$item_id" : "home.php"));
    }

    // Reuse an unfinished payment for the same item
    $payment = row("SELECT * FROM payments WHERE user_id = ? AND item_type = ? AND COALESCE(item_id, 0) = ? AND status IN ('pending', 'review') ORDER BY id DESC LIMIT 1",
                   [$uid, $type, $item_id]);

    if (!$payment) {
        q("INSERT INTO payments (user_id, item_type, item_id, title, amount, currency, note) VALUES (?, ?, ?, ?, ?, ?, ?)",
          [$uid, $type, $type === "pro" ? null : $item_id, $item["title"], $item["price"], $settings["currency"], mb_substr(trim((string)($_GET["note"] ?? "")), 0, 300)]);
        $payment = row("SELECT * FROM payments WHERE id = ?", [insert_id()]);
    }
}

if (is_post() && in_array($payment["status"], ["pending", "review"], true)) {
    $receipt = save_upload("receipt", ["pdf", "jpg", "jpeg", "png"], 10);

    if (!$receipt) {
        flash("Загрузите чек в формате PDF, JPG или PNG (до 10 МБ).", "error");
    } else {
        q("UPDATE payments SET receipt_file = ?, status = 'review' WHERE id = ?", [$receipt, (int)$payment["id"]]);
        flash("Чек получен! Мы проверим оплату и откроем доступ.");
    }
    redirect("pay.php?payment=" . (int)$payment["id"]);
}

$status = [
    "pending"  => ["Ожидает оплаты", "bg-blue-100 text-blue-800"],
    "review"   => ["Чек на проверке", "bg-yellow-100 text-yellow-800"],
    "paid"     => ["Оплачено ✓", "bg-green-100 text-green-800"],
    "rejected" => ["Отклонено", "bg-red-100 text-red-800"],
][$payment["status"]];

page_header("Оплата", $user);
?>
<div class="max-w-xl mx-auto card p-6 md:p-8">
    <div class="flex justify-between gap-3 items-start">
        <div>
            <p class="text-sm text-slate-500"><?= e($payment_types[$payment["item_type"]]) ?> · платёж №<?= (int)$payment["id"] ?></p>
            <h1 class="text-2xl font-bold"><?= e($payment["title"]) ?></h1>
            <?php if ($payment["note"]): ?><p class="text-slate-500"><?= e($payment["note"]) ?></p><?php endif; ?>
        </div>
        <span class="chip <?= $status[1] ?>"><?= $status[0] ?></span>
    </div>

    <p class="text-3xl font-bold text-blue-900 mt-4"><?= e(money($payment["amount"], $payment["currency"])) ?></p>

    <?php if (in_array($payment["status"], ["pending", "review"], true)): ?>
        <div class="mt-6 p-5 rounded-xl bg-slate-50">
            <h2 class="font-bold mb-2">Как оплатить</h2>
            <p class="whitespace-pre-line text-slate-700"><?= e($settings["payment_instructions"]) ?></p>
            <p class="mt-3">Комментарий к переводу: <strong>NII-<?= (int)$payment["id"] ?></strong></p>
        </div>

        <form method="POST" enctype="multipart/form-data" class="mt-6 space-y-3">
            <?= csrf_field() ?>
            <label class="label"><?= $payment["status"] === "review" ? "Загрузить другой чек" : "Загрузите чек после оплаты" ?></label>
            <input class="field" type="file" name="receipt" accept=".pdf,.jpg,.jpeg,.png,image/*" required>
            <button class="btn btn-primary w-full">Отправить чек</button>
        </form>
    <?php elseif ($payment["status"] === "paid"): ?>
        <p class="mt-6 p-4 rounded-xl bg-green-50 text-green-800">Оплата подтверждена <?= fmt_dt($payment["paid_at"]) ?>. Спасибо!</p>
    <?php else: ?>
        <p class="mt-6 p-4 rounded-xl bg-red-50 text-red-800">Платёж отклонён. Если это ошибка — напишите организаторам или оформите заново.</p>
    <?php endif; ?>

    <a href="profile.php#payments" class="block text-center text-blue-800 font-semibold mt-6">Мои платежи →</a>
</div>
<?php page_footer();
