# ファクトチェックレポート — パナソニック NP-TSP1-W レビュー記事

**チェック実施日:** 2026-02-22  
**対象ファイル:** `content/posts/2026-02-22-dishwasher-tabletop/index.md`

---

## 参照URL一覧

| # | 種別 | URL | アクセス結果 | 確認内容 |
|---|------|-----|:---:|----------|
| 1 | パナソニック公式仕様ページ | https://panasonic.jp/dish/p-db/NP-TSP1_spec.html | ✅ 取得成功 | 容量・庫内容積・エコナビ・予約機能・運転音・本体寸法・重量 |
| 2 | パナソニック公式サポート（消耗品・別売品） | https://panasonic.jp/dish/products/NP-TSP1/support.html | ✅ 取得成功 | 別売り給水ホース（ANP1251-7235、ANP1251-7245）の存在を確認 |
| 3 | パナソニック公式特長ページ | https://panasonic.jp/dish/products/NP-TSP1/points.html | ⚠️ JSリダイレクトのみ・本文未取得 | 技術的に取得不可 |
| 4 | パナソニック公式製品ページ | https://panasonic.jp/dish/products/NP-TSP1.html | ⚠️ JSリダイレクトのみ・本文未取得 | 技術的に取得不可 |
| 5 | パナソニック FAQ (a_id=9030) | https://jpn.faq.panasonic.com/app/answers/detail/a_id/9030 | ❌ 「ご利用できません」 | 該当ページ存在せず |
| 6 | パナソニック FAQ (a_id=80030) | https://jpn.faq.panasonic.com/app/answers/detail/a_id/80030 | ❌ 食洗機と無関係（LAN配線器具のFAQ） | 参照不可 |
| 7 | _snapshot.json（楽天APIエビデンス） | content/posts/2026-02-22-dishwasher-tabletop/_snapshot.json | ✅ ローカル参照 | 価格・レビュー件数・レビュー評価・ショップ名・5年保証 |

---

## ファクトチェック詳細

### ✅ 確認済み・正確な記述

---

賃貸でも使えるのがポイントで調べてみたら**タンク式食洗機**という選択肢があるとわかって、そこからNP-TSP1-Wにたどり着きました。<sup><a href="#fn1" id="ref1">参照1</a></sup>

---

容量は**食器点数24点（4人用）**なので、3人家族なら余裕で一度に収まります。<sup><a href="#fn2" id="ref2">参照2</a></sup>

---

買ってから楽天のレビューを見たら★4.64（69件）で、「あ、ちゃんと選べてた」と安心しました。<sup><a href="#fn3" id="ref3">参照3</a></sup>

---

**楽天で5年保証付きショップがあった**：masaniosというショップで、購入時に5年延長保証が無料でつく<sup><a href="#fn4" id="ref4">参照4</a></sup>

---

公式スペックでは約39〜41dBですが<sup><a href="#fn5" id="ref5">参照5</a></sup>

---

**4時間後に予約スタートできる機能**<sup><a href="#fn6" id="ref6">参照6</a></sup>

---

1回の運転で**約9L**使う<sup><a href="#fn7" id="ref7">参照7</a></sup>

---

実はNP-TSP1-Wは別売りの給水ホース（ANP1251-7235など）と分岐水栓を組み合わせれば、**水道直結での給水も可能**です。毎回タンクに入れる手間がなくなるので便利なはずなんですが——賃貸だと分岐水栓の取り付けが工事扱いになり、**退去時の原状回復でもめる可能性がある**んですよね。<sup><a href="#fn8" id="ref8">参照8</a></sup>

---

### ⚠️ 修正済みの記述

初回ファクトチェック時に「タンク専用・直結不可」と誤判定しましたが、公式サポートページに別売り給水ホースの記載があり、**分岐水栓+別売りホースで直結給水が可能**であることを確認。著者の体験談（賃貸での断念理由）は正確でした。記事内容を正確な方向に修正しました。

---

<h2>ファクトチェック根拠（人間確認用）</h2>

<p id="fn1">参照1 ✅ <strong>正確</strong>: NP-TSP1-Wはタンク式（工事不要）の卓上型食器洗い乾燥機。仕様表で「タンク式」との記載および付属品に「給水カップ」の記載あり。一次情報: <a href="https://panasonic.jp/dish/p-db/NP-TSP1_spec.html">パナソニック公式仕様ページ</a> <a href="#ref1">元の場所に戻る</a></p>

<p id="fn2">参照2 ✅ <strong>正確</strong>: 公式仕様表「容量（食器点数）★1 | 24点」。注釈★1「収納できる食器点数は標準食器の場合（日本電機工業会自主基準）」。一次情報: <a href="https://panasonic.jp/dish/p-db/NP-TSP1_spec.html">パナソニック公式仕様ページ</a> <a href="#ref2">元の場所に戻る</a></p>

<p id="fn3">参照3 ✅ <strong>正確</strong>: _snapshot.json（2026-02-22T15:15:18+09:00）に「reviewCount: 69, reviewAverage: 4.64, shopName: マサニ電気株式会社 楽天市場店」として記録済み。一次情報: content/posts/2026-02-22-dishwasher-tabletop/_snapshot.json <a href="#ref3">元の場所に戻る</a></p>

<p id="fn4">参照4 ✅ <strong>正確</strong>: _snapshot.json の rawName に「5年延長保証無料進呈★」の記載あり。ショップ名「マサニ電気株式会社 楽天市場店」で確認済み。一次情報: content/posts/2026-02-22-dishwasher-tabletop/_snapshot.json <a href="#ref4">元の場所に戻る</a></p>

<p id="fn5">参照5 ✅ <strong>正確</strong>: 公式仕様表「運転音＜50Hz/60Hz＞★5 | 約39dB/約41dB」。注釈★5「日本電機工業会自主基準（2008年3月5日改訂）による」。一次情報: <a href="https://panasonic.jp/dish/p-db/NP-TSP1_spec.html">パナソニック公式仕様ページ</a> <a href="#ref5">元の場所に戻る</a></p>

<p id="fn6">参照6 ✅ <strong>正確</strong>: 公式仕様表「予約機能 | ○（選択したコースを4時間後にスタート）」。一次情報: <a href="https://panasonic.jp/dish/p-db/NP-TSP1_spec.html">パナソニック公式仕様ページ</a> <a href="#ref6">元の場所に戻る</a></p>

<p id="fn7">参照7 ✅ <strong>正確</strong>: 公式仕様表「標準使用水量★3 | 約9L（タンク式）」。注釈★3「標準食器点数時」。一次情報: <a href="https://panasonic.jp/dish/p-db/NP-TSP1_spec.html">パナソニック公式仕様ページ</a> <a href="#ref7">元の場所に戻る</a></p>

<p id="fn8">参照8 ✅ <strong>正確（修正済み）</strong>: 初回チェック時に「直結不可」と誤判定したが、パナソニック公式サポートページの別売品リストに「ANP1251-7235 食器洗い乾燥機用給水ホース」「ANP1251-7245 食器洗い乾燥機用給水ホース」がNP-TSP1対応品として掲載されており、分岐水栓との組み合わせで直結給水が可能であることを確認。公式仕様表で「給水ホース長 | 給水 | ー」は「標準付属なし（別売り対応）」の意味であった。著者の体験談（賃貸での原状回復問題で断念）は正確。一次情報: <a href="https://panasonic.jp/dish/products/NP-TSP1/support.html">パナソニック公式サポートページ（消耗品・別売品）</a> <a href="#ref8">元の場所に戻る</a></p>
