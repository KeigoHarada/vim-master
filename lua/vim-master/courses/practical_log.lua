return {
  id = "practical_log",
  name = "実践②: ログ解析・データ整形",
  description = "マクロ, :g, :s 一括処理",
  problems = {
    {
      id = "log_01",
      title = "エラー行以外の全削除",
      mission = "INFOログを削除し、ERROR行のみを残せ",
      filetype = "text",
      cursor = { 1, 0 },
      initial = "[INFO] User logged in\n[ERROR] Connection failed\n[INFO] Cache cleared\n[ERROR] Timeout reached",
      target = "[ERROR] Connection failed\n[ERROR] Timeout reached",
      ideal_keys = ":v/ERROR/d<CR>",
      ideal_count = 11,
      explanation = ":v/パターン/d は、パターンに一致しない行をすべて一括削除するVimの超強力なコマンドです。",
    },
  },
}
