return {
  id = "practical_refactor",
  name = "実践①: コードリファクタリング",
  description = "シグネチャ変更, ブロック移送",
  problems = {
    {
      id = "refactor_01",
      title = "関数シグネチャと呼出側の追従",
      mission = "`ctx` を第1引数として追加せよ",
      filetype = "csharp",
      cursor = { 1, 0 },
      initial = "public void Handle(Request req) {\n    Execute(req);\n}",
      target = "public void Handle(Context ctx, Request req) {\n    Execute(ctx, req);\n}",
      ideal_keys = "f(aContext ctx, <Esc>jf(actx, <Esc>",
      ideal_count = 24,
      explanation = "f( と a で引数位置に瞬時にジャンプし、引数を挿入します。",
    },
  },
}
