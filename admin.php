<?php
$file = 'database.json';
$data = json_decode(file_get_contents($file), true) ?: [];

if (isset($_POST['update'])) {
    $id = $_POST['order_id'];
    $data[$id] = [
        'views' => $_POST['views'],
        'clicks' => $_POST['clicks'],
        'spend' => $_POST['spend']
    ];
    file_put_contents($file, json_encode($data));
    echo "<script>alert('داتاکان نوێکرانەوە');</script>";
}
?>
<!DOCTYPE html>
<html dir="rtl" lang="ku">
<head><meta charset="UTF-8"><script src="https://cdn.tailwindcss.com"></script></head>
<body class="p-8 bg-gray-100">
    <div class="max-w-md mx-auto bg-white p-6 rounded-xl shadow">
        <h2 class="font-bold mb-4">نوێکردنەوەی داتای کڕیار</h2>
        <form method="POST" class="space-y-4">
            <input type="text" name="order_id" placeholder="کۆدی داواکاری (T-1234)" class="w-full p-2 border rounded" required>
            <input type="text" name="views" placeholder="ژمارەی بینەر (بۆ نموونە: 120k)" class="w-full p-2 border rounded">
            <input type="text" name="clicks" placeholder="ژمارەی کلیک" class="w-full p-2 border rounded">
            <input type="text" name="spend" placeholder="خەرجی بە دۆلار" class="w-full p-2 border rounded">
            <button name="update" type="submit" class="w-full bg-green-600 text-white p-2 rounded">پاشەکەوت بکە</button>
        </form>
    </div>
</body>
</html>
