<?php
$file = 'database.json';
$data = json_decode(@file_get_contents($file), true) ?: [];

if (isset($_POST['update'])) {
    $id = $_POST['order_id'];
    $data[$id] = [
        'views' => $_POST['views'],
        'clicks' => $_POST['clicks'],
        'spend' => $_POST['spend']
    ];
    file_put_contents($file, json_encode($data));
    $msg = "✅ داتاکان بۆ کۆدی $id نوێکرانەوە";
}
?>
<!DOCTYPE html>
<html dir="rtl" lang="ku">
<head>
    <meta charset="UTF-8">
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 p-8 font-sans">
    <div class="max-w-md mx-auto bg-white p-6 rounded-3xl shadow-lg">
        <h2 class="font-bold text-xl mb-6 text-center text-blue-600">بەڕێوبەرایەتی سپۆنسەر</h2>
        
        <?php if(isset($msg)) echo "<p class='bg-green-100 text-green-700 p-3 rounded-xl mb-4 text-center'>$msg</p>"; ?>

        <form method="POST" class="space-y-4">
            <div>
                <label class="block text-sm mb-1">کۆدی داواکاری (Order ID):</label>
                <input type="text" name="order_id" placeholder="T-1234" class="w-full p-3 border rounded-xl outline-none focus:ring-2 focus:ring-blue-500" required>
            </div>
            <div class="grid grid-cols-2 gap-4">
                <input type="text" name="views" placeholder="بینەر (10k)" class="p-3 border rounded-xl outline-none">
                <input type="text" name="clicks" placeholder="کلیک (200)" class="p-3 border rounded-xl outline-none">
            </div>
            <input type="text" name="spend" placeholder="خەرجی بە دۆلار" class="w-full p-3 border rounded-xl outline-none">
            <button name="update" type="submit" class="w-full bg-blue-600 text-white p-4 rounded-xl font-bold hover:bg-blue-700">نوێکردنەوەی ئەنجام</button>
        </form>
    </div>
</body>
</html>
