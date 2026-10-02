<?php
require_once "config.php";
require_once "layout.php";

$error = "";
$roles = [
    "user"  => ["Участник", "Курсы, конференции, программы, онлайн-лаборатория"],
    "team"  => ["Команда НИИ", "Сотрудники и исследователи: задачи, лаборатория, встречи"],
    "admin" => ["Организатор (админ)", "Управление НИИ: задачи, курсы, конференции, оплаты"],
];

if (is_post()) {
    $name = post("name");
    $email = post("email");
    $password = $_POST["password"] ?? "";
    $role = isset($roles[post("role")]) ? post("role") : "user";
    $code = post("access_code");
    $family = $_POST["family_code"] ?? "";

    if ($name === "" || !filter_var($email, FILTER_VALIDATE_EMAIL) || !preg_match('/\.[a-z]{2,}$/i', $email)) {
        $error = "Укажите имя и правильный email (например, name@gmail.com).";
    } elseif (strlen($password) < 6) {
        $error = "Пароль должен быть не короче 6 символов.";
    } elseif ($role === "admin" && !hash_equals($settings["admin_code"], $code)) {
        $error = "Неверный код организатора.";
    } elseif ($role === "team" && !hash_equals($settings["team_code"], $code)) {
        $error = "Неверный код команды НИИ.";
    } elseif ($family !== "" && !is_free_access_code($family)) {
        sleep(1);
        $error = "Неверный семейный пароль.";
    } elseif (row("SELECT id FROM users WHERE email = ?", [$email])) {
        $error = "Этот email уже зарегистрирован. Войдите через «Вход».";
    } else {
        q("INSERT INTO users (name, email, password, role, phone, organization, is_family) VALUES (?, ?, ?, ?, ?, ?, ?)",
          [$name, $email, password_hash($password, PASSWORD_DEFAULT), $role, post("phone"), post("organization"), $family !== "" ? 1 : 0]);

        session_regenerate_id(true);
        $_SESSION["uid"] = insert_id();
        flash("Добро пожаловать в NII App!");
        redirect($role === "admin" ? "admin.php" : "home.php");
    }
}

page_header("Регистрация");
?>
<div class="max-w-lg mx-auto card p-6 md:p-8 mt-4">
    <h1 class="text-2xl font-bold mb-6">Регистрация</h1>

    <?php if ($error): ?><p class="mb-4 p-3 rounded-lg bg-red-100 text-red-800 font-semibold"><?= e($error) ?></p><?php endif; ?>

    <form method="POST" class="space-y-4">
        <?= csrf_field() ?>

        <div>
            <label class="label">Кто вы?</label>
            <div class="space-y-2">
            <?php foreach ($roles as $key => [$label, $hint]): ?>
                <label class="flex gap-3 items-start border rounded-xl p-3 cursor-pointer has-[:checked]:border-blue-800 has-[:checked]:bg-blue-50">
                    <input type="radio" name="role" value="<?= $key ?>" <?= (post("role", "user") === $key) ? "checked" : "" ?> onchange="toggleCode()" class="mt-1">
                    <span><strong><?= e($label) ?></strong><br><span class="text-sm text-slate-500"><?= e($hint) ?></span></span>
                </label>
            <?php endforeach; ?>
            </div>
        </div>

        <div id="codeBox" class="hidden">
            <label class="label">Код доступа (выдаёт организатор)</label>
            <input class="field" type="password" name="access_code" autocomplete="off">
        </div>

        <div>
            <label class="label">Имя и фамилия</label>
            <input class="field" name="name" value="<?= e(post("name")) ?>" required>
        </div>
        <div>
            <label class="label">Email</label>
            <input class="field" type="email" name="email" value="<?= e(post("email")) ?>" placeholder="name@gmail.com" pattern="[^@\s]+@[^@\s]+\.[^@\s]+" required>
        </div>
        <div>
            <label class="label">Пароль (минимум 6 символов)</label>
            <input class="field" type="password" name="password" minlength="6" required autocomplete="new-password">
        </div>
        <div class="grid sm:grid-cols-2 gap-4">
            <div>
                <label class="label">Телефон</label>
                <input class="field" name="phone" value="<?= e(post("phone")) ?>" placeholder="+7 ...">
            </div>
            <div>
                <label class="label">Организация</label>
                <input class="field" name="organization" value="<?= e(post("organization")) ?>">
            </div>
        </div>

        <details class="text-sm">
            <summary class="cursor-pointer text-slate-600">У меня есть семейный пароль</summary>
            <input class="field mt-2" type="password" name="family_code" autocomplete="off" placeholder="Семейный пароль">
        </details>

        <button class="btn btn-primary w-full">Создать аккаунт</button>
    </form>

    <p class="mt-6 text-center text-slate-600">Уже есть аккаунт? <a href="login.php" class="text-blue-800 font-semibold">Войти</a></p>
</div>

<script>
function toggleCode() {
    const role = document.querySelector('input[name=role]:checked').value;
    document.getElementById("codeBox").classList.toggle("hidden", role === "user");
}
toggleCode();
</script>
<?php page_footer();
