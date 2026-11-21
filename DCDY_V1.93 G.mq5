//+------------------------------------------------------------------+
//|  DuoCaiDuoYi_V1.mq5   多財多億 V1                                  |
//|  雙向獨立網格馬丁：首單錨定格線 + 手數階梯 + 整籃均價止盈          |
//|  交易邏輯 = v1.20（120 秒冷卻 + 每輪最多補 5 層），1–10 月回測未爆倉 |
//+------------------------------------------------------------------+
#property copyright "多財多億"
#property version   "1.93"
// v1.93：基於 Claude V1.92 機體，堅守「100% 券商端止盈、不加寬格槓桿（HotLotMul 維持 4.0）、一般鏈維持 VL=10」原則，僅加入 3 項低過擬合結構優化與 1 項重啟修補：
//        1) HotTPUsd 預設 2.10 → 2.40：落在寬格止盈單調平滑高原（1.2～2.4）上緣，2025／2026 方向一致且最差回撤不升反降
//        2) TBTPUsd 預設 0 → 1.80 ＋ 新增 TBTPMaxL＝12（淺層保護順勢止盈）：順勢加碼鏈在 ≤L12（真正順勢階段）改用 1.80 美元券商端止盈，
//           一旦反轉套深（>L12）立即自動退回 0.80 美元加速解套——徹底解決 V1.92 無上限 TBTPUsd 在 2026/7/14 拖累回撤與多爆倉的問題
//        3) 新增 HotVirtualLayers＝5、TBVirtualLayers＝5（一般鏈維持 VirtualLayers＝10）：過熱寬格鏈（每格 $5.45）與順勢加碼鏈前 5 層採虛擬層，
//           補回 VL=10 在高波動／順勢前段錯失的安全利潤，同時完全保留一般鏈 VL=10 的低手續費與 0 超線防禦力
//        4) 實盤重啟修補（HotLoad）：修正當寬格／順勢鏈仍在虛擬層階段（CountSide==0 && g_vlOn）重啟 MT5 時，HotLoad 誤刪鏈倍數全域變數的盲點
//        5) 保留 V1.92 全部安全機制：HotLotMul=4.0、UseMidLadder=true、BasketTrailDist=0.0（100% 券商端 TP，無 EA 斷線滑價依賴）、週五提前出場與鎖利 SL 架構
//        模擬器完整 83 組壓力驗證（V1.92 → V1.93，100k USC，含 6 USC/手佣金）：
//          2025 單路徑（120/30）：淨利 359,572 → 371,751（+3.4%），最大回撤 99,667 → 99,033（降 634），PF 2.24 → 2.29
//          2026 單路徑（120/30）：淨利 628,394 → 669,028（+6.5%），最大回撤 78,447 → 78,160（降 287），PF 2.21 → 2.22
//          2025 年 36 情境：淨利合計 9,352k → 9,765k（+4.4%），爆倉 0/36，>100k 0/36，最差回撤 99,881 → 99,589
//          2026 年 2–9 月 32 情境：淨利合計 10,974k → 11,704k（+6.7%），爆倉 0/32，>100k 0/32，最差回撤 78,595 → 78,436
//          2026/1/2 起 4 情境：淨利合計 2,362k → 2,509k（+6.2%），爆倉 0/4，>100k 0/4，最差回撤 78,595 → 78,436
//          22 個月每日出金 10 萬（9 組冷卻）：中位淨現金 864,576 → 880,376（+1.8%），最差組 729,506 → 766,308（+5.0%），最佳組 897,518 → 961,985（+7.2%），爆倉合計 9 → 10
// v1.92：V1.90 ＋ 寬格止盈 2.10 ＋ 順勢極速重開（交易邏輯只改以下三處，其餘與 v1.90 完全相同）
//        1) HotTPUsd 預設 1.80 → 2.10：寬格鏈整籃止盈。1.2～2.4 淨利平滑上升、2025／2026 方向一致、最差回撤不變（不追 2.40）
//        2) 新增 TrendReopenSec＝3（順勢極速重開）：對面鏈已補到 TrendBoostLayer(L20) 以上時，這一邊止盈後的重開冷卻由 ReopenCooldownSec(30) 縮為 3 秒；
//           需 EnableSafeMode＝true；設 0＝關閉＝與 v1.90 相同。靈感來自 Gemini V1.91 R2，但只取這一項，且不改手數
//        3) 新增 TBTPUsd（順勢加碼鏈專屬止盈，預設 0＝關閉＝與 v1.90 相同）：模擬器 1.1～1.8 淨利單調上升（+3～15%），
//           但 2026/7/14 那條順勢鏈被套時最差回撤 68.7k→80.9k、22 個月連續多 1 次爆倉，不符「爆倉不增加」原則，所以預設關閉；要試請從 1.10 起
//        刻意不採用的 Gemini V1.91 項目：HotLotMul 5.5（2026 最差回撤 68.7k→94.1k，淨利只多 +9%）、
//           分段收緊追蹤與寬格追蹤（80% 的手數靠 EA 市價平倉，斷線、滑價風險）、VirtualLayers 5
//        研究後排除：寬格鏈深層回收（L12～L21）與寬格手數只放大前段（L16／L20）→ 2025 年 18/18 情境爆倉；寬格鏈額外虛擬層 → 淨利 −3～5%
//        模擬器（行情已修正）V1.90 → V1.92：
//          2025 年 36／2026 年 2–9 月 32 情境（縮減組）：爆倉 0 → 0；回撤超過 10 萬 0 → 0；2026 最差回撤 68,717 不變；2025 最差 95,910 → 96,428
//          144 壓力情境：爆倉 0 → 0；最差回撤 70,405 不變；淨利中位 326,492 → 336,636（+3.1%）
//          22 個月連續出金 10 萬（9 組冷卻）：淨現金中位 775,788 → 829,929（+7.0%）；最差 646,530 → 717,561；爆倉合計 9 → 10（同樣的 1/5 空鏈日期，多一組）
//        尚無 V1.92 的 MT5 實測：請用 VL10、冷卻 120/30，跑 2025、2026 兩段與 10/1 起跑
// v1.90：V1.89 ＋ Gemini V1.89 的兩項止盈改動（交易邏輯只改以下兩項，其餘與 v1.89 完全相同）
//        1) 寬格鏈專屬止盈 HotTPUsd＝1.80（預設開）：過熱寬格鏈（格距 ×5、一格 5.45 美元）的整籃止盈由 0.80 改為 1.80；
//           一般鏈不受影響。MT5 實測（V1.88 底、VL5、冷卻 120/30）Gemini 版 2026 年淨利 +11.6%，大部分來自這一項
//        2) 整籃追蹤止盈（預設關閉，BasketTrailDist=0）：照 Gemini 的邏輯放進來，並修三個實盤風險
//           a. 追蹤啟動後，伺服器端每張單加「保底鎖利價」（均價 ± BasketTrailFloor，高於均價，不是停損）：
//              EA 斷線、跳價時仍由券商在保底價出場（Gemini 版只靠 EA 市價平倉，2026/5/4 L40 鏈跌破保底）
//           b. 追蹤中照常執行週五收盤前提前出場（Gemini 版會跳過，可能帶單過週末）
//           c. 伺服器 TP 外推距離改為參數 BasketTrailSrvTPUsd；重啟時由鎖利價接回追蹤狀態
//           保留風險：鏈 ≥ BasketTrailMinL 層、追蹤尚未啟動前，伺服器 TP 在原 TP 外，斷線時不會在原 TP 出場
//        3) 面板標題改為 V1.90
//        模擬器（行情已修正；2025 年 36、2026/1/2 起 4、2026 年 2–9 月 32 情境；144 壓力；22 個月連續出金 9 組）V1.89 → V1.90（追蹤止盈關）：
//          2025 年 36 情境：爆倉 0 → 0；回撤超過 10 萬 0 → 0；最差回撤 96,337 不變；淨利合計 8,115k → 8,649k（+6.6%）
//          2026/1/2 起 4 情境：爆倉 0 → 0；最差回撤 68,717 不變；淨利合計 1,979k → 2,191k
//          2026 年 2–9 月 32 情境：爆倉 0 → 0；最差回撤 68,717 不變；淨利合計 9,522k → 10,297k（+8.1%）
//          144 壓力情境：爆倉 0 → 0；最差回撤 69,271 → 70,405；淨利中位 302,077 → 326,492（+8.1%）
//          22 個月連續出金 10 萬（9 組冷卻）：淨現金中位 700,790 → 775,788（+10.7%）；爆倉合計 9 → 9
//          單一路徑 2026/2/1 起：淨利 492,533 → 548,008；最大回撤 58,101 → 66,809（3/3 寬格鏈抱得較久）
//        追蹤止盈開啟（0.50）時模擬器：2026 年 2–9 月淨利合計 9,902k（比預設少）、22 個月中位 860,001，所以預設關閉
// v1.89：V1.88 ＋ 中段手數加密（交易邏輯只改這一項，其餘與 v1.88 完全相同）
//        背景：v1.88 判定「中段加密是過度擬合」是錯的——當時模擬器 2026/10/9–11/4 的行情資料缺盤中反彈，
//        把 11/4 那條空鏈高估成 L67 爆倉；MT5 同路徑（10/1 起跑、冷卻 120／20）實測沒爆倉（回撤 40,222、最深 L45）。
//        用 M1 K 線補回行情後整批重跑，Gemini 的中段加密反而讓 2026/1/5 那條空鏈不再爆倉。
//        1) UseMidLadder 改回輸入參數，預設 true：L11–L21 手數 0.05/0.05/0.06/0.06/0.08/0.12/0.15/0.18/0.20/0.23/0.23
//           → 0.06/0.07/0.09/0.11/0.14/0.18/0.22/0.25/0.28/0.30/0.32（L22 以後不變，仍受 LotCap 限制）
//        2) 維持：TrendBoostFrontLot=0（順勢實單 0.08 讓 2025 年回撤超過 10 萬的情境 0→12 個，只多賺約 1.5%）、
//           VirtualLayers=10、HotLotMul=4.0、配對減倉固定關閉（增益 ±1% 以內）
//        3) 面板標題改為 V1.89
//        模擬器（行情已修正；2025 年 36、2026/1/2 起 4、2026 年 2–9 月 32 情境；144 壓力；22 個月連續出金 9 組）V1.88 → V1.89：
//          2025 年 36 情境：爆倉 0 → 0；回撤超過 10 萬 9 → 0 個；最差回撤 137,238 → 96,337；淨利合計 6,936k → 8,115k（+17%）
//          2026/1/2 起 4 情境：爆倉 1 → 0（1/5 空鏈不再爆）；最差回撤 54,673 → 68,717；淨利合計 1,280k → 1,979k
//          2026 年 2–9 月 32 情境：爆倉 0 → 0；最差回撤 54,673 → 68,717；淨利合計 9,209k → 9,522k（+3.4%）
//          144 壓力情境：爆倉 0 → 0；最差回撤 76,547 → 69,271；淨利中位 291,862 → 302,077（+3.5%）
//          22 個月連續出金 10 萬（9 組冷卻）：淨現金中位 641,708 → 700,790（+9.2%）；爆倉合計 13 → 9
//          單一路徑 2025/1/13 起：最大回撤 90,438 → 96,138（2025/6/12 那條 L59 鏈 20.8 → 21.4 手），已接近 10 萬預算
//        風險提醒：中段手數加密讓 L11–L21 的單層手數變大，單一長鏈的保證金占用上升；尚無 V1.89 的 MT5 實測，請先跑 2025、2026 與 10/1 起跑三段
// v1.88：以 Gemini 的 V1.87 為底，經 Python 模擬器完整情境集驗證後修正（交易邏輯只改以下預設值，其餘不動）
//        1) 中段手數加密 UseMidLadder 取消（改回原版階梯，選項移出屬性面板）：
//           V1.87 在 2026/11/4 07:40 開出的空鏈會補到 L67～L72、24～27 手（V1.84 同一路徑只到 L42），
//           10 萬帳戶 2026/10/1 起跑在 11/5 爆倉；144 壓力情境最差回撤 76,547 → 188,261、超過 10 萬 0 → 32 個。
//           它在 2025 年看起來降低回撤，只是剛好避開 2025/6/12 那條鏈的路徑，屬於路徑過度擬合
//        2) 順勢加碼實單 TrendBoostFrontLot 預設 0.08 → 0（10 萬帳戶）：只多 0～3%，2026 年最差回撤 54k → 78k
//        3) 虛擬層 VirtualLayers 預設 5 → 10（不改路徑，MT5 實測 VL10 手續費少約 1/5）
//        4) 淨正配對減倉 PairTrim 預設關閉（選項移出屬性面板）：模擬器增益 ±1% 以內，屬雜訊
//        5) 保留：過熱寬格鏈手數 HotLotMul 4.0（唯一確認有效的改動，見下）、V1.86 六項實盤盲點修補、冷卻相位輸入
//        6) 修 bug：面板標題仍顯示 V1.85；急速逆向期間每個 tick 寫 4 個終端全域變數 → 改為每 60 秒最多寫一次；
//           只在虛擬層階段記錄的凍結狀態，重啟後不再套到別條鏈
//        模擬器（2025 年 36、2026/1/2 起 4、2026 年 2–9 月 32 情境；144 壓力；22 個月連續出金 9 組）V1.84 → V1.88：
//          2025 年 36 情境：爆倉 0 → 0；淨利合計 5,835k → 6,936k（+19%）；最差回撤 137,238 不變
//          2026 年 2–9 月 32 情境：爆倉 0 → 0；淨利合計 8,336k → 9,608k（+15%）；最差回撤 54,673 不變
//          144 壓力情境：爆倉 0 → 0；最差回撤 76,547 不變；淨利中位 273,691 → 304,990（+11%）
//          22 個月連續出金 10 萬（9 組冷卻）：淨現金中位 553,003 → 681,274（+23%）；爆倉合計 11 → 11（同樣的日期）
//          寬格鏈手數倍數 3／3.5／4／4.5／5 淨利平滑遞增、都沒有新增爆倉；10 萬帳戶寬格鏈可承受逆向約 165 美元（×2 時約 206）
//          2026/1/2 起跑的 1/5 空鏈爆倉（1/4）與 V1.84 相同，本版沒有改善
// v1.87：「安全模式高效率版」—— 針對 2026 年有 43.7% 時間處於 Regime2 寬格模式卻只用到一半回撤預算的現象：
//        1) HotLotMul 拉出為輸入參數並預設 2.0 → 4.0（維持 5 倍寬格，實測高原 3.0~4.5 全數 0 爆倉）
//        2) TrendBoostFrontLot 預設 0.0 → 0.08（10 萬帳戶安全實單門檻，兼顧降回撤與順勢收割）
//        3) VirtualLayers 預設 10 → 5（與 MT5 實測一致）；保留 V1.86 中段階梯、PairTrim 與全部 6 項實盤 Bug 修補
//        模擬器 22 個月(9組冷卻,10萬本金)：爆倉 8→6 次（4組0爆）、中位淨現金 577k→763k(+32%)、2026 單路 557k（不扣費 574k）
// v1.86：整合回測勝出方案（A1-Med 中段手數密度＋PairTrim 淨正配對減倉＋安全模式可切換＋冷卻相位錯開輸入）
//        並修補 6 項實盤程式碼盲點：
//        1) 凍結狀態 g_frozen / g_frozenVel / g_velTrig 持久化（重啟不遺忘凍結與重定錨）
//        2) AnchorLoad 改 >= 比對、HotSave/HotLoad 補開倉時間戳比對
//        3) 新增 MarketTradeable() 停盤/休市保護，且 SyncTP 改實際送單才扣改單額度
//        4) FridayCloseSec() 改每日重查券商收盤時間（不再永久快取）
//        5) 偵測休市重開/跳空（>30 分鐘）強制首輪限補 1 層；修正 VelPast() 跨週末誤讀上週五 M1 Open
//        6) 2027 年底新聞表過期自動接軌 MT5 日曆（非回測）；美歐 DST 錯位期自動補償 1 小時
// v1.85：「V1.79 模式」—— 與 V1.84 只差三個固定值（Regime2Pct 11→0、EdgePct 2.5→0、TrendBoostLayer 20→0），其餘完全相同
//        效果＝關掉長期過熱暫停（含 V1.81 寬格模式）、高低點過濾（高點不開空鏈／低點不開多鏈）、V1.82／V1.83 順勢加碼；
//        交易邏輯回到 V1.78／V1.79（V1.79 只改面板），虛擬層 10、2027 新聞表保留。EdgeBlockLow 在 EdgePct=0 時不起作用
//        風險（模擬器估算，V1.80 回測紀錄）：V1.78／V1.79 在 198 個起跑情境爆倉率 19.2%，2025 年 36 情境爆 20 次；V1.80 以後（有保護）只有 1.0%、0 次
//        10 萬帳戶逆向約 110～130 美元沒有回調就會爆。要恢復保護，把這三個值改回 11.0／2.5／20（或直接換用 V1.84）
// v1.84（重新發行）：V1.83 升級版（三項，其餘交易邏輯與 v1.83 完全相同）
//        1) 低點側過濾可關（新參數 EdgeBlockLow，預設 false＝放行）：v1.80 的高低點過濾在現價離 60 天最低價不到 2.5% 時不開新多鏈，
//           金價緩跌時多單鏈完全不開、利潤偏低。本版預設放行多鏈；高點側（不開新空鏈）固定開啟、不可關
//           （2025 年的爆倉全部發生在高點側：只關高點側 14/36 爆、全關 14/36 爆、只關低點側 0/36 爆）
//           設 true＝與 v1.83 相同。取代先前版本的 EdgeLowQuietHours（低點靜止 48 小時才放行）
//        2) 虛擬層預設 5 → 10：L5～L9（0.02 手）也只記帳不下單。MT5 實測 VL10 淨利 +0.6%、手續費少約 1/5、下單少約 1/4
//        3) 2027 新聞表依官方時程重建：補齊零售銷售、PCE／GDP、JOLTS 與 12 月數據；FOMC 依聯準會 2026/11/12 修訂
//           （10/27 改為策略會議不公布利率、12/8 移到 11/17）。只影響 2027 年，不影響回測
//        4) 屬性面板精簡：只留 手數（BaseLot、LotCap、TrendBoostFrontLot）、虛擬層、面板、字體、DDBudget、EdgeBlockLow；
//           其餘參數全部改成程式內固定值（數值不變），不再顯示在屬性面板
//        面板：標題 V1.84；底部標籤「LOW-OK」；近低點且已放行時，狀態列顯示「低點過濾已關，照常開多鏈」
//        回測（Python 模擬器，冷卻抖動，模擬器估算，尚未 MT5 實測）V1.83 → 只關低點側：
//          2025 年 36 情境：爆倉 0 → 0；淨利合計 6,974k → 6,975k；2026 年 2–9 月起跑 32 情境：爆倉 0 → 0；淨利合計 8,271k → 8,953k（+8.2%）
//          限制：2025～2026 多為漲勢，低點側放行只被 2026/8～11 約 18% 的下跌驗證過；長期暴跌時多鏈是逆勢方向，風險未充分驗證
//        10 萬帳戶仍請用 TrendBoostFrontLot=0（＝v1.82 模式），其餘照樣有效
// v1.83：「順勢加碼」再加強 —— 加碼的順勢鏈前兩層改用實單、固定手數（只改這一點，其他邏輯與 v1.82 相同）
//        1) v1.82 的順勢加碼鏈，L0～L4 是虛擬層（只記帳不下單），趨勢順順走的時候這條鏈在 L0～L4 就止盈，等於沒賺到
//        2) v1.83：被判定為順勢加碼的鏈不用虛擬層，整條都是實單；第 0～TrendBoostFrontLayers−1 層（L0、L1）手數固定 TrendBoostFrontLot(0.15)，
//           其餘照 v1.82（L2～L9 原手數 ×4，L10 起原手數）。一般鏈、寬格鏈、虛擬層、止盈、格距、冷卻、凍結、回收全部照舊
//        3) TrendBoostFrontLot＝0 即與 v1.82 完全相同；手數隨 BaseLot 等比例放大（BaseLot 0.02 時為 0.30）
//        回測（Python 模擬器，含手續費，起跑前帶 100 天歷史；模擬器估算，尚未 MT5 實測）V1.82 → V1.83：
//          2025 年 9 個起跑日 × 4 組冷卻：爆倉 0/36 → 0/36；淨利合計 +23%；回撤中位 94,007 → 103,939（超過 10 萬的情境 9 → 23 個，最差 13.8 萬不變）
//          2026 年 2～9 月起跑 144 情境：爆倉 0 → 0；淨利中位 243,607 → 268,604（+10%）；最差回撤 79,045 → 93,781
//          2026 年 1/2 起跑 18 組：爆倉 2 → 2（同一條 1/5 空鏈）；淨利中位 348,328 → 370,685
//          22 個月連續、每天出金、15 萬本金：淨現金中位 605,878 → 742,687（+23%），有爆倉的組數 2/9 → 2/9
//          10 萬本金：525,230 → 511,100，爆倉次數變多 → 10 萬帳戶請設 TrendBoostFrontLot=0（或 TrendBoostLayer=0 用 v1.81）
//        參數範圍：手數 0.10～0.20 × 前 2～3 層都沒有新增爆倉；0.30×2 層在 2025/6/16 爆倉（12/36）、0.15×5 層爆倉，請勿超過 0.20、3 層
//        面板：頁尾 TB 改顯示 TB+；底圖金條右下角改成「DCDY · XAUUSD」（不再寫版本號，請用新的 DCDY_bg.bmp 覆蓋後再編譯）
// v1.82：新增「順勢加碼」—— 一邊被套很深（正在走趨勢）時，另一邊新開的順勢鏈前段手數放大
//        1) 開新鏈當下，若對面那條鏈已補到 TrendBoostLayer(20) 層以上，且現價離對面鏈最深那張單的成交價不超過 TrendBoostNearUsd(3) 美元
//           （趨勢還在走、沒有回頭）→ 這條新鏈第 0～TrendBoostMaxLayer−1 層（L0～L9，含虛擬層）手數 × TrendBoostLotMul(4)，L10 起回到原手數
//        2) 倍數在開鏈時決定，整條鏈到結束都不變；可與 v1.81 寬格鏈的手數倍數相乘；止盈、格距、冷卻、凍結、回收、虛擬層照舊
//        3) 倍數存在終端全域變數，EA 重啟後同一條鏈沿用；TrendBoostLayer＝0 即與 v1.81 完全相同
//        為什麼：對面鏈被套到 L20 代表價格已單邊走了約 22 美元以上，這時順勢方向的新鏈大多很快止盈，前幾層放大手數就多賺；
//          不放大深層（整條鏈 ×3 會在 2025/6/12 爆倉），趨勢已回頭不加碼（不檢查時 2026/6/18 一條加碼多鏈補到 L35、回撤 10.1 萬）
//        回測（Python 模擬器，含手續費，起跑前帶 100 天歷史；模擬器估算，尚未 MT5 實測）V1.81 → V1.82：
//          2025 年 9 個起跑日 × 4 組冷卻：爆倉 0/36 → 0/36；淨利中位 134,051 → 141,948（+6%）；回撤中位 66,094 → 94,007（最差 13.9 萬不變）
//          2026 年 1/2 起跑 × 18 組：爆倉 2/18 → 2/18（同一條 1/5 空鏈）；淨利中位 332,257 → 348,328（+5%）；最差回撤 56,246 → 79,045
//          2026 年 2～9 月起跑 144 情境：爆倉 0 → 0；最差回撤 56,246 → 79,045；回撤 p90 55,629 → 55,554；淨利中位 226,735 → 243,607（+7%）
//          MT5 同期間單一路徑：2025/1/2 起 243,074 → 269,581（+11%）；2026/1/2 起 384,306 → 410,333（+7%）
//          2025/1/13～2026/11/12 連續、每天出金到 15 萬、爆倉補 15 萬（9 組冷卻）：淨現金中位 514,145 → 605,878（+18%）；爆倉組數 2/9 → 2/9（都是 2026/1/6）
//          同上但本金 10 萬：淨現金中位 505,737 → 525,230（+4%）；有爆倉的組數 6/9 → 8/9，其中一組多爆一次（2026/8/11）→ 10 萬帳戶不建議開順勢加碼
//        參數平台（4 個起跑日 × 3 組冷卻，未加現價條件時）：觸發層 L20／L25／L30、倍數 3～5、只放大前 6～15 層都沒有新增爆倉；
//          觸發層 L12／L15 多賺 20～35% 但回撤升到 12.2 萬（超過預算）；現價條件 1～5 美元結果相近
//        面板：頁尾參數列多一個 TB；加碼開鏈時「專家」日誌印出「順勢加碼」；其餘樣式不變
//        面板改版（版本號不變）：換成「財神金紅」橫式面板 1040×570（酒紅底、金框、今日進財＋金幣、右側四格數值、金鏈／銀鏈卡片）；
//          底圖 DCDY_bg.bmp 以 #resource 編進 EX5（編譯前須放進 MQL5\Images\）、動態數值疊在底圖上；虧損改綠色、超過預算線改紅色；
//          狀態改中文（運行中／限流／新聞／凍結／週五關閘／近極值／過熱／已停機）；訊息列移到右上；交易邏輯與參數完全不變
//        面板再改版（版本號不變）：換成「黑金」面板 1040×570（黑底金框、金條色塊今日獲利、多空鏈改圓形層數儀表、右側四格數值直排）；
//          底圖同樣是 DCDY_bg.bmp（請用新檔覆蓋 MQL5\Images\ 舊檔再編譯）；狀態鈕恢復英文（RUNNING／THROTTLE／NEWS／FREEZE／FRI GATE／EDGE／HOT／HALTED）；
//          新增 input PanelFontSerif（大數字襯線字型，空白＝Times New Roman）；交易邏輯與參數完全不變
// v1.81：過熱寬格模式 —— 長期波動過熱（Regime2）時不再整段停開新鏈，改成「寬格距、較大手數」繼續做
//        1) 開新鏈當下若長期波動過熱：這條鏈的格距（含深層格距）× HotGridMul(5)、每層手數 × HotLotMul(2)；
//           倍數在開鏈時決定，整條鏈到結束都不變；止盈距離、冷卻、凍結、回收、虛擬層規則照舊
//           例：一般鏈第 35 層在逆向 38 美元處；寬格鏈第 35 層在逆向 191 美元處，所以同樣逆向幅度下層數少很多
//        2) 高低點過濾（Edge）、72 小時過熱（RegimeRange）照舊，仍然不開新鏈
//        3) 倍數存在終端全域變數，EA 重啟後同一條鏈沿用；HotGridMul 設 1 以下＝與 v1.80 完全相同（過熱不開鏈）
//        依據：V1.80 的 MT5 實測（90% 真實報價，2025/1/1～2026/11/12 分兩段）沒有爆倉，扣手續費淨利 162,380＋321,545；
//          模擬器同期間 2025/12/8 起 318,200（MT5 321,545）、最大回撤 62,632（MT5 61,987），逐月相符
//        回測（Python 模擬器，含手續費；模擬器估算，尚未 MT5 實測）V1.80 → V1.81：
//          2025 年 9 個起跑日 × 4 組冷卻：爆倉 0/36 → 0/36；淨利中位 111,538 → 134,051（+20%）
//          2026 年 1/2 起跑 × 18 組：爆倉 2/18 → 2/18（同一條 1/5 空鏈）；淨利中位 246,828 → 332,257（+35%）
//          2026 年 2～9 月起跑 144 情境：爆倉 0 → 0；最差回撤 56,246 → 56,246；淨利中位 198,582 → 226,735（+14%）
//          2/1 起單一路徑：淨利 273,250 → 364,724（+33%）、PF 2.13 → 2.15、最大回撤 55,283 不變
//          2025/1/13～2026/11/12 連續、每天出金到 15 萬、爆倉補 15 萬（9 組冷卻）：淨現金中位 398,311 → 514,145（+29%）；爆倉 0～1 次不變
//          寬格鏈最深只到 L27、單邊最多 8.76 手（一般鏈最深 L59、20.38 手）
//        參數平台（2025 年 36 情境＋2026 年 12 情境）：格距 ×4／×5／×6 配手數 ×2 都沒有新增爆倉；格距 ×3 配手數 ×2 會爆（2026/3/19 多鏈）；
//          格距 ×4 配手數 ×2.5／×3 沒爆但最差回撤 5.5 萬 → 7.7 萬／9.3 萬；止盈距離跟著放大會大量爆倉，所以止盈不動
//        面板：過熱時頁尾改顯示「新鏈改用寬格距」，頁尾參數列多一個 WIDE；其餘樣式不變
// v1.80：新增「安全模式」兩道開新鏈過濾（只影響「要不要開新鏈」；已開的鏈照常補格、止盈，不是停損、不平倉、不用利潤池）
//        1) 長期波動過熱：最近 Regime2Hours(460) 根 H1（約 20 個交易日，含當根）的最高最低價差，超過現價的 Regime2Pct(11%) → 多空都不開新鏈
//           針對 2025 年 4～5 月那種「20 天內來回 15% 以上」的行情（4/23、5/5、5/15 爆倉的鏈都是在這種行情裡開出來的）
//        2) 高低點過濾：現價離最近 EdgeHours(1380) 根 H1（約 60 個交易日，含當根）的最高價不到 EdgePct(2.5%) → 不開新空鏈；
//           離最低價不到 2.5% → 不開新多鏈。針對「價格在高點附近、接著突破一路走」時開出的逆勢鏈（2025/3/13、2026/1/20 爆倉的空鏈）
//        回測（Python 模擬器，含手續費，起跑前帶 100 天歷史；模擬器估算，尚未 MT5 實測）V1.79 → V1.80：
//          2025 年 9 個起跑日 × 4 組冷卻：爆倉 20/36 → 0/36（其中 9 個情境最大回撤約 13.9 萬，靠已累積的獲利撐過）
//          2026 年 1/2 起跑 × 18 組：爆倉 18/18 → 2/18（剩下的是 1/5 開出的空鏈，30 小時逆向 113 美元，兩道過濾都看不出來）
//          2026 年 2～9 月起跑 144 情境：爆倉 0 → 0；最差回撤 84,516 → 56,246；淨利中位 315,876 → 198,582（行情劇烈時不進場，少賺約 37%）
//          2/1 起單一路徑：淨利 598,526 → 273,250、PF 2.05 → 2.13、最大回撤 84,363 → 55,283
//          2025/1/13～2026/11/12 連續跑、每天出金到 10 萬、爆倉隔天補 10 萬（9 組冷卻）：淨現金中位 +18,048 → +376,221；爆倉 7～11 次 → 0～2 次
//        參數平台（2025 年 36 情境的爆倉數）：Regime2Pct 9／10／11 都是 0，12 → 2；Regime2Hours 400 → 2、460 → 0、520 → 1；
//          EdgePct 2／2.5／3 都是 0，1.5 以下 → 8；EdgeHours 920／1380／1840 都是 0。想更保守可把 Regime2Pct 改 10（淨利再少約 25%）
//        兩項都設 0 即與 v1.79 完全相同；面板：過熱時顯示 HOT、高低點暫停時顯示 EDGE，頁尾說明原因，鏈卡片顯示「近高點暫停／近低點暫停」，頁尾參數列多一個 SAFE
//        其餘交易邏輯、面板樣式不變
// v1.79：面板改版「玫瑰金・簡約現代」（只改面板，交易邏輯完全不變）
//        1) 最大的數字改為「今日獲利」：本 EA（Magic）今天已平倉的損益合計，含隔夜利息與手續費；下方顯示今日報酬率與成交筆數
//           以伺服器日期換日；每 2 秒重算一次
//        2) 面板樣式「玫瑰金屬」：象牙白底、白色卡片，今日獲利放在玫瑰金漸層色塊上，數字用 Bahnschrift 粗體
//        3) 字體再加大：主數字 56、區塊數值 21、鏈卡片數值 17、說明文字 12.5～14（基準像素，仍可用 FontScale／PanelScale 再放大）
//        4) 版面精簡：標題 → 今日獲利 → 淨值／浮動盈虧／今日最大回撤／歷史最大回撤 → 回撤預算條 → 多空鏈卡片 → 頁尾
//           拿掉網格、掃描線、角框等裝飾；PanelGlow 改為面板外圍與色塊的柔光
//        5) 配色不用紅綠：賺錢＝玫瑰金、虧損與超出預算＝藍；多鏈＝玫瑰金、空鏈＝銀灰藍
//        移除 v1.77 的三款（鈦藍午夜／精工黑銀／賽博霓虹）與 PanelTheme 參數，面板只剩這一款
// v1.78：新增「虛擬層」—— 每條新鏈的前 VirtualLayers(5) 層（L0～L4，階梯表裡 0.01 手的那五層）只記帳、不下單；
//        從第 VirtualLayers 層（預設 L5、0.02 手）起才真的下單。鏈的走法完全不變：
//        ‧ 錨點＝虛擬首單當下的價格；補格的觸發價、冷卻、每輪補格數、凍結、重新定錨都照原規則，把虛擬層當成已成交的單來算
//        ‧ 整籃止盈價＝「虛擬層＋真實單」的加權均價 ± 0.80（跟 v1.77 同一個價位），真實單的 TP 就設在這個價位
//        ‧ 鏈還沒走到真實層就打到止盈價 → 虛擬鏈直接結束（沒有任何成交），照原規則冷卻後重開
//        為什麼：MT5 真實 tick 報告逐層統計（v1.76，2026/2/1～11/9，扣手續費）L0～L4 這五層合計虧 54,396 美分
//        （L0 −28,077、L1 −18,759、L2 −4,032、L3 −2,180、L4 −1,348）——淺鏈每次只賺 0.8 美分，但只要鏈走深，這幾張單都在最高（低）點被套到整鏈止盈；
//        這五層 0.01 手已是最小手數、無法再縮，只能不下。拿掉後進出場時間點完全相同，所以爆倉情境、回撤路徑與 v1.77 相同
//        回測（Python 模擬器，含手續費）：2/1 起單一路徑淨利 526,085→585,444（+11.3%）、PF 1.65→2.04、最大回撤 84,593→84,363、成交筆數 287,879→57,395
//        不是停損、不是利潤池：沒有任何一張單虧損出場，真實單的出場價位與 v1.77 相同
//        升級時已在跑的鏈（有真實首單）照舊規則跑完，下一條新鏈才套用；VirtualLayers=0 即與 v1.77 完全相同
//        EA 重啟：虛擬層資料存在終端全域變數，有真實單時會接回；只有虛擬層（沒有真實單）時重啟，該虛擬鏈作廢、重新起算
//        面板：鏈卡片在只有虛擬層時顯示「虛擬層」，階梯條前幾格以暗色表示虛擬層；頁尾顯示 VL5
// v1.77：1) 移除手動加倉（面板右側兩條按鍵、ManualButtons／ManualConfirm 參數、確認視窗與下單函式）
//        2) 面板全面改版，預設「賽博霓虹」（PanelTheme=2）；另保留兩版可切換（版面、字型、框線、階梯格樣式各不相同）：
//           PanelTheme 0＝鈦藍午夜（Bahnschrift＋正黑體，圓角、斜格、網格掃描線）
//                      1＝精工黑銀（Segoe UI Light＋正黑體 Light，標題標楷體，切角、細刻度、拉絲金屬，字放大 12%）
//                      2＝賽博霓虹（預設；Consolas 粗體＋微軟雅黑，切角、方塊格、霓虹粗框，字放大 12%）
//           版面重排：大字淨值 → 今日最大回撤（主角，含百分比與發生時間）／目前浮虧 → 橫式回撤預算條（菱形刻度標今日與歷史最大）→ 多空鏈卡片
//           字體整體加大約 15～20%（精工、霓虹再大 12%）；字型都是 Windows 內建，PanelFontNum／PanelFontTxt 可另外指定
//           多單藍、空單橘，賺錢藍、虧損橘（不用紅綠）
//        3) 回撤統計多記「今日最大回撤發生時間」（只供面板顯示）
//        交易邏輯完全不變（與 v1.76 相同）
// v1.76：新增「深層分批回收」—— 鏈的最深層 ≥ RecycleLayer(44) 時，最深那一張單只要價格回到它的格線（或成交價，取較有利者）
//        再往有利方向 RecycleUsd(2 美元），就單獨把這一張獲利平掉；之後價格再回到這一層的格線，照原規則（冷卻、每輪補格）補回來。
//        不是停損：只平賺錢的最深層單；也不是利潤池：平掉的單不拿去抵其他單的虧損。整籃止盈、凍結、過熱等其他邏輯不動
//        回測（Python 模擬器，含手續費，帶起跑前歷史）：2026 年 144 情境爆倉 0（同 V1.75）；最差回撤 88,261→84,752；
//        回撤中位 59,100→55,129；淨利中位 260,198→272,337；2/1 起單一路徑淨利 484,478→526,085、最大回撤 88,179→84,593
//        參數平台：從 L42～L45 開始回收都有效（L40 會失效，所以預設取 L44 留安全距離）；回收金額 1～4 美元結果幾乎相同
// v1.75：1) 慢速逆向凍結：除了 45 分鐘 $60，最近 Vel2WinMin(240) 分鐘逆向超過 Vel2Usd(100 美元）也凍結加倉（同一套凍結＋重新定錨）
//        2) 行情過熱暫停改看 72 小時、門檻 400 美元（原 24 小時 180 美元太敏感，正常波動也常被擋）
//        3) 輸入設定移除：格距 GridStepUsd、整籃止盈 ChainTargetUsd（固定 1.09／0.80）、AutoLot、BalancePerBaseLot（手數不隨餘額縮放）
//        回測（修正後模擬器，帶起跑前歷史，144 情境）：爆倉 0（同 V1.74）；最差回撤 102,221→88,261；淨利中位數 240,501→260,198
// v1.74：新增「急速逆向凍結」—— 最近 VelWinMin(45) 分鐘內，價格往對鏈不利的方向走超過 VelUsd(60 美元）時，
//        該方向的鏈暫停加倉 VelHoldMin(45) 分鐘（止盈照常、不平倉）；凍結結束以現價重新定錨，錯過的層不補
//        針對 2/12、3/25、4/2 三次急跌急漲（全部是數十分鐘～數小時內單邊 $115～$181，之後都有大反彈）
//        修正後模擬器 144 情境：爆倉 16 → 0；分別調整回看 30～45 分鐘、門檻 50～60 美元、凍結 15～60 分鐘都 0 爆倉
//        其餘邏輯不動
// v1.73：1) 預設值改成回測用的設定：AutoLot=false（固定階梯手數）、ReopenCooldownSec=30
//        2) 內建新聞表新增 2027 年（非農、CPI、PPI 取自 BLS 官方日程；FOMC 取自聯準會公布日程），2027 起新聞過濾不再失效
//        3) 回撤統計排除入金／出金：偵測到入出金時，最高淨值同步加減該金額，出金不再被面板記成回撤
//        交易邏輯完全不變
// v1.72：新增「行情過熱暫停」—— 最近 RegimeHours(24) 小時（H1 K 棒，含當根）的最高最低價差超過 RegimeRangeUsd(180 美元）時，
//        多空兩邊都不開新鏈；已開的鏈照常補格、止盈（不是停損、不平倉）。依 Python 模擬器 48 種情境測試選定
//        面板狀態顯示 HOT，頁尾顯示目前區間；其餘邏輯不動
// v1.71：深層手數與格距（依 Python 回測模擬器 32 種情境穩健測試選定；爆倉情境 18/32 → 5/32）
//        1) 新增深層格距：第 DeepStepLayer(35) 層以後，每層格距改為 DeepStepUsd(3.00 美元)，同樣逆向幅度下層數與手數少很多
//        2) LotCap 預設改 0.50：單筆手數上限 0.50 手（原階梯表 L25 起 0.60～2.00 手）
//        3) 關閉 v1.70 兩項：DeepCatchLayer=0（放慢補格會讓均價跟不上，1/21 回測因此爆倉）、DeepTPLayer=0（主要是少賺）
//        其餘邏輯不動
// v1.70：深層風控兩項（4/21 事件：L21 時止盈價只差 $0.16 沒打到，之後 6 分鐘內從 L17 補到 L35，最終補到 L93）
//        1) 深層縮小止盈：鏈的最深層 ≥ DeepTPLayer 時，整籃止盈距離改為 DeepTPUsd（較小者），讓深鏈小反彈就出場
//        2) 深層放慢補格：下一層 ≥ DeepCatchLayer 時，每輪最多補 DeepMaxCatchUp 層（錯過的層不會跳過，只是放慢）
//        兩項設 0 即與 v1.69 完全相同；其餘邏輯不動
// v1.69：面板修正 —— 1) 錶盤大數字回撤金額大時會壓到弧線 → 字級 40→36、改置中，「/預算」移到下一行
//        2) 錶盤小字在大金額時超出弧線 → 字級 11→10   3) 帳戶三格浮動 ≥1 萬時改顯示整數，避免超出格子
//        4) 自動縮放時面板若超出圖表高度／寬度會自動縮小；圖表視窗改變大小時自動重畫   5) FontScale 上限改 1.15
//        交易邏輯完全不變
// v1.68：面板字體放大、重新排版：PanelScale=0 自動依螢幕 DPI 縮放（Windows 150% 縮放的螢幕不再字太小）、
//        新增 FontScale 字體倍率；所有文字字級加大約 30%，次要文字顏色調亮；面板加高、側軌加寬；交易邏輯完全不變
// v1.67：手動加倉按鍵從鏈卡片移出，改為面板右側「戰術側軌」兩條直立大按鍵（多／空各一），
//        顯示下一層手數、觸發價、距觸發距離、自動加倉冷卻狀態；階梯條格數改為自動（預算線後再多 6 格，52～80 格），
//        回撤預算 10 萬時預算線 L58 也看得到；交易邏輯完全不變
// v1.66：回撤預算 DDBudget 預設由 50,000 改為 100,000；面板版本字樣改為 v1.66；交易邏輯完全不變
// v1.65：面板改版為「C3 螢光綠 Terminal」科技風（CCanvas 點陣繪製）—— HUD 角框、網格＋掃描線背景、
//        分段式回撤預算錶盤（目前浮虧對照 DDBudget 絕對金額，標出當日最大回撤位置）、多空鏈層數階梯條（標出預算線層數）、
//        PanelTheme 可切換 C3／C1／C2 三種配色、PanelScale 縮放；手動加倉按鍵改畫在面板上；交易邏輯完全不變
// v1.64：面板新增手動加倉按鍵 —— 多鏈、空鏈卡片各一顆：有鏈時加下一層（手數照階梯表、註解 DCDY-補N），沒鏈時開首單；
//        預設跳出確認視窗；收網中、補格排隊中、EA 停機、已達 MaxLayers 時不動作；交易邏輯其餘完全不變
// v1.63：下單註解改為中文易讀格式 —— 首單「DCDY-首單」、第 N 次補單「DCDY-補N」（補1＝L1、補2＝L2…）；
//        仍可辨識舊版 DC_Lxx_x／SJL_Lxx_x 註解，升級時既有部位照常接管
// v1.62：1) 新聞公佈當下～公佈後 NewsFreezeAfterMin 分鐘：已在跑的鏈暫停加倉（止盈照常），結束後以現價重新定錨網格（錯過的層不補）
//        2) 內建 2025 年重大新聞表（2025 回測新聞過濾終於生效）
//        3) 兩個實驗開關（預設關＝與 v1.61 完全相同）：ATR 止盈 TPAtrMult、前幾層小格距 EarlyStepUsd/EarlyLayers
// v1.61：修正三個實盤 bug（2026.10.16 事件）
//        1) 伺服器 TP 逐張平倉的空檔，EA 看到殘單誤判鏈還活著並補 5 層 → 加「收網鎖」，TP 一成交就整鏈收掉、鎖住開單直到歸零
//        2) 首單 L0 不在時錨點退回「最早一單」，重開後格線錯位、不再加倉 → 改由最深層反推錨點
//        3) 重開後第一輪補格限 RestartMaxCatchUp 層，避免一開機就連補；可選擇把手動單（Magic=0）併入鏈
// v1.60：週五收盤前 4 小時不開新鏈；已有的鏈有獲利即提前出場，避免抱單過週末跳空
// v1.51：內建 2026 年重大新聞時間表（BLS／BEA／Fed／Census 官方日程），回測不需匯出
// v1.50：重大新聞過濾 —— 新聞前 2 小時起不開新鏈（已有的鏈跑完為止），新聞後 30 分鐘恢復
// v1.40：更名多財多億 V1；手數隨餘額縮放（預設每 25 萬餘額 = 1 倍）；混合式止盈；科技風面板；訂單註解 DC_
// v1.10：加入補格上限 MaxCatchUp=5（依 2026.03 原版 vs 重建版比對修正）
// v1.20：補格數量改為開輪時決定、排隊送出，中途不再看價格（修正急跌時多補層數）
#property strict

#include <Trade/Trade.mqh>
#include <Canvas/Canvas.mqh>   // v1.65 面板改用 CCanvas 繪製
#resource "\\Images\\DCDY_bg.bmp"   // v1.82 面板底圖：請把 DCDY_bg.bmp 放到 MQL5\Images\ 再編譯（會編進 EX5，之後不用附檔）
#define BG_RES "::Images\\DCDY_bg.bmp"

#define PFX "DCP1_"      // 面板物件前綴

//==================== 核心幾何 ====================
double       GridStepUsd       = 1.09;   // v1.75 固定（不再是輸入）：格距（美元），第L層 = 首單價 ∓ L×格距
double       ChainTargetUsd    = 0.80;   // v1.75 固定（不再是輸入）：整籃止盈＝加權均價 ± 此值
//==================== 屬性面板（只留這幾項，其餘參數已固定在程式內）====================
input group "【手數】"
input double BaseLot           = 0.01;   // 基礎手數（階梯表按 BaseLot/0.01 等比縮放；0.01＝每 15 萬本金）
input double LotCap            = 0.50;   // 單筆手數上限（0＝用階梯表上限 2.00×縮放）
input double TrendBoostFrontLot= 0.0;    // v1.88 順勢加碼鏈前 2 層固定手數（★10 萬帳戶請維持 0；15 萬以上帳戶可設 0.15）
input group "【虛擬層】"
input int    VirtualLayers     = 10;     // 一般鏈前 N 層只記帳不下單（0＝關閉；上限 30）
input int    HotVirtualLayers  = 5;      // v1.93 過熱寬格鏈專屬虛擬層數（-1＝沿用 VirtualLayers；上限 30）
input int    TBVirtualLayers   = 5;      // v1.93 順勢加碼鏈專屬虛擬層數（-1＝沿用 VirtualLayers；上限 30）
input group "【面板】"
input bool   ShowPanel         = true;   // 顯示面板
input int    PanelX            = 12;     // 面板左上角 X（像素）
input int    PanelY            = 28;     // 面板左上角 Y（像素）
input double PanelScale        = 0;      // 面板縮放：0＝自動依螢幕 DPI；手動可設 0.5～3.0
input bool   PanelGlow         = true;   // 面板柔光效果（關掉可省一點 CPU）
input double DDBudget          = 100000; // 回撤預算（帳戶貨幣）：錶盤滿格＝此金額
input group "【字體】"
input double FontScale         = 1.0;    // 字體再放大倍率（0.7～1.4）
input string PanelFontNum      = "";     // 數字／英文字型（空白＝Bahnschrift）
input string PanelFontTxt      = "";     // 中文字型（空白＝Microsoft JhengHei UI）
input string PanelFontSerif    = "";     // 大數字襯線字型（空白＝Times New Roman）
input group "【策略模式】"
input bool   EnableSafeMode    = true;   // true＝開啟安全模式（Regime2 11%寬格＋高點2.5%過濾＋順勢加碼）；false＝純 V1.85 模式
input double HotLotMul         = 4.0;    // v1.88 過熱寬格鏈每層手數倍數（格距 ×5 時；模擬器 3～5 都沒有新增爆倉，預設 4.0；2＝V1.84）
input double HotTPUsd          = 2.40;   // v1.93 過熱寬格鏈專屬整籃止盈距離（美元；高原 1.2～2.4 上緣；0＝沿用 0.80；只影響寬格鏈）
input double TBTPUsd           = 1.80;   // v1.93 順勢加碼鏈專屬整籃止盈距離（美元；僅在 ≤TBTPMaxL 層啟用；0＝沿用 0.80）
input int    TBTPMaxL          = 12;     // v1.93 順勢專屬止盈最高適用層數（超過此層自動退回 0.80 加速解套；0＝不限）
input bool   UseMidLadder      = true;   // v1.89 true＝中段手數加密（L11–L21 微幅加手，模擬器 1/5 空鏈不爆倉、2025 年淨利 +17%）；false＝原版階梯（＝v1.88）
const int    PairTrimLayer     = 0;      // v1.88 起固定關閉：配對減倉模擬器增益 ±1% 以內
input group "【整籃追蹤止盈（v1.90，預設關閉）】"
input double BasketTrailDist   = 0.0;    // 到原止盈價後的追蹤回撤距離（美元；0＝關閉＝與 v1.89 同；Gemini 建議 0.50）
input int    BasketTrailMinL   = 15;     // 鏈最深層 ≥ 此層才用追蹤止盈（淺鏈照原伺服器 TP）
input double BasketTrailFloor  = 0.65;   // 追蹤啟動後的保底鎖利距離（美元，均價 ± 此值）
input double BasketTrailSrvTPUsd = 15.0; // 追蹤鏈的伺服器 TP 放在原止盈價外多少美元（避免伺服器在原 TP 搶先平倉）
input bool   BasketTrailLockSL = true;   // 追蹤啟動後在伺服器端設保底鎖利價（斷線、跳價保護；高於均價，不是停損）
const double PairTrimMinUsd    = 0.0;    // 配對減倉最低合計淨利（PairTrimLayer=0 時不起作用）
input group "【冷卻節奏（10帳戶相位錯開用）】"
input int    AddCooldownSec    = 120;    // 第2層起每次加倉最少間隔（秒；多帳戶建議錯開 100/110/120/130/140）
input int    ReopenCooldownSec = 30;     // 一條鏈全平後重開冷卻（秒；多帳戶建議錯開 20/30/45/60/75）
input int    TrendReopenSec    = 3;      // v1.92 順勢極速重開：對面鏈已補到 TrendBoostLayer(L20) 以上時，這一邊止盈後的重開冷卻縮為此秒數（0＝關閉；需 EnableSafeMode）
input group "【高低點過濾】"
input bool   EdgeBlockLow      = false;  // true＝離 60 天低點 2.5% 內不開新多鏈；false＝放行多鏈（預設）。高點側過濾隨 EnableSafeMode 開啟
//==================== 以下參數已固定（不顯示在屬性面板）====================
//==================== 雙通道 ======================
const bool   EnableLong        = true;   // 開啟多單鏈
const bool   EnableShort       = true;   // 開啟空單鏈
//==================== 節奏 ========================
// ReopenCooldownSec / AddCooldownSec 已移至上方 input 區供多帳戶相位錯開與回測使用
const bool   L1NoCooldown      = true;   // 第1層不受冷卻限制（原版行為）
const int    MaxCatchUp        = 5;      // 冷卻後每輪最多連補幾層（原版=5，v1.0 漏掉此限制導致 3/3 爆倉）
//==================== 風控（原版無，0=關閉）======
const int    MaxLayers         = 0;      // 最大層數（0=不限，原版回測最深 53 層）
const double ChainStopLoss     = 0.0;    // 單鏈浮虧達此金額（帳戶貨幣）就整鏈砍倉
const double EquityStopPct     = 0.0;    // 權益回撤達餘額此%就全部平倉並停機
//==================== 系統 ========================
const long   Magic             = 20260911;
const int    SlippagePoints    = 30;
const bool   ResetMaxDD        = false;  // true＝重設歷史最大回撤紀錄
//==================== 止盈方式 ====================
const int    TPMode            = 2;      // 0=純虛擬  1=伺服器 TP（每次加倉都改，原版）  2=混合（伺服器 TP＋每分鐘限速，超過時虛擬保底）
const int    MaxModsPerMin     = 60;     // 混合模式：每分鐘最多改單次數（請依券商規定調整）
const double TPMinChangeUsd    = 0.0;    // TP 變動小於此值不改單（0＝與原版相同）
const bool   ShowTPLine        = true;   // 圖上畫出止盈線
//==================== 新聞過濾（v1.50）============
const bool   NewsFilter        = true;   // 重大新聞前後不開新鏈（已在跑的鏈照常運作直到止盈）
const int    NewsBeforeMin     = 120;    // 新聞前幾分鐘起不開新鏈
const int    NewsAfterMin      = 30;     // 新聞後幾分鐘恢復開新鏈
const int    NewsMinImportance = 3;      // MT5 日曆重要性：3=高（非農、CPI、FOMC…）；2=中以上（會擋掉很多時段）
const string NewsCurrencies    = "USD";  // 只看哪些幣別的新聞，逗號分隔
const string NewsKeywords      = "Nonfarm,Non-Farm,CPI,Consumer Price,FOMC,Interest Rate,Fed,Federal Funds,PCE,PPI,GDP,Unemployment,Jobless,Payroll,Retail Sales,ISM,Powell"; // 名稱含這些字的新聞一律視為重大（不論重要性）
const int    NewsSource        = 0;      // 0=內建 2025～2027 重大新聞表（回測、實盤皆可用）  1=內建＋實盤 MT5 日曆  2=讀檔（DC_ExportNews 匯出）
const int    NewsServerOffsetH = 7;      // 伺服器時間 = 美東時間 + 此小時數（Vantage = 7）
const string NewsFile          = "DC_news.csv"; // NewsSource=2 時讀取 Common\Files 下的此檔
//==================== 週五收盤保護（v1.60）========
const double FridayGateHours   = 4.0;    // 週五收盤前幾小時起不開新鏈（0=關）
const string FridayCloseTime   = "23:55";// 備用收盤時間（伺服器時間）；優先讀券商交易時段
const double FridayExitUsd     = 0.10;   // 窗口內已有的鏈：每手獲利達此距離即提前全平（0=不提前，照原 TP）
const bool   FridayStopAdds    = false;  // 窗口內是否停止加倉（預設否：V1 靠加倉拉回均價，停加反而更危險）
//==================== 接管與重啟（v1.61）==========
const bool   AdoptManual       = false;  // 把本商品的手動單（Magic=0）併入同方向的鏈：一起算均價、改 TP、整籃平倉
const int    RestartMaxCatchUp = 1;      // EA 重啟後，對既有的鏈第一輪最多補幾層（之後恢復 MaxCatchUp）
//==================== 新聞凍結加倉（v1.62）========
const bool   NewsFreezeAdds    = true;   // 新聞公佈當下起，已在跑的鏈暫停加倉（不平倉、止盈照常）
const int    NewsFreezeAfterMin= 30;     // 公佈後凍結幾分鐘（只從公佈當下開始，不提前；提前凍結回測會更糟）
const bool   NewsReanchor      = true;   // 凍結結束後以現價重新定錨網格：下一層 = 現價 ∓ 1 格，錯過的層不補
//==================== 實驗開關（v1.62，預設關）====
const double TPAtrMult         = 0.0;    // >0：整籃止盈距離 = max(ChainTargetUsd, M5 ATR(14)×此值)，每次加倉時決定（0=關，固定 0.80）
const double EarlyStepUsd      = 0.0;    // >0：前 EarlyLayers 層改用此格距（例如 0.80），之後恢復 GridStepUsd（0=關）
const int    EarlyLayers       = 10;     // EarlyStepUsd 適用的層數
//==================== 深層風控（v1.70）=============
const int    DeepTPLayer       = 0;      // 深層縮小止盈：鏈的最深層 ≥ 此層時改用 DeepTPUsd（0＝關閉；v1.71 預設關閉）
const double DeepTPUsd         = 0.40;   // 深層止盈距離（美元）：整籃 TP＝加權均價 ± 此值（與原止盈距離取較小者）
const int    DeepCatchLayer    = 0;      // 深層放慢補格：下一層 ≥ 此層時改用 DeepMaxCatchUp（0＝關閉；v1.71 預設關閉，回測證實有害）
const int    DeepMaxCatchUp    = 2;      // 深層每輪最多補幾層（原 MaxCatchUp=5）
//==================== 深層格距（v1.71）=============
const int    DeepStepLayer     = 35;     // 深層格距：第幾層之後改用 DeepStepUsd（0＝關閉，全部用 GridStepUsd）
const double DeepStepUsd       = 3.00;   // 深層格距（美元）：第 DeepStepLayer+1 層起每層的間距
//==================== 深層分批回收（v1.76）==========
const int    RecycleLayer      = 44;     // 鏈的最深層 ≥ 此層時啟動回收（0＝關閉＝與 v1.75 相同；回測安全區 L42～L45，L40 以下會失效）
const double RecycleUsd        = 2.0;    // 最深那張單超過自己的格線／成交價多少美元就單獨獲利平掉（回測 1～4 美元結果相近）
//==================== 行情過熱暫停（v1.72）=========
const int    RegimeHours       = 72;     // 回看幾小時的 H1 最高最低價（含當根；0＝關閉）（v1.75：24→72）
const double RegimeRangeUsd    = 400.0;  // 區間超過此金額（美元）就多空都不開新鏈；已開的鏈照常補格與止盈（v1.75：180→400）
//==================== 安全模式（v1.80）=============
const int    Regime2Hours      = 460;    // 長期波動過熱：回看幾根 H1 K 棒（460≈20 個交易日，含當根；0＝關閉）
double       Regime2Pct        = 11.0;  // v1.86：由 EnableSafeMode 於 OnInit 控制（true=11.0, false=0.0）
const int    EdgeHours         = 1380;   // 高低點過濾：回看幾根 H1 K 棒（1380≈60 個交易日，含當根；0＝關閉）
const double HotGridMul        = 5.0;    // v1.81 過熱寬格模式：長期波動過熱時新鏈的格距倍數（1 以下＝關閉，過熱時不開新鏈；回測安全區 4～6，3 以下會爆倉）
// HotLotMul 已移至上方 input 區（v1.87 預設 4.0）
//==================== 順勢加碼（v1.82）=============
int          TrendBoostLayer   = 20;    // v1.86：由 EnableSafeMode 於 OnInit 控制（true=20, false=0）
const double TrendBoostLotMul  = 4.0;    // v1.82 順勢鏈前段每層手數的倍數（回測 3～5 都沒有新增爆倉；越大越賺、回撤越大）
const int    TrendBoostMaxLayer= 10;     // v1.82 只放大第 0 層到第 N−1 層（含虛擬層），第 N 層起回到原手數（0＝整條鏈都放大，回測會爆倉，請勿用）
const int    TrendBoostFrontLayers = 2;     // v1.83 上面的固定手數用在第 0 層到第 N−1 層（回測 2～3 安全，5 會爆倉）
const double TrendBoostNearUsd = 3.0;    // v1.82 開鏈當下現價離對面鏈最深那張單的成交價不超過幾美元才加碼（趨勢已回頭就不加碼；0＝不檢查，回測回撤會到 10 萬；1～5 結果相近）
double       EdgePct           = 2.5;   // v1.86：由 EnableSafeMode 於 OnInit 控制（true=2.5, false=0.0）
//==================== 急速逆向凍結（v1.74）=========
const int    VelWinMin         = 45;     // 回看幾分鐘的價格變化（0＝關閉）
const double VelUsd            = 60.0;   // 回看期間往對鏈不利方向走超過幾美元，就暫停該方向加倉（回測安全區 50～60；70 起開始失效）
const int    VelHoldMin        = 45;     // 最後一次觸發後再凍結幾分鐘（止盈照常、不平倉）
const bool   VelReanchor       = true;   // 凍結結束以現價重新定錨：下一層＝現價 ∓ 1 格，錯過的層不補
const int    Vel2WinMin        = 240;    // v1.75 慢速逆向：回看幾分鐘（0＝關閉）
const double Vel2Usd           = 100.0;  // v1.75 慢速逆向：回看期間逆向超過幾美元也凍結加倉（凍結時間同 VelHoldMin）
//==================== 面板外觀（v1.77）=============

CTrade trade;

// 原版回測觀察到的手數階梯（BaseLot=0.01 時），第 39 層起固定 2.00
double LadderTbl[] = {
   0.01,0.01,0.01,0.01,0.01,             // L0-L4
   0.02,0.02,0.02,0.02,0.02,0.02,        // L5-L10
   0.05,0.05,0.06,0.06,0.08,             // L11-L15
   0.12,0.15,0.18,0.20,0.23,0.23,        // L16-L21
   0.40,0.40,0.50,0.60,0.70,0.80,        // L22-L27
   1.00,1.10,1.20,1.20,1.30,1.50,        // L28-L33
   1.60,1.70,1.80,1.90,1.90              // L34-L38
};
// v1.86 A1-Med 中段手數密度階梯（僅微調 L11–L21，L24+ 仍受 LotCap=0.50 限制）
double LadderTblMid[] = {
   0.01,0.01,0.01,0.01,0.01,             // L0-L4
   0.02,0.02,0.02,0.02,0.02,0.02,        // L5-L10
   0.06,0.07,0.09,0.11,0.14,             // L11-L15 (A1-Med)
   0.18,0.22,0.25,0.28,0.30,0.32,        // L16-L21 (A1-Med)
   0.40,0.40,0.50,0.60,0.70,0.80,        // L22-L27
   1.00,1.10,1.20,1.20,1.30,1.50,        // L28-L33
   1.60,1.70,1.80,1.90,1.90              // L34-L38
};
const double LADDER_TAIL = 2.00;
datetime g_lastTickT = 0;                 // v1.86 偵測休市重開/跳空用

datetime g_lastClose[2] = {0,0};   // 0=多 1=空
datetime g_lastAdd[2]   = {0,0};   // 最後一次實際加倉（冷卻計時基準）
int      g_pending[2]   = {0,0};           // 本輪尚待送出的補格單數
int      g_prevCount[2] = {0,0};
bool     g_halted       = false;
double   g_tpPx[2]      = {0,0};          // 目前整籃 TP 價
bool     g_tpDeferred[2]= {false,false};  // 伺服器 TP 暫緩更新中
bool     g_trOn[2]      = {false,false};  // v1.90 整籃追蹤止盈已啟動（價格已越過原 TP）
double   g_trPk[2]      = {0,0};          // v1.90 追蹤啟動後的最佳極值價
bool     g_closing[2]   = {false,false};  // v1.61 收網中：TP 已成交，整鏈平完前不開單、不改 TP
bool     g_resume[2]    = {false,false};  // v1.61 重啟後第一輪補格受 RestartMaxCatchUp 限制
uint     g_closeTry[2]  = {0,0};          // v1.61 收網時上次送平倉的時間（毫秒）
bool     g_frozen[2]    = {false,false};  // v1.62 新聞凍結中
bool     g_frozenVel[2] = {false,false};  // v1.74 本次凍結是否由急速逆向觸發
datetime g_velTrig[2]   = {0,0};          // v1.74 最後一次觸發急速逆向的時間
// v1.74 價格紀錄（每秒最多一筆），用來取得 VelWinMin 分鐘前的價格
datetime g_vT[];
double   g_vP[];
int      g_vStart=0;
datetime g_vInitT=0;
double   g_anchorOv[2]  = {0,0};          // v1.62 重新定錨後的錨點（0=用原錨點）
double   g_tpDist[2]    = {0,0};          // v1.62 這條鏈目前的止盈距離
int      g_atrH         = INVALID_HANDLE;
string   AnchorKey(int side,string k){ return StringFormat("DC1_%I64d_%I64d_ra%d_%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,side,k); }
datetime EarliestOpen(int side);
// v1.62 重新定錨存到終端全域變數，EA 重啟後同一條鏈仍沿用（避免重啟後回頭補錯過的層）
void AnchorSave(int side)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_anchorOv[side]>0){ GlobalVariableSet(AnchorKey(side,"px"),g_anchorOv[side]); GlobalVariableSet(AnchorKey(side,"t"),(double)EarliestOpen(side)); }
   else { GlobalVariableDel(AnchorKey(side,"px")); GlobalVariableDel(AnchorKey(side,"t")); }
}
void AnchorLoad(int side)
{
   g_anchorOv[side]=0;
   if(MQLInfoInteger(MQL_TESTER) || !GlobalVariableCheck(AnchorKey(side,"px"))) return;
   datetime eo=EarliestOpen(side), st=(datetime)GlobalVariableGet(AnchorKey(side,"t"));
   if(CountSide(side)>0 && eo>0 && eo>=st)
      g_anchorOv[side]=GlobalVariableGet(AnchorKey(side,"px"));
   else AnchorSave(side);
}
// v1.86 盲點修補1：凍結狀態與急速逆向觸發時間持久化，重啟不遺忘凍結與重定錨
datetime g_fzSaved[2]={0,0};              // v1.88 急速逆向期間凍結狀態最近一次寫入時間（節流）
string FreezeKey(int side,string k){ return StringFormat("DC1_%I64d_%I64d_fz%d_%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,side,k); }
void FreezeSave(int side)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_frozen[side] || g_velTrig[side]>0)
   {
      GlobalVariableSet(FreezeKey(side,"on"),g_frozen[side]?1.0:0.0);
      GlobalVariableSet(FreezeKey(side,"vel"),g_frozenVel[side]?1.0:0.0);
      GlobalVariableSet(FreezeKey(side,"vt"),(double)g_velTrig[side]);
      GlobalVariableSet(FreezeKey(side,"t"),(double)EarliestOpen(side));
   }
   else
   {
      GlobalVariableDel(FreezeKey(side,"on")); GlobalVariableDel(FreezeKey(side,"vel"));
      GlobalVariableDel(FreezeKey(side,"vt")); GlobalVariableDel(FreezeKey(side,"t"));
   }
}
void FreezeLoad(int side)
{
   g_frozen[side]=false; g_frozenVel[side]=false; g_velTrig[side]=0;
   if(MQLInfoInteger(MQL_TESTER) || !GlobalVariableCheck(FreezeKey(side,"on"))) return;
   datetime eo=EarliestOpen(side), st=(datetime)GlobalVariableGet(FreezeKey(side,"t"));
   if(CountSide(side)>0 && eo>0 && (st==0 || eo>=st))
   {
      g_frozen[side]=(st>0 && GlobalVariableGet(FreezeKey(side,"on"))>0.5);   // v1.88 t=0（只有虛擬層時記錄）不接回凍結旗標
      g_frozenVel[side]=(g_frozen[side] && GlobalVariableGet(FreezeKey(side,"vel"))>0.5);
      g_velTrig[side]=(datetime)GlobalVariableGet(FreezeKey(side,"vt"));
      if(g_frozen[side] || g_velTrig[side]>0)
         PrintFormat("接回凍結狀態 side=%d：frozen=%d vel=%d trig=%s",side,(int)g_frozen[side],(int)g_frozenVel[side],TimeToString(g_velTrig[side]));
   }
   else FreezeSave(side);
}

//+------------------------------------------------------------------+
// v1.81 過熱寬格模式：開鏈時決定這條鏈的格距倍數與手數倍數，存到終端全域變數（EA 重啟後同一條鏈沿用）
double   g_hotMul[2]    = {1.0,1.0};      // 這條鏈的格距倍數（1＝一般）
double   g_hotLot[2]    = {1.0,1.0};      // 這條鏈的手數倍數（1＝一般）
double   g_tbLot[2]     = {1.0,1.0};      // v1.82 順勢加碼：這條鏈前段手數倍數（1＝一般）
string   HotKey(int side,string k){ return StringFormat("DC1_%I64d_%I64d_hm%d_%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,side,k); }
bool     HotModeOn(){ return HotGridMul>1.0; }
void HotSave(int side)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_hotMul[side]!=1.0 || g_hotLot[side]!=1.0 || g_tbLot[side]!=1.0)
   {
      GlobalVariableSet(HotKey(side,"m"),g_hotMul[side]);
      GlobalVariableSet(HotKey(side,"l"),g_hotLot[side]);
      GlobalVariableSet(HotKey(side,"t"),g_tbLot[side]);     // v1.82
      GlobalVariableSet(HotKey(side,"ts"),(double)TimeCurrent()); // v1.86 盲點修補2：開鏈時間戳
   }
   else { GlobalVariableDel(HotKey(side,"m")); GlobalVariableDel(HotKey(side,"l")); GlobalVariableDel(HotKey(side,"t")); GlobalVariableDel(HotKey(side,"ts")); }
}
void HotReset(int side)
{
   bool was=(g_hotMul[side]!=1.0 || g_hotLot[side]!=1.0 || g_tbLot[side]!=1.0);
   g_hotMul[side]=1.0; g_hotLot[side]=1.0; g_tbLot[side]=1.0;
   if(was) HotSave(side);
}

//+------------------------------------------------------------------+
// v1.78 虛擬層：前 VirtualLayers 層只記帳、不下單
bool     g_vlOn[2]      = {false,false};  // 這條鏈有虛擬層
double   g_vlAnchor[2]  = {0,0};          // 虛擬首單價格（鏈的錨點）
int      g_vlN[2]       = {0,0};          // 已記帳的虛擬層數（下一層 = g_vlN）
double   g_vlLots[2]    = {0,0};          // 虛擬層手數合計
double   g_vlPV[2]      = {0,0};          // 虛擬層 手數×價格 合計
datetime g_vlTime[2]    = {0,0};          // 虛擬首單時間
int      g_vk           = 0;              // 一般鏈實際使用的虛擬層數（VirtualLayers 限制在 0～30）
int SideVK(int side)                      // v1.93 依鏈類型（一般／順勢／寬格）回傳實際虛擬層數
{
   int vk=g_vk;
   if(g_tbLot[side]!=1.0 && TBVirtualLayers>=0)  vk=MathMin(30,TBVirtualLayers);
   if(g_hotMul[side]>1.0 && HotVirtualLayers>=0) vk=MathMin(30,HotVirtualLayers);
   return MathMax(0,vk);
}
string   VirtKey(int side,string k){ return StringFormat("DC1_%I64d_%I64d_vl%d_%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,side,k); }
void VirtSave(int side)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(g_vlOn[side])
   {
      GlobalVariableSet(VirtKey(side,"n"),(double)g_vlN[side]);
      GlobalVariableSet(VirtKey(side,"px"),g_vlAnchor[side]);
      GlobalVariableSet(VirtKey(side,"lots"),g_vlLots[side]);
      GlobalVariableSet(VirtKey(side,"pv"),g_vlPV[side]);
      GlobalVariableSet(VirtKey(side,"t"),(double)g_vlTime[side]);
   }
   else
   {
      GlobalVariableDel(VirtKey(side,"n")); GlobalVariableDel(VirtKey(side,"px")); GlobalVariableDel(VirtKey(side,"lots"));
      GlobalVariableDel(VirtKey(side,"pv")); GlobalVariableDel(VirtKey(side,"t"));
   }
}
void VirtReset(int side)
{
   bool was=g_vlOn[side];
   g_vlOn[side]=false; g_vlAnchor[side]=0; g_vlN[side]=0; g_vlLots[side]=0; g_vlPV[side]=0; g_vlTime[side]=0;
   if(was) VirtSave(side);
}
// EA 啟動：有真實單、且都是在虛擬首單之後開的 → 接回虛擬層；否則作廢
void VirtLoad(int side)
{
   g_vlOn[side]=false; g_vlAnchor[side]=0; g_vlN[side]=0; g_vlLots[side]=0; g_vlPV[side]=0; g_vlTime[side]=0;
   if(MQLInfoInteger(MQL_TESTER) || !GlobalVariableCheck(VirtKey(side,"n"))) return;
   int      n  = (int)GlobalVariableGet(VirtKey(side,"n"));
   double   an = GlobalVariableGet(VirtKey(side,"px"));
   double   lt = GlobalVariableGet(VirtKey(side,"lots"));
   double   pv = GlobalVariableGet(VirtKey(side,"pv"));
   datetime t0 = (datetime)GlobalVariableGet(VirtKey(side,"t"));
   datetime eo = EarliestOpen(side);
   if(n>0 && an>0 && lt>0 && pv>0 && t0>0 && CountSide(side)>0 && eo>=t0)
   {
      g_vlOn[side]=true; g_vlAnchor[side]=an; g_vlN[side]=n; g_vlLots[side]=lt; g_vlPV[side]=pv; g_vlTime[side]=t0;
      PrintFormat("接回虛擬層 side=%d：%d 層 %.2f 手 錨點 %.2f 均價 %.2f",side,n,lt,an,pv/lt);
   }
   else
   {
      g_vlOn[side]=true; VirtReset(side);                       // 清掉終端全域變數
      PrintFormat("虛擬層作廢 side=%d（沒有對應的真實單），之後重新起算",side);
   }
}
// 只有虛擬層時的鏈狀態
void VirtState(int side,int &maxL,double &anchor,double &avg)
{
   maxL=g_vlN[side]-1; if(maxL<0) maxL=0;
   anchor=(g_anchorOv[side]>0) ? g_anchorOv[side] : g_vlAnchor[side];
   avg=(g_vlLots[side]>0) ? g_vlPV[side]/g_vlLots[side] : g_vlAnchor[side];
}

//+------------------------------------------------------------------+
// v1.62 網格幾何：第 L 層距錨點的距離（支援前幾層小格距）
double LevelOff(int L)
{
   if(L<=0) return 0;
   // v1.71 深層格距：第 DeepStepLayer 層之後每層改用 DeepStepUsd
   if(DeepStepLayer>0 && DeepStepUsd>0 && L>DeepStepLayer)
      return LevelOff(DeepStepLayer) + (L-DeepStepLayer)*DeepStepUsd;
   if(EarlyStepUsd<=0 || EarlyLayers<=0) return L*GridStepUsd;
   if(L<=EarlyLayers) return L*EarlyStepUsd;
   return EarlyLayers*EarlyStepUsd + (L-EarlyLayers)*GridStepUsd;
}
double StepOf(int L){ return LevelOff(L)-LevelOff(L-1); }
// 距錨點 dist 美元時，已越過的最深層
int LevelsWithin(double dist)
{
   if(dist<=0) return 0;
   int L=0;
   while(L<2000 && LevelOff(L+1)<=dist+1e-9) L++;
   return L;
}
// v1.62 止盈距離：固定 ChainTargetUsd，或 ATR 倍數（取較大者）
double CalcTPDist()
{
   if(TPAtrMult<=0 || g_atrH==INVALID_HANDLE) return ChainTargetUsd;
   double b[]; if(CopyBuffer(g_atrH,0,1,1,b)<1) return ChainTargetUsd;
   double d=MathMax(ChainTargetUsd,b[0]*TPAtrMult);
   return NormalizeDouble(MathRound(d*20)/20.0,2);          // 0.05 美元一級，減少改單
}
double TPDist(int side,int maxL=-1)
{
   if(g_tpDist[side]<=0) g_tpDist[side]=CalcTPDist();
   double d=g_tpDist[side];
   if(g_hotMul[side]>1.0 && HotTPUsd>0) d=HotTPUsd;                               // v1.93 寬格鏈專屬止盈距離（預設 2.40）
   else if(g_tbLot[side]!=1.0 && TBTPUsd>0 && (TBTPMaxL<=0 || maxL<0 || maxL<=TBTPMaxL)) d=TBTPUsd; // v1.93 淺層保護順勢專屬止盈
   if(DeepTPLayer>0 && DeepTPUsd>0 && maxL>=DeepTPLayer) d=MathMin(d,DeepTPUsd);   // v1.70 深層縮小止盈
   return d;
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("警告：帳戶不是對沖模式，雙向鏈無法同時持倉。");
   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   if(TPAtrMult>0) g_atrH=iATR(_Symbol,PERIOD_M5,14);
   Regime2Pct      = EnableSafeMode ? 11.0 : 0.0;               // v1.86
   EdgePct         = EnableSafeMode ? 2.5  : 0.0;               // v1.86
   TrendBoostLayer = EnableSafeMode ? 20   : 0;                 // v1.86
   g_vk=(int)MathMax(0,MathMin(30,VirtualLayers));              // v1.78
   g_lastTickT=0;
   for(int s=0;s<2;s++)
   {
      g_prevCount[s]=CountSide(s); g_lastAdd[s]=LatestOpenTime(s);
      g_closing[s]=false; g_pending[s]=0; g_trOn[s]=false; g_trPk[s]=0;
      g_resume[s]=(g_prevCount[s]>0);
      AnchorLoad(s);                                         // v1.62
      FreezeLoad(s);                                         // v1.86
      VirtLoad(s);                                           // v1.78
      HotLoad(s);                                            // v1.81
      if(g_prevCount[s]>0)
      {
         int mL; double an,av,lt,pl;
         if(ChainState(s,mL,an,av,lt,pl))
            PrintFormat("接管既有%s鏈：%d 張 最深 L%d 總手數 %.2f 均價 %.2f 錨點 %.2f 下一層觸發 %.2f（首輪最多補 %d 層）",
                        s==0?"多":"空",g_prevCount[s],mL,lt,av,an,
                        s==0?an-LevelOffS(s,mL+1):an+LevelOffS(s,mL+1),RestartMaxCatchUp);
      }
   }
   DDInit();
   NewsLoad(true);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ if(g_atrH!=INVALID_HANDLE) IndicatorRelease(g_atrH); Comment(""); PanelDestroy(); ObjectsDeleteAll(0,PFX); ObjectDelete(0,"DC1_TP_BUY"); ObjectDelete(0,"DC1_TP_SELL"); DDSave(); }

//+------------------------------------------------------------------+
// v1.75 手數不再隨餘額縮放，固定 1 倍（保留函式供面板顯示）
double LotScale()
{
   return 1.0;
}

double LotForLayer(int L)
{
   double raw = LADDER_TAIL;
   if(UseMidLadder && L < ArraySize(LadderTblMid)) raw = LadderTblMid[L];
   else if(L < ArraySize(LadderTbl))               raw = LadderTbl[L];
   raw *= BaseLot/0.01 * LotScale();
   if(LotCap>0) raw = MathMin(raw, LotCap);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   raw = MathFloor(raw/step+1e-9)*step;
   return NormalizeDouble(MathMax(vmin,MathMin(vmax,raw)),2);
}

// v1.81 依這條鏈的倍數計算：格距、越過層數、每層手數
double LevelOffS(int side,int L){ return LevelOff(L)*g_hotMul[side]; }
int    LevelsWithinS(int side,double dist){ return LevelsWithin(dist/g_hotMul[side]); }
// v1.83 這條鏈是順勢加碼鏈、且前段用實單固定手數（不用虛擬層）
bool TBReal(int side){ return (g_tbLot[side]!=1.0 && TrendBoostFrontLot>0 && TrendBoostFrontLayers>0); }
double LotForLayerS(int side,int L)
{
   if(TBReal(side) && !g_vlOn[side] && L<TrendBoostFrontLayers)   // v1.83 順勢加碼鏈前段：固定手數
   {
      double fs=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      double fmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
      double fmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
      if(fs<=0) fs=0.01;
      double fr=TrendBoostFrontLot*BaseLot/0.01;
      if(LotCap>0) fr=MathMin(fr,LotCap);
      fr=MathFloor(fr/fs+1e-9)*fs;
      return NormalizeDouble(MathMax(fmin,MathMin(fmax,fr)),2);
   }
   double lot=LotForLayer(L);
   double mul=g_hotLot[side];
   if(g_tbLot[side]!=1.0 && (TrendBoostMaxLayer<=0 || L<TrendBoostMaxLayer)) mul*=g_tbLot[side];   // v1.82 順勢加碼只放大前段
   if(mul==1.0) return lot;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   double raw=MathFloor(lot*mul/step+1e-9)*step;
   return NormalizeDouble(MathMax(vmin,MathMin(vmax,raw)),2);
}
// EA 啟動：這一邊還有持倉、且存有倍數 → 接回；否則清掉
void HotLoad(int side)
{
   g_hotMul[side]=1.0; g_hotLot[side]=1.0; g_tbLot[side]=1.0;
   if(MQLInfoInteger(MQL_TESTER) || !GlobalVariableCheck(HotKey(side,"m"))) return;
   double m=GlobalVariableGet(HotKey(side,"m"));
   double l=GlobalVariableCheck(HotKey(side,"l")) ? GlobalVariableGet(HotKey(side,"l")) : 1.0;
   double tb=GlobalVariableCheck(HotKey(side,"t")) ? GlobalVariableGet(HotKey(side,"t")) : 1.0;   // v1.82
   datetime ts=GlobalVariableCheck(HotKey(side,"ts")) ? (datetime)GlobalVariableGet(HotKey(side,"ts")) : 0;
   datetime eo=EarliestOpen(side);
   bool timeOk=(ts==0 || (eo>0 && eo>=ts-60));
   bool alive=(CountSide(side)>0 && timeOk) || (CountSide(side)==0 && g_vlOn[side]); // v1.93 修補虛擬層階段重啟接回
   if(alive && m>=1.0 && m<=50.0 && l>0 && l<=20.0 && tb>0 && tb<=20.0)
   {
      g_hotMul[side]=m; g_hotLot[side]=l; g_tbLot[side]=tb;
      PrintFormat("接回鏈倍數 side=%d：格距 ×%.2f 手數 ×%.2f 順勢加碼 ×%.2f",side,m,l,tb);
   }
   else { GlobalVariableDel(HotKey(side,"m")); GlobalVariableDel(HotKey(side,"l")); GlobalVariableDel(HotKey(side,"t")); GlobalVariableDel(HotKey(side,"ts")); }
}

// v1.63 下單註解：首單 = DCDY-首單，第 N 層補單 = DCDY-補N（方向由買／賣單本身區分）
string Tag(int L,int side){ return (L<=0) ? "DCDY-首單" : StringFormat("DCDY-補%d",L); }

int LayerFromComment(string c)
{
   // v1.63 新格式：DCDY-首單 / DCDY-補N
   //   只認 ASCII 的「DCDY-」前綴＋後面的數字：有數字 = 第 N 層，沒有數字 = 首單。
   //   即使券商把中文存成亂碼（例如 DCDY-?? 或 DCDY-?2），層數仍能正確判讀。
   int q=StringFind(c,"DCDY-");
   if(q>=0)
   {
      int n=StringLen(c), st=q+5;
      while(st<n && (StringGetCharacter(c,st)<'0' || StringGetCharacter(c,st)>'9')) st++;
      if(st>=n) return 0;                                   // 沒有數字 → 首單
      int e=st;
      while(e<n && StringGetCharacter(c,e)>='0' && StringGetCharacter(c,e)<='9') e++;
      return (int)StringToInteger(StringSubstr(c,st,e-st));
   }
   // 舊格式（v1.62 以前的 DC_Lxx_x、雙截龍 SJL_Lxx_x）
   int k=4;
   int p=StringFind(c,"DC_L");
   if(p<0){ p=StringFind(c,"SJL_L"); k=5; }   // 相容舊版 SJL 單
   if(p<0) return -1;
   int u=StringFind(c,"_",p+k);  if(u<0) return -1;
   return (int)StringToInteger(StringSubstr(c,p+k,u-(p+k)));
}

bool IsMine(ulong ticket,int side)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol) return false;
   long mg=PositionGetInteger(POSITION_MAGIC);
   if(mg!=Magic && !(AdoptManual && mg==0)) return false;
   long t=PositionGetInteger(POSITION_TYPE);
   return (side==0 && t==POSITION_TYPE_BUY) || (side==1 && t==POSITION_TYPE_SELL);
}

int CountSide(int side)
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--) if(IsMine(PositionGetTicket(i),side)) n++;
   return n;
}

datetime EarliestOpen(int side)
{
   datetime t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(IsMine(PositionGetTicket(i),side)){ datetime o=(datetime)PositionGetInteger(POSITION_TIME); if(t==0 || o<t) t=o; }
   return t;
}

datetime LatestOpenTime(int side)
{
   datetime t=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(IsMine(PositionGetTicket(i),side)) t=MathMax(t,(datetime)PositionGetInteger(POSITION_TIME));
   return t;
}

// v1.61 手動單沒有 DCDY／DC_Lxx 註解：依手數在階梯表中找「比目前最深層更深」的第一個相符層
int InferLayer(double vol,int after)
{
   int n=ArraySize(LadderTbl);
   for(int L=MathMax(0,after+1);L<n;L++)
      if(MathAbs(LotForLayer(L)-vol)<1e-6) return L;
   return after+1;
}

// 讀取一條鏈的狀態：最深層、首單錨點、加權均價、總手數、浮動盈虧
// v1.61：L0 不在時，錨點由最深層反推（錨點 = 最深層開倉價 ± 層數×格距），
//        讓下一層觸發價 = 最深層價 ∓ 1 格，重啟或首單被平後格線不再錯位
bool ChainState(int side,int &maxL,double &anchor,double &avg,double &lots,double &pnl)
{
   maxL=-1; anchor=0; avg=0; lots=0; pnl=0;
   double pv=0, deepPx=0;
   double manV[], manP[]; int nm=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!IsMine(tk,side)) continue;
      double v=PositionGetDouble(POSITION_VOLUME), p=PositionGetDouble(POSITION_PRICE_OPEN);
      int L=LayerFromComment(PositionGetString(POSITION_COMMENT));
      if(L==0) anchor=p;
      if(L<0)
      {
         ArrayResize(manV,nm+1); ArrayResize(manP,nm+1);
         manV[nm]=v; manP[nm]=p; nm++;
      }
      else if(L>maxL || (L==maxL && ((side==0 && p<deepPx) || (side==1 && p>deepPx)))){ maxL=L; deepPx=p; }
      lots+=v; pv+=v*p;
      pnl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   if(lots<=0) return false;
   // 手動單（依開倉價由淺到深）接在最深層後面
   for(int a=0;a<nm;a++)
   {
      int b=a;
      for(int j=a+1;j<nm;j++) if((side==0 && manP[j]>manP[b]) || (side==1 && manP[j]<manP[b])) b=j;
      if(b!=a){ double tv=manV[a]; manV[a]=manV[b]; manV[b]=tv; double tp=manP[a]; manP[a]=manP[b]; manP[b]=tp; }
      int L=InferLayer(manV[a],maxL);
      maxL=L; deepPx=manP[a];
   }
   if(maxL<0) maxL=0;
   if(anchor==0) anchor = (side==0) ? deepPx + LevelOffS(side,maxL) : deepPx - LevelOffS(side,maxL);
   if(g_vlOn[side])                                          // v1.78 虛擬層：錨點＝虛擬首單價；均價把虛擬層算進去（止盈價位與全部下單時相同）
   {
      anchor=g_vlAnchor[side];
      if(g_vlN[side]-1>maxL) maxL=g_vlN[side]-1;
   }
   if(g_anchorOv[side]>0) anchor=g_anchorOv[side];           // v1.62 新聞後重新定錨
   avg = g_vlOn[side] ? (pv+g_vlPV[side])/(lots+g_vlLots[side]) : pv/lots;
   return true;
}

// v1.61 最近 120 秒內，這一方向是否有被伺服器 TP 平掉的單
bool RecentTPExit(int side)
{
   datetime now=TimeCurrent();
   if(!HistorySelect(now-120,now+60)) return false;
   for(int i=HistoryDealsTotal()-1;i>=0;i--)
   {
      ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      long mg=HistoryDealGetInteger(d,DEAL_MAGIC);
      if(mg!=Magic && !(AdoptManual && mg==0)) continue;
      if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
      if(HistoryDealGetInteger(d,DEAL_REASON)!=DEAL_REASON_TP) continue;
      long dt=HistoryDealGetInteger(d,DEAL_TYPE);
      // 平多單的成交是 SELL，平空單的成交是 BUY
      if((side==0 && dt==DEAL_TYPE_SELL) || (side==1 && dt==DEAL_TYPE_BUY)) return true;
   }
   return false;
}

// v1.61 進入收網：清掉補格排隊，市價收掉殘單（伺服器正在平的單會回報不存在，無妨）
void BeginClosing(int side,string why)
{
   if(!g_closing[side])
      PrintFormat("收網開始 side=%d 原因=%s 剩餘 %d 張，平完前暫停開單與改 TP",side,why,CountSide(side));
   g_closing[side]=true;
   g_pending[side]=0;
}

void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(tr.deal)) return;
   if(HistoryDealGetString(tr.deal,DEAL_SYMBOL)!=_Symbol) return;
   long mg=HistoryDealGetInteger(tr.deal,DEAL_MAGIC);
   if(mg!=Magic && !(AdoptManual && mg==0)) return;
   if(HistoryDealGetInteger(tr.deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) return;
   if(HistoryDealGetInteger(tr.deal,DEAL_REASON)!=DEAL_REASON_TP) return;
   long dt=HistoryDealGetInteger(tr.deal,DEAL_TYPE);
   if(dt==DEAL_TYPE_SELL) BeginClosing(0,"伺服器TP成交");
   if(dt==DEAL_TYPE_BUY)  BeginClosing(1,"伺服器TP成交");
}

// v1.86 盲點修補3：市場與交易權限檢查，避免休市/停盤空燒改單額度與洗日誌
bool MarketTradeable(bool closeOnly=false)
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   }
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(mode==SYMBOL_TRADE_MODE_DISABLED) return false;
   if(!closeOnly && mode==SYMBOL_TRADE_MODE_CLOSEONLY) return false;
   return true;
}
void CloseSide(int side)
{
   if(!MarketTradeable(true)) return;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(IsMine(tk,side)) trade.PositionClose(tk);
   }
}

// v1.90 追蹤止盈：伺服器端是否已有保底鎖利價（重啟時用來接回追蹤狀態）
bool HasLockSL(int side)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(IsMine(tk,side) && PositionGetDouble(POSITION_SL)>0) return true;
   }
   return false;
}

// 把整條鏈所有單的 TP 設成 均價 ± 目標
void SyncTP(int side)
{
   if(g_closing[side]) return;              // v1.61 收網中不改 TP（避免 close to market 失敗）
   int maxL; double anchor,avg,lots,pnl;
   if(!ChainState(side,maxL,anchor,avg,lots,pnl)) return;
   double tp = (side==0) ? avg+TPDist(side,maxL) : avg-TPDist(side,maxL);
   tp=NormalizeDouble(tp,_Digits);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   g_tpPx[side]=tp;

   // v1.90 整籃追蹤止盈（BasketTrailDist>0 且最深層 ≥ BasketTrailMinL 才啟用）
   bool useTrail = (BasketTrailDist>0 && maxL>=BasketTrailMinL);
   double lockPx = NormalizeDouble((side==0) ? avg+BasketTrailFloor : avg-BasketTrailFloor, _Digits);
   if(useTrail)
   {
      if(!g_trOn[side] && BasketTrailLockSL && HasLockSL(side))      // 重啟：伺服器上有鎖利價 → 接回追蹤
      { g_trOn[side]=true; g_trPk[side]=(side==0)?bid:ask; PrintFormat("接回追蹤止盈 side=%d L%d",side,maxL); }
      if(!g_trOn[side] && ((side==0 && bid>=tp) || (side==1 && ask<=tp)))
      {
         g_trOn[side]=true; g_trPk[side]=(side==0)?bid:ask;
         PrintFormat("追蹤止盈啟動 side=%d L%d 均價 %.2f 啟動價 %.2f 回撤 %.2f 保底 %.2f",side,maxL,avg,g_trPk[side],BasketTrailDist,BasketTrailFloor);
      }
      if(g_trOn[side])
      {
         double stopPx;
         if(side==0){ if(bid>g_trPk[side]) g_trPk[side]=bid; stopPx=NormalizeDouble(MathMax(lockPx,g_trPk[side]-BasketTrailDist),_Digits); }
         else       { if(ask<g_trPk[side]) g_trPk[side]=ask; stopPx=NormalizeDouble(MathMin(lockPx,g_trPk[side]+BasketTrailDist),_Digits); }
         DrawTPLine(side,stopPx);
         if((side==0 && bid<=stopPx) || (side==1 && ask>=stopPx)){ BeginClosing(side,"追蹤止盈平倉"); CloseSide(side); DrawTPLine(side,0); return; }
      }
      else DrawTPLine(side,tp);
   }
   else
   {
      g_trOn[side]=false; g_trPk[side]=0;
      DrawTPLine(side,tp);
      // 價格已越過目標 → 直接市價全平（虛擬 TP／保底）
      if((side==0 && bid>=tp) || (side==1 && ask<=tp)){ BeginClosing(side,"虛擬TP到價"); CloseSide(side); DrawTPLine(side,0); return; }
   }
   if(TPMode==0) return;                    // 純虛擬：不送伺服器 TP

   // v1.90 追蹤鏈：伺服器 TP 外推；追蹤啟動後加保底鎖利價（離現價太近、低於券商最小距離時暫不設）
   double srvTp = useTrail ? NormalizeDouble((side==0) ? tp+BasketTrailSrvTPUsd : tp-BasketTrailSrvTPUsd, _Digits) : tp;
   double srvSl = -1;                                            // -1＝不動原本的 SL（未啟動追蹤時與 v1.89 完全相同）
   if(useTrail && g_trOn[side] && BasketTrailLockSL)
   {
      double minD=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
      bool slOk=(side==0) ? (bid-lockPx>minD) : (lockPx-ask>minD);
      srvSl = slOk ? lockPx : -1;                                   // -1＝保留原值
   }
   ulong need[]; int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!IsMine(tk,side)) continue;
      bool tpOk = MathAbs(PositionGetDouble(POSITION_TP)-srvTp) < MathMax(_Point/2,TPMinChangeUsd);
      bool slSame = (srvSl<0) || MathAbs(PositionGetDouble(POSITION_SL)-srvSl) < _Point/2;
      if(tpOk && slSame) continue;
      ArrayResize(need,n+1); need[n++]=tk;
   }
   if(n==0){ g_tpDeferred[side]=false; return; }
   if(!MarketTradeable(true)) return;       // v1.86 休市時不送改單也不扣額度
   // 混合：本分鐘額度不足就先不改（伺服器上舊 TP 一定比新 TP 遠，不會提早誤平），由上面的虛擬 TP 保底
   if(TPMode==2 && MaxModsPerMin>0 && ModsLastMinute()+n > MaxModsPerMin){ g_tpDeferred[side]=true; return; }
   g_tpDeferred[side]=false;
   int sent=0;
   for(int j=0;j<n;j++)
      if(PositionSelectByTicket(need[j]))
      {
         double sl=(srvSl<0) ? PositionGetDouble(POSITION_SL) : srvSl;
         trade.PositionModify(need[j],sl,srvTp);
         uint rc=trade.ResultRetcode();
         if(rc==TRADE_RETCODE_MARKET_CLOSED || rc==TRADE_RETCODE_TRADE_DISABLED) break;
         sent++;
      }
   if(TPMode==2 && sent>0) ModBudgetTake(sent);
}

datetime g_modTimes[];
bool ModBudgetTake(int n)
{
   if(MaxModsPerMin<=0) return true;
   datetime now=TimeCurrent(); int k=0;
   for(int i=0;i<ArraySize(g_modTimes);i++) if(now-g_modTimes[i]<60) g_modTimes[k++]=g_modTimes[i];
   ArrayResize(g_modTimes,k);
   if(k+n > MaxModsPerMin) return false;
   ArrayResize(g_modTimes,k+n);
   for(int i=0;i<n;i++) g_modTimes[k+i]=now;
   return true;
}
int ModsLastMinute()
{
   datetime now=TimeCurrent(); int c=0;
   for(int i=0;i<ArraySize(g_modTimes);i++) if(now-g_modTimes[i]<60) c++;
   return c;
}

void DrawTPLine(int side,double price)
{
   string nm = (side==0) ? "DC1_TP_BUY" : "DC1_TP_SELL";
   if(!ShowTPLine || price<=0){ ObjectDelete(0,nm); return; }
   if(ObjectFind(0,nm)<0)
   {
      ObjectCreate(0,nm,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,side==0?clrDodgerBlue:clrOrangeRed);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   }
   else ObjectSetDouble(0,nm,OBJPROP_PRICE,price);
}

bool OpenLayer(int side,int L)
{
   if(g_closing[side]) return false;        // v1.61 收網中一律不開單
   if(!MarketTradeable(false)) return false;// v1.86 停盤/休市不送單
   double lot=LotForLayerS(side,L);                          // v1.81
   if(TPAtrMult>0) g_tpDist[side]=CalcTPDist();              // v1.62 每次加倉時決定止盈距離
   bool ok = (side==0) ? trade.Buy(lot,_Symbol,0,0,0,Tag(L,side))
                       : trade.Sell(lot,_Symbol,0,0,0,Tag(L,side));
   if(ok && (trade.ResultRetcode()==TRADE_RETCODE_DONE || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      PrintFormat("開倉 side=%d L%d lot=%.2f 成交 %.2f 補格排隊剩 %d",side,L,lot,trade.ResultPrice(),g_pending[side]);
      g_lastAdd[side]=TimeCurrent();
      g_trOn[side]=false; g_trPk[side]=0;                       // v1.90 新層開倉重置追蹤狀態
      if(g_vlOn[side] && g_anchorOv[side]>0) AnchorSave(side);  // v1.78
      SyncTP(side);
      return true;
   }
   PrintFormat("開倉失敗 side=%d L=%d lot=%.2f ret=%d",side,L,lot,trade.ResultRetcode());
   return false;
}

// v1.78 虛擬層記帳：以當下可成交價（多＝Ask、空＝Bid）記一筆，不送單
bool VirtOpen(int side,int L)
{
   double px=(side==0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0) return false;
   double lot=LotForLayerS(side,L);                          // v1.81
   if(L==0 || !g_vlOn[side])
   {
      g_vlOn[side]=true; g_vlAnchor[side]=px; g_vlN[side]=0; g_vlLots[side]=0; g_vlPV[side]=0; g_vlTime[side]=TimeCurrent();
   }
   if(TPAtrMult>0) g_tpDist[side]=CalcTPDist();
   g_vlN[side]=L+1; g_vlLots[side]+=lot; g_vlPV[side]+=lot*px;
   g_lastAdd[side]=TimeCurrent();
   VirtSave(side);
   return true;
}
// v1.78 虛擬鏈結束（還沒有真實單就到止盈價／週五提前出場）：等同一條鏈收完
void VirtClose(int side)
{
   g_lastClose[side]=TimeCurrent(); g_pending[side]=0; g_tpPx[side]=0; g_tpDeferred[side]=false; g_trOn[side]=false; g_trPk[side]=0; DrawTPLine(side,0);
   g_resume[side]=false; g_frozen[side]=false; g_frozenVel[side]=false; g_velTrig[side]=0; g_anchorOv[side]=0; g_tpDist[side]=0; AnchorSave(side); FreezeSave(side);
   VirtReset(side);
   HotReset(side);                                              // v1.81
}
// v1.78 開一層：虛擬層範圍內只記帳，其餘照常下單
bool OpenLayerX(int side,int L)
{
   int vk=SideVK(side);
   if(vk>0 && g_vlOn[side] && L<vk && L==g_vlN[side] && CountSide(side)==0) return VirtOpen(side,L);
   return OpenLayer(side,L);
}

//+------------------------------------------------------------------+
// v1.74 每個 tick 記錄價格（同一秒只記一次），並刪掉超過回看時間的舊紀錄
void VelRecord()
{
   if(VelMaxWin()<=0) return;
   datetime now=TimeCurrent();
   int n=ArraySize(g_vT);
   if(n>0 && g_vT[n-1]==now) return;
   ArrayResize(g_vT,n+1,4096); ArrayResize(g_vP,n+1,4096);
   g_vT[n]=now; g_vP[n]=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(g_vInitT==0) g_vInitT=now;
   datetime lim=now-(datetime)VelMaxWin()*60;
   while(g_vStart<n && g_vT[g_vStart]<lim) g_vStart++;
   if(g_vStart>4096)                                           // 定期壓縮陣列
   {
      int m=ArraySize(g_vT)-g_vStart;
      for(int i=0;i<m;i++){ g_vT[i]=g_vT[g_vStart+i]; g_vP[i]=g_vP[g_vStart+i]; }
      ArrayResize(g_vT,m,4096); ArrayResize(g_vP,m,4096);
      g_vStart=0;
   }
}

// v1.75 需要保留的最長回看分鐘數（快速、慢速取較大者；兩個都關閉回傳 0）
int VelMaxWin()
{
   int a=(VelWinMin>0 && VelUsd>0) ? VelWinMin : 0;
   int b=(Vel2WinMin>0 && Vel2Usd>0) ? Vel2WinMin : 0;
   return (a>b) ? a : b;
}

// v1.74／v1.75 取得 winMin 分鐘前（第一筆不早於該時間）的 Bid；EA 剛啟動、紀錄不夠長時改用 M1 K 棒開盤價
double VelPast(int winMin)
{
   int n=ArraySize(g_vT);
   if(n==0 || winMin<=0) return 0;
   datetime lim=TimeCurrent()-(datetime)winMin*60;
   if(g_vInitT>0 && g_vInitT<=lim)
   {
      int lo=g_vStart, hi=n-1;                                  // 二分搜尋第一筆 >= lim
      while(lo<hi){ int mid=(lo+hi)/2; if(g_vT[mid]<lim) lo=mid+1; else hi=mid; }
      return g_vP[lo];
   }
   int sh=iBarShift(_Symbol,PERIOD_M1,lim,false);
   if(sh<0) return 0;
   datetime bt=iTime(_Symbol,PERIOD_M1,sh);
   // v1.86 盲點修補5：若該 M1 K棒距今超過回看時間+1小時（代表跨週末或長休市），不誤拿上週五價格當急衝基準
   if(bt<=0 || (TimeCurrent()-bt) > (datetime)(winMin*60 + 3600)) return 0;
   double o=iOpen(_Symbol,PERIOD_M1,sh);
   return (o>0) ? o : 0;
}

// v1.74 急速逆向：更新觸發時間，回傳該方向目前是否在凍結期內
bool VelFrozen(int side,double bid)
{
   if(VelMaxWin()<=0) return false;
   datetime now=TimeCurrent();
   // 快速：VelWinMin 分鐘逆向超過 VelUsd
   if(VelWinMin>0 && VelUsd>0)
   {
      double past=VelPast(VelWinMin);
      if(past>0)
      {
         double adv=(side==0) ? past-bid : bid-past;            // 對鏈不利方向的變化
         if(adv>VelUsd)
         {
            if(g_velTrig[side]==0 || now-g_velTrig[side]>VelHoldMin*60)
               PrintFormat("急速逆向凍結 side=%d：%d 分鐘內逆向 %.2f 美元，暫停加倉 %d 分鐘",side,VelWinMin,adv,VelHoldMin);
            bool newTrig=(g_velTrig[side]==0 || now-g_velTrig[side]>VelHoldMin*60);
            g_velTrig[side]=now;
            if(newTrig || now-g_fzSaved[side]>=60){ FreezeSave(side); g_fzSaved[side]=now; }   // v1.88 每 60 秒最多寫一次
         }
      }
   }
   // v1.75 慢速：Vel2WinMin 分鐘逆向超過 Vel2Usd
   if(Vel2WinMin>0 && Vel2Usd>0)
   {
      double past2=VelPast(Vel2WinMin);
      if(past2>0)
      {
         double adv2=(side==0) ? past2-bid : bid-past2;
         if(adv2>Vel2Usd)
         {
            if(g_velTrig[side]==0 || now-g_velTrig[side]>VelHoldMin*60)
               PrintFormat("慢速逆向凍結 side=%d：%d 分鐘內逆向 %.2f 美元，暫停加倉 %d 分鐘",side,Vel2WinMin,adv2,VelHoldMin);
            bool newTrig2=(g_velTrig[side]==0 || now-g_velTrig[side]>VelHoldMin*60);
            g_velTrig[side]=now;
            if(newTrig2 || now-g_fzSaved[side]>=60){ FreezeSave(side); g_fzSaved[side]=now; }   // v1.88
         }
      }
   }
   return (g_velTrig[side]>0 && now-g_velTrig[side]<=VelHoldMin*60);
}

// v1.76 深層分批回收：最深一張單價格回到「格線與成交價較有利者 + RecycleUsd」就單獨平掉（只平獲利單）
//        平掉後最深層變淺一層；價格再回到該層格線時，依原規則（冷卻、每輪補格）重新補回
bool RecycleDeep(int side,int maxL,double anchor)
{
   if(RecycleLayer<=0 || RecycleUsd<=0 || maxL<RecycleLayer) return false;
   if(g_pending[side]>0 || g_closing[side]) return false;
   ulong best=0; int bestL=-1, n=0; double bestPx=0, bestV=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!IsMine(tk,side)) continue;
      n++;
      int L=LayerFromComment(PositionGetString(POSITION_COMMENT));
      if(L<0) continue;                                          // 手動單不回收
      double p=PositionGetDouble(POSITION_PRICE_OPEN);
      if(L>bestL || (L==bestL && ((side==0 && p<bestPx) || (side==1 && p>bestPx))))
      { bestL=L; best=tk; bestPx=p; bestV=PositionGetDouble(POSITION_VOLUME); }
   }
   if(n<2 || best==0 || bestL<RecycleLayer || bestL!=maxL) return false;   // 至少留一張；有手動單在更深處時不動作
   double lvl=(side==0) ? anchor-LevelOffS(side,bestL) : anchor+LevelOffS(side,bestL);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double thr=(side==0) ? MathMax(bestPx,lvl)+RecycleUsd : MathMin(bestPx,lvl)-RecycleUsd;
   bool go=(side==0) ? (bid>=thr) : (ask<=thr);
   if(!go) return false;
   if(trade.PositionClose(best) && (trade.ResultRetcode()==TRADE_RETCODE_DONE || trade.ResultRetcode()==TRADE_RETCODE_PLACED))
   {
      PrintFormat("深層回收 side=%d 平掉 L%d %.2f 手 開倉 %.2f 格線 %.2f 平倉 %.2f（剩 %d 張）",
                  side,bestL,bestV,bestPx,lvl,side==0?bid:ask,n-1);
      return true;
   }
   PrintFormat("深層回收失敗 side=%d L%d ret=%d",side,bestL,trade.ResultRetcode());
   return false;
}

// v1.86 最深獲利單＋最淺實單「淨正配對減倉」：同時平掉最深獲利單與套最遠實單（合計淨利≥PairTrimMinUsd）
//        不拉遠殘餘均價（反而靠攏現價）、不淨虧損、不動用其他鏈利潤池
bool PairTrim(int side,int maxL)
{
   if(PairTrimLayer<=0 || maxL<PairTrimLayer) return false;
   if(g_pending[side]>0 || g_closing[side] || !MarketTradeable(true)) return false;
   ulong tkDeep=0, tkShal=0; int deepL=-1, shalL=999999, realCnt=0;
   double deepNet=0, shalNet=0, deepV=0, shalV=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!IsMine(tk,side)) continue;
      int L=LayerFromComment(PositionGetString(POSITION_COMMENT));
      if(L<0) continue;                                          // 手動單不參與配對
      realCnt++;
      double vol=PositionGetDouble(POSITION_VOLUME);
      // 淨損益：浮動盈虧 + 隔夜利息 - 預估來回手續費（6 USC/手）
      double net=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP)-6.0*vol;
      if(L>deepL){ deepL=L; tkDeep=tk; deepNet=net; deepV=vol; }
      if(L<shalL){ shalL=L; tkShal=tk; shalNet=net; shalV=vol; }
   }
   if(realCnt<3 || tkDeep==0 || tkShal==0 || tkDeep==tkShal || deepL<PairTrimLayer) return false;
   if(deepNet<=0.0 || (deepNet+shalNet)<PairTrimMinUsd) return false;
   // 先平獲利最深單，成功再平最淺實單
   bool ok1=trade.PositionClose(tkDeep) && (trade.ResultRetcode()==TRADE_RETCODE_DONE || trade.ResultRetcode()==TRADE_RETCODE_PLACED);
   if(!ok1) return false;
   bool ok2=trade.PositionClose(tkShal) && (trade.ResultRetcode()==TRADE_RETCODE_DONE || trade.ResultRetcode()==TRADE_RETCODE_PLACED);
   PrintFormat("配對減倉 side=%d：平最深 L%d(%.2f手,淨%.1f) ＋ 最淺 L%d(%.2f手,淨%.1f) 合計淨%.1f ok2=%d",
               side,deepL,deepV,deepNet,shalL,shalV,shalNet,deepNet+shalNet,(int)ok2);
   return true;
}

// v1.82 順勢加碼：對面那條鏈目前最深的層數與該張單成交價（只看本 EA 的單；沒有持倉回傳 false）
bool OppDeepest(int side,int &L,double &px)
{
   int o=1-side; L=-1; px=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(!IsMine(tk,o)) continue;
      int k=LayerFromComment(PositionGetString(POSITION_COMMENT));
      if(k<0) continue;
      double p=PositionGetDouble(POSITION_PRICE_OPEN);
      if(k>L || (k==L && ((o==0 && p<px) || (o==1 && p>px)))){ L=k; px=p; }
   }
   return L>=0;
}
// v1.82 開新鏈當下：對面鏈 ≥ TrendBoostLayer 層、且現價離它最深那張單不超過 TrendBoostNearUsd → 回傳手數倍數，否則 1
double TrendBoostFor(int side)
{
   if(TrendBoostLayer<=0 || TrendBoostLotMul<=0 || TrendBoostLotMul==1.0) return 1.0;
   int L; double px;
   if(!OppDeepest(side,L,px) || L<TrendBoostLayer) return 1.0;
   if(TrendBoostNearUsd>0)
   {
      double cur=(side==0) ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      bool isNear=(side==0) ? (cur>=px-TrendBoostNearUsd) : (cur<=px+TrendBoostNearUsd);
      if(!isNear) return 1.0;
   }
   return TrendBoostLotMul;
}

void ProcessSide(int side)
{
   bool enabled = (side==0) ? EnableLong : EnableShort;
   datetime now = TimeCurrent();
   int cnt = CountSide(side);

   // v1.61 備援偵測：張數變少且最近有 TP 成交 → 伺服器正在逐張平倉，進入收網
   if(cnt>0 && cnt<g_prevCount[side] && !g_closing[side] && RecentTPExit(side))
      BeginClosing(side,"張數減少+TP成交");

   // 偵測鏈剛被止盈清空 → 記錄時間，啟動 75 秒重開冷卻
   if((g_prevCount[side]>0 || g_closing[side]) && cnt==0)
   {
      if(g_closing[side]) PrintFormat("收網完成 side=%d，層數歸零，%d 秒後可開新鏈",side,ReopenCooldownSec);
      g_lastClose[side]=now; g_pending[side]=0; g_tpPx[side]=0; g_tpDeferred[side]=false; g_trOn[side]=false; g_trPk[side]=0; DrawTPLine(side,0);
      g_closing[side]=false; g_resume[side]=false;
      g_frozen[side]=false; g_frozenVel[side]=false; g_velTrig[side]=0; g_anchorOv[side]=0; g_tpDist[side]=0; AnchorSave(side); FreezeSave(side); // v1.86
      VirtReset(side);                                           // v1.78 真實單全平 → 虛擬層一併結束
      HotReset(side);                                            // v1.81 寬格倍數歸位
   }
   g_prevCount[side]=cnt;

   // v1.61 收網中：殘單直接市價收掉，平完之前不做任何其他事
   if(g_closing[side])
   {
      if(cnt>0 && (MQLInfoInteger(MQL_TESTER) || GetTickCount()-g_closeTry[side]>500)){ CloseSide(side); g_closeTry[side]=GetTickCount(); }
      return;
   }

   bool vOnly = (cnt==0 && g_vlOn[side]);     // v1.78 這條鏈目前只有虛擬層、還沒有真實單
   if(cnt==0 && !vOnly)
   {
      if(!enabled || g_halted) return;
      if(NewsBlocked()) return;               // v1.50 新聞窗口內不開新鏈
      if(FridayGate()) return;                // v1.60 週五收盤前不開新鏈
      if(RegimeHot()) return;                 // v1.72 行情過熱：不開新鏈
      bool hot2=Regime2Hot();
      if(hot2 && !HotModeOn()) return;        // v1.80 長期波動過熱：不開新鏈（v1.81：寬格模式開啟時改用寬格距，見下）
      if(EdgeBlocked(side)) return;           // v1.80 高低點過濾：離高點太近不開空鏈、離低點太近不開多鏈
      int rcCur=ReopenCooldownSec;
      if(TrendReopenSec>0 && TrendBoostLayer>0 && TrendReopenSec<rcCur)          // v1.92 順勢極速重開
      {
         int oppL; double oppPx;
         if(OppDeepest(side,oppL,oppPx) && oppL>=TrendBoostLayer) rcCur=TrendReopenSec;
      }
      if(g_lastClose[side]>0 && now-g_lastClose[side] < rcCur) return;
      g_hotMul[side]=hot2 ? HotGridMul : 1.0;                     // v1.81 這條鏈的格距／手數倍數，開鏈時決定
      g_hotLot[side]=(hot2 && HotLotMul>0) ? HotLotMul : 1.0;
      g_tbLot[side]=TrendBoostFor(side);                          // v1.82 順勢加碼：開鏈時決定
      if(g_tbLot[side]!=1.0) PrintFormat("順勢加碼 side=%d：前 %d 層手數 ×%.2f%s",side,TrendBoostMaxLayer,g_tbLot[side],TBReal(side)?StringFormat("；前 %d 層實單 %.2f 手、不用虛擬層",TrendBoostFrontLayers,LotForLayerS(side,0)):"");
      HotSave(side);
      if(SideVK(side)>0 && !TBReal(side)) VirtOpen(side,0);   // v1.93 依鏈類型套用虛擬層；v1.83 順勢實單模式直接下單
      else if(OpenLayer(side,0)) g_prevCount[side]=1;
      return;
   }

   int maxL; double anchor,avg,lots,pnl;
   if(vOnly)
   {
      // v1.78 只有虛擬層：到止盈價就結束這條虛擬鏈（沒有任何成交）
      VirtState(side,maxL,anchor,avg); lots=0; pnl=0;
      double vtp=NormalizeDouble((side==0) ? avg+TPDist(side,maxL) : avg-TPDist(side,maxL),_Digits);
      double vb=SymbolInfoDouble(_Symbol,SYMBOL_BID), va=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      g_tpPx[side]=vtp;
      if((side==0 && vb>=vtp) || (side==1 && va<=vtp)){ VirtClose(side); return; }
   }
   else
   {
      if(!ChainState(side,maxL,anchor,avg,lots,pnl)) return;

      // 風控：單鏈砍倉
      if(ChainStopLoss>0 && pnl <= -ChainStopLoss)
      {
         PrintFormat("單鏈止損觸發 side=%d 浮虧=%.2f 層數=%d",side,pnl,maxL+1);
         BeginClosing(side,"單鏈止損"); CloseSide(side); return;
      }

      // v1.76 深層分批回收：平掉一張後重算 TP，下個 tick 再判斷下一張
      if(RecycleDeep(side,maxL,anchor)){ SyncTP(side); return; }
      // v1.86 淨正配對減倉：最深獲利單＋最淺實單合計淨正同時平倉
      if(PairTrim(side,maxL)){ SyncTP(side); return; }

      // 確保 TP 一直正確（重啟或改單失敗時補救）
      SyncTP(side);
      if(CountSide(side)==0) return;
   }
   if(g_halted) return;

   // v1.60 週五收盤前：有獲利就提前全平（不虧損平倉）；可選擇停止加倉
   if(FridayGate())
   {
      if(FridayExitUsd>0)
      {
         double b=SymbolInfoDouble(_Symbol,SYMBOL_BID), a=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double dist = (side==0) ? b-avg : avg-a;
         if(dist >= FridayExitUsd)
         {
            if(vOnly){ VirtClose(side); return; }                // v1.78 只有虛擬層：直接結束
            PrintFormat("週五收盤前提前出場 side=%d 層數=%d 手數=%.2f 每手獲利 %.2f",side,maxL+1,lots,dist);
            BeginClosing(side,"週五提前出場"); CloseSide(side); DrawTPLine(side,0); return;
         }
      }
      if(FridayStopAdds) return;
   }
   if(g_trOn[side]) return;                                      // v1.90 追蹤止盈啟動期間不再加倉（週五出場已在上面照常處理）

   int next=maxL+1;
   if(MaxLayers>0 && next>=MaxLayers) return;
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // v1.74 急速逆向凍結：最近 VelWinMin 分鐘逆向超過 VelUsd → 暫停加倉（止盈照常）
   bool velFrz=VelFrozen(side,bid);
   if(velFrz && !VelReanchor){ g_pending[side]=0; return; }      // 不重新定錨：只延後，之後照常追補

   // v1.62 新聞凍結：公佈當下～+N 分鐘不加倉（止盈在上面的 SyncTP 照常）
   bool newsFrz=NewsFreeze();
   if(newsFrz || velFrz)
   {
      if(!g_frozen[side] && newsFrz) PrintFormat("新聞凍結加倉 side=%d 目前 L%d 手數 %.2f，%d 分鐘內不加倉",side,maxL,lots,NewsFreezeAfterMin);
      bool wasF=g_frozen[side];
      if(!g_frozen[side]) g_frozenVel[side]=!newsFrz;
      else if(newsFrz) g_frozenVel[side]=false;
      g_frozen[side]=true; g_pending[side]=0;
      if(!wasF) FreezeSave(side);                                // v1.86 持久化凍結狀態
      return;
   }
   if(g_frozen[side])
   {
      bool reanchor = g_frozenVel[side] ? VelReanchor : NewsReanchor;
      g_frozen[side]=false; g_frozenVel[side]=false; FreezeSave(side); // v1.86
      if(reanchor)
      {
         double px=(side==0)?ask:bid;
         double st=StepOf(next)*g_hotMul[side];                  // v1.81
         double na=(side==0) ? px-st+LevelOffS(side,next) : px+st-LevelOffS(side,next);
         // 只在對鏈有利時改錨（價格已越過原本的下一層＝暴衝期間錯過的層不補）
         double oldLvl=(side==0)?anchor-LevelOffS(side,next):anchor+LevelOffS(side,next);
         bool passed=(side==0)?(ask<oldLvl):(bid>oldLvl);
         if(passed)
         {
            g_anchorOv[side]=na; anchor=na; AnchorSave(side);
            PrintFormat("凍結結束 side=%d 重新定錨 %.2f → 下一層 L%d 觸發價 %.2f",side,na,next,(side==0)?na-LevelOffS(side,next):na+LevelOffS(side,next));
         }
         else PrintFormat("凍結結束 side=%d 價格未越過下一層，沿用原網格",side);
      }
      g_lastAdd[side]=now;                                       // 凍結結束後先走一輪冷卻
   }

   double level = (side==0) ? anchor - LevelOffS(side,next) : anchor + LevelOffS(side,next);
   bool hit = (side==0) ? (ask <= level) : (bid >= level);

   // --- L1：到價立即加，不受冷卻與補格計數影響 ---
   if(next==1 && L1NoCooldown)
   {
      if(hit && OpenLayerX(side,1)){ g_lastAdd[side]=now; g_pending[side]=0; }
      return;
   }

   // --- L2 起：冷卻 + 補格輪次 ---
   // v1.10：每輪最多 MaxCatchUp 層。
   // v1.20：一輪補幾層在「開輪那一刻」決定 = min(MaxCatchUp, 當下已越過的格數)，
   //        之後每個 tick 送一單直到補完，中途不再檢查價格（原版 2.1 萬輪皆符合此規則）。
   if(g_pending[side] > 0)
   {
      if(!OpenLayerX(side,next)){ g_pending[side]=0; return; }
      g_lastAdd[side]=now;
      g_pending[side]--;
      return;
   }
   if(!hit) return;
   if(now-g_lastAdd[side] < AddCooldownSec) return;      // 冷卻中

   double dist = (side==0) ? (anchor-ask) : (bid-anchor);
   int crossed = LevelsWithinS(side,dist) - next + 1;                        // 含本層，已越過幾格
   if(crossed < 1) return;
   int k = MathMin(MaxCatchUp, crossed);
   if(DeepCatchLayer>0 && DeepMaxCatchUp>0)                            // v1.70 深層放慢補格
   {
      int lim = (next>=DeepCatchLayer) ? DeepMaxCatchUp : (DeepCatchLayer-next)+DeepMaxCatchUp;
      k = MathMin(k, lim);
   }
   if(g_resume[side]) k = MathMin(k, MathMax(1,RestartMaxCatchUp));   // v1.61 重啟後首輪限量
   if(MaxLayers>0) k = MathMin(k, MaxLayers-next);
   if(k < 1) return;

   PrintFormat("補格開輪 side=%d 從 L%d 起補 %d 層（已越過 %d 格）觸發價 %.2f 現價 %.2f 錨點 %.2f 持倉 %d 張",
               side,next,k,crossed,level,side==0?ask:bid,anchor,CountSide(side));
   g_pending[side]=k-1;
   if(!OpenLayerX(side,next)){ g_pending[side]=0; return; }
   g_lastAdd[side]=now;
   g_resume[side]=false;
}

void CheckEquityStop()
{
   if(EquityStopPct<=0 || g_halted) return;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= bal*(1.0-EquityStopPct/100.0))
   {
      PrintFormat("權益止損觸發：餘額 %.2f 權益 %.2f，全部平倉並停止開新單",bal,eq);
      CloseSide(0); CloseSide(1); g_halted=true;
   }
}

//+------------------------------------------------------------------+
//| 回撤統計：當日（伺服器日）與歷史最大，歷史值存在終端全域變數      |
//+------------------------------------------------------------------+
double   g_histPeakEq=0, g_histMaxDDPct=0, g_histMaxDDAmt=0;
datetime g_ddDay=0;
double   g_dayPeakEq=0, g_dayMaxDDPct=0, g_dayMaxDDAmt=0;
datetime g_dayMaxDDT=0;     // v1.77 今日最大回撤發生時間（面板顯示用）

string GVKey(string k){ return StringFormat("DC1_%I64d_%I64d_%s",AccountInfoInteger(ACCOUNT_LOGIN),Magic,k); }

// v1.73 入金／出金不算回撤：記錄已處理到的時間與單號，偵測到新的入出金就同步調整最高淨值
datetime g_cashT=0;          // 上次掃描入出金的時間
double   g_cashTk=0;         // 已處理過的最大入出金單號
double   g_lastBal=0;        // 上次看到的餘額（餘額變動時才掃描歷史）
uint     g_cashScanMs=0;     // 上次掃描的時間（毫秒）
uint     g_cashHold=0;       // 餘額大減但歷史尚未出現出金單時，暫停記錄回撤（最多 30 秒）

bool IsCashDeal(long t)
{
   return t==DEAL_TYPE_BALANCE || t==DEAL_TYPE_CREDIT || t==DEAL_TYPE_CHARGE ||
          t==DEAL_TYPE_CORRECTION || t==DEAL_TYPE_BONUS;
}

// 掃描新的入出金單，回傳這次新發現的金額合計（入金為正、出金為負）；apply=false 只標記為已處理
double CashScan(bool apply)
{
   datetime now=TimeCurrent();
   bool first=(g_cashT<=0);                                   // 第一次掃描：既有的入出金只標記，不調整
   datetime from=first ? now-86400 : g_cashT-300;
   if(!HistorySelect(from,now+60)) return 0;
   double sum=0, mx=g_cashTk;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(d==0 || (double)d<=g_cashTk) continue;
      if(!IsCashDeal(HistoryDealGetInteger(d,DEAL_TYPE))) continue;
      sum+=HistoryDealGetDouble(d,DEAL_PROFIT);
      if((double)d>mx) mx=(double)d;
   }
   g_cashTk=mx;
   g_cashT=now;
   return (apply && !first) ? sum : 0;
}

// 把入出金金額加到最高淨值上（出金後最高淨值跟著降低，回撤不變）
void CashApply(double amt)
{
   if(amt==0) return;
   g_histPeakEq+=amt;
   if(g_ddDay>0) g_dayPeakEq+=amt;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_histPeakEq<eq) g_histPeakEq=eq;
   if(g_ddDay>0 && g_dayPeakEq<eq) g_dayPeakEq=eq;
   PrintFormat("偵測到%s %.2f，最高淨值同步調整為 %.2f（不計入回撤）",amt>0?"入金":"出金",MathAbs(amt),g_histPeakEq);
}

void DDInit()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   if(!tester && !ResetMaxDD && GlobalVariableCheck(GVKey("peak")))
   {
      g_histPeakEq  = GlobalVariableGet(GVKey("peak"));
      g_histMaxDDPct= GlobalVariableGet(GVKey("ddp"));
      g_histMaxDDAmt= GlobalVariableGet(GVKey("dda"));
   }
   else { g_histPeakEq=eq; g_histMaxDDPct=0; g_histMaxDDAmt=0; }
   g_ddDay=0;
   // v1.73 入出金：重啟時補算 EA 沒在跑的期間發生的入出金；第一次使用或重設時只把既有的標記為已處理
   if(!tester && !ResetMaxDD && GlobalVariableCheck(GVKey("cashT")) && GlobalVariableCheck(GVKey("peak")))
   {
      g_cashT=(datetime)GlobalVariableGet(GVKey("cashT"));
      g_cashTk=GlobalVariableGet(GVKey("cashTk"));
      CashApply(CashScan(true));
   }
   else if(!tester) { g_cashT=0; g_cashTk=0; CashScan(false); }
   g_lastBal=AccountInfoDouble(ACCOUNT_BALANCE);
   g_cashScanMs=GetTickCount();
}

void DDSave()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   GlobalVariableSet(GVKey("peak"),g_histPeakEq);
   GlobalVariableSet(GVKey("ddp"),g_histMaxDDPct);
   GlobalVariableSet(GVKey("dda"),g_histMaxDDAmt);
   GlobalVariableSet(GVKey("cashT"),(double)g_cashT);          // v1.73
   GlobalVariableSet(GVKey("cashTk"),g_cashTk);
}

void DDUpdate()
{
   // v1.73 餘額有變動（平倉或入出金）或每 60 秒，掃描一次入出金；先調整最高淨值再算回撤（回測不掃描）
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!MQLInfoInteger(MQL_TESTER) && (MathAbs(bal-g_lastBal)>0.001 || g_cashHold>0 || GetTickCount()-g_cashScanMs>60000))
   {
      double drop=g_lastBal-bal;
      g_lastBal=bal; g_cashScanMs=GetTickCount();
      double amt=CashScan(true);
      if(amt!=0){ CashApply(amt); DDSave(); g_cashHold=0; }
      else if(drop>1000) g_cashHold=GetTickCount();              // 餘額一次少 1000 以上，多半是出金單還沒進歷史 → 先等
      else if(g_cashHold>0 && GetTickCount()-g_cashHold>30000) g_cashHold=0;
   }
   if(g_cashHold>0) return;                                      // 等待期間不更新回撤紀錄
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   datetime day=(datetime)(((long)TimeCurrent()/86400)*86400);
   if(day!=g_ddDay){ g_ddDay=day; g_dayPeakEq=eq; g_dayMaxDDPct=0; g_dayMaxDDAmt=0; g_dayMaxDDT=0; }
   if(eq>g_dayPeakEq) g_dayPeakEq=eq;
   double dA=g_dayPeakEq-eq, dP=(g_dayPeakEq>0)?dA/g_dayPeakEq*100:0;
   if(dP>g_dayMaxDDPct){ g_dayMaxDDPct=dP; g_dayMaxDDAmt=dA; g_dayMaxDDT=TimeCurrent(); }
   bool chg=false;
   if(eq>g_histPeakEq){ g_histPeakEq=eq; chg=true; }
   double hA=g_histPeakEq-eq, hP=(g_histPeakEq>0)?hA/g_histPeakEq*100:0;
   if(hP>g_histMaxDDPct){ g_histMaxDDPct=hP; g_histMaxDDAmt=hA; chg=true; }
   static uint lastSave=0;
   if(chg && GetTickCount()-lastSave>5000){ DDSave(); lastSave=GetTickCount(); }
}

//+------------------------------------------------------------------+
//| v1.79 面板：玫瑰金・簡約現代（CCanvas 點陣繪製）                  |
//|  玫瑰金屬：象牙白底、白卡片、今日獲利放在玫瑰金漸層色塊上        |
//|  標題 → 今日獲利 → 淨值／浮動／回撤 → 回撤預算條 → 多空鏈卡片    |
//|  靜態圖層只畫一次並快取，每次更新只疊上動態內容                   |
//+------------------------------------------------------------------+
#define PNL_W   1040     // 面板寬（基準像素，實際 × PanelScale）
#define PNL_H   570      // 面板高

bool g_cham=false;           // 外框形狀：false＝圓角

double DcRRDist(double px,double py,double x,double y,double w,double h,double r)
{
   // 點到圓角矩形邊界的有號距離（內部為負）
   double cx=x+w/2.0, cy=y+h/2.0;
   double qx=MathAbs(px-cx)-(w/2.0-r), qy=MathAbs(py-cy)-(h/2.0-r);
   double ox=MathMax(qx,0.0), oy=MathMax(qy,0.0);
   return MathSqrt(ox*ox+oy*oy)+MathMin(MathMax(qx,qy),0.0)-r;
}

// v1.77 切角矩形的有號距離（內部為負），c＝切角大小
double DcChamDist(double px,double py,double x,double y,double w,double h,double c)
{
   double dx=MathMin(px-x,x+w-px), dy=MathMin(py-y,y+h-py);
   double d=MathMin(MathMin(dx,dy),(dx+dy-c)*0.70710678);
   return -d;
}

// v1.77 依面板版本取外框距離：切角或圓角
double DcShpDist(double px,double py,double x,double y,double w,double h,double r)
{
   return g_cham ? DcChamDist(px,py,x,y,w,h,r*0.8) : DcRRDist(px,py,x,y,w,h,r);
}

uint DCARGB(int a,int r,int g,int b){ return ((uint)a<<24)|((uint)r<<16)|((uint)g<<8)|(uint)b; }
uint WithA(uint c,int a){ if(a<0) a=0; if(a>255) a=255; return (c&0x00FFFFFF)|((uint)a<<24); }

class CDCCanvas : public CCanvas
{
public:
   void SnapTo(uint &dst[])         { ArrayCopy(dst,m_pixels); }
   void LoadFrom(const uint &src[]) { if(ArraySize(src)==ArraySize(m_pixels)) ArrayCopy(m_pixels,src); }

   // 貼底圖（不透明 ARGB 陣列）到 (ox,oy)，四個圓角依半徑 r 抗鋸齒裁切
   void DcBlit(const uint &src[],int sw,int sh,int ox,int oy,double r)
   {
      if(ArraySize(src)<sw*sh) return;
      int rc=(int)MathCeil(r)+1;
      for(int y=0;y<sh;y++)
      {
         int py=oy+y;
         if(py<0 || py>=m_height) continue;
         for(int x=0;x<sw;x++)
         {
            int px=ox+x;
            if(px<0 || px>=m_width) continue;
            uint c=src[y*sw+x];
            bool inner=(x>=rc && x<sw-rc) || (y>=rc && y<sh-rc);
            if(inner){ m_pixels[py*m_width+px]=c; continue; }
            double d=DcRRDist(x+0.5,y+0.5,0.0,0.0,(double)sw,(double)sh,r);
            if(d>=0.5) continue;
            if(d<=-0.5) m_pixels[py*m_width+px]=c;
            else        DcPx(px,py,c,0.5-d);
         }
      }
   }

   // 單一像素 alpha 混色：來源色 c 的 alpha × 覆蓋率 cov
   void DcPx(int x,int y,uint c,double cov)
   {
      if(cov<=0.0 || x<0 || y<0 || x>=m_width || y>=m_height) return;
      double a=((c>>24)&0xFF)/255.0*MathMin(1.0,cov);
      if(a<=0.0) return;
      int i=y*m_width+x;
      uint d=m_pixels[i];
      double da=((d>>24)&0xFF)/255.0;
      double k=da*(1.0-a);
      double oa=a+k;
      if(oa<=0.0) return;
      uint r=(uint)MathRound((((c>>16)&0xFF)*a+((d>>16)&0xFF)*k)/oa);
      uint g=(uint)MathRound((((c>>8)&0xFF)*a+((d>>8)&0xFF)*k)/oa);
      uint b=(uint)MathRound(((c&0xFF)*a+(d&0xFF)*k)/oa);
      uint A=(uint)MathRound(oa*255.0);
      if(r>255) r=255; if(g>255) g=255; if(b>255) b=255; if(A>255) A=255;
      m_pixels[i]=(A<<24)|(r<<16)|(g<<8)|b;
   }

   // 實心矩形（邊緣次像素覆蓋）
   void DcRect(double x,double y,double w,double h,uint c)
   {
      int x0=(int)MathFloor(x), y0=(int)MathFloor(y), x1=(int)MathCeil(x+w), y1=(int)MathCeil(y+h);
      for(int py=y0;py<y1;py++)
      {
         double cy=MathMin(py+1.0,y+h)-MathMax((double)py,y);
         if(cy<=0.0) continue;
         for(int px=x0;px<x1;px++)
         {
            double cx=MathMin(px+1.0,x+w)-MathMax((double)px,x);
            if(cx>0.0) DcPx(px,py,c,cx*cy);
         }
      }
   }

   // 圓弧帶（抗鋸齒）：半徑 r、粗細 t；角度 a0→a1 以正上方為 0°、順時針（度）
   void DcArc(double cx,double cy,double r,double t,double a0,double a1,uint c)
   {
      double sw=a1-a0;
      if(sw<=0.0) return;
      if(sw>360.0) sw=360.0;
      double ro=r+t/2.0+1.0;
      int x0=(int)MathFloor(cx-ro), y0=(int)MathFloor(cy-ro), x1=(int)MathCeil(cx+ro), y1=(int)MathCeil(cy+ro);
      for(int py=y0;py<=y1;py++)
         for(int px=x0;px<=x1;px++)
         {
            double dx=px+0.5-cx, dy=py+0.5-cy;
            double dd=MathSqrt(dx*dx+dy*dy);
            double cr=0.5-(MathAbs(dd-r)-t/2.0);                    // 徑向覆蓋率
            if(cr<=0.0) continue;
            double ang=MathArctan2(dx,-dy)*180.0/M_PI;
            if(ang<0.0) ang+=360.0;
            double rel=MathMod(ang-a0+720.0,360.0);
            double e=(rel<=sw) ? MathMin(rel,sw-rel) : -MathMin(rel-sw,360.0-rel);
            double ca=0.5+e*M_PI/180.0*dd;                         // 角度方向覆蓋率（像素）
            if(ca<=0.0) continue;
            DcPx(px,py,c,MathMin(1.0,cr)*MathMin(1.0,ca));
         }
   }

   // 圓角矩形填色
   void DcFillRR(double x,double y,double w,double h,double r,uint c)
   {
      int x0=(int)MathFloor(x), y0=(int)MathFloor(y), x1=(int)MathCeil(x+w), y1=(int)MathCeil(y+h);
      for(int py=y0;py<y1;py++)
         for(int px=x0;px<x1;px++)
         {
            double cov=0.5-DcShpDist(px+0.5,py+0.5,x,y,w,h,r);
            if(cov>0.0) DcPx(px,py,c,MathMin(1.0,cov));
         }
   }

   // 圓角矩形框線（往內 t 像素）
   void DcStrokeRR(double x,double y,double w,double h,double r,uint c,double t)
   {
      int x0=(int)MathFloor(x), y0=(int)MathFloor(y), x1=(int)MathCeil(x+w), y1=(int)MathCeil(y+h);
      for(int py=y0;py<y1;py++)
         for(int px=x0;px<x1;px++)
         {
            double d=DcShpDist(px+0.5,py+0.5,x,y,w,h,r);
            double cov=MathMin(0.5-d,d+t+0.5);
            if(cov>0.0) DcPx(px,py,c,MathMin(1.0,cov));
         }
   }

   // 圓角矩形外光暈（向外 R 像素淡出）
   void DcGlowRR(double x,double y,double w,double h,double r,uint c,double R)
   {
      int x0=(int)MathFloor(x-R), y0=(int)MathFloor(y-R), x1=(int)MathCeil(x+w+R), y1=(int)MathCeil(y+h+R);
      for(int py=y0;py<y1;py++)
         for(int px=x0;px<x1;px++)
         {
            double d=DcShpDist(px+0.5,py+0.5,x,y,w,h,r);
            if(d<=0.0 || d>=R) continue;
            double f=1.0-d/R;
            DcPx(px,py,c,f*f);
         }
   }

   // 實心圓（抗鋸齒）
   void DcCircle(double cx,double cy,double rr,uint c)
   {
      int x0=(int)MathFloor(cx-rr-1), y0=(int)MathFloor(cy-rr-1), x1=(int)MathCeil(cx+rr+1), y1=(int)MathCeil(cy+rr+1);
      for(int py=y0;py<=y1;py++)
         for(int px=x0;px<=x1;px++)
         {
            double dx=px+0.5-cx, dy=py+0.5-cy;
            double cov=rr-MathSqrt(dx*dx+dy*dy)+0.5;
            if(cov>0.0) DcPx(px,py,c,MathMin(1.0,cov));
         }
   }

   // 右斜平行四邊形（階梯條的單格）
   void DcPara(double x,double y,double w,double h,double sk,uint c)
   {
      int y0=(int)MathFloor(y), y1=(int)MathCeil(y+h);
      for(int py=y0;py<y1;py++)
      {
         double yy=py+0.5-y;
         if(yy<0.0 || yy>h) continue;
         double xl=x+(h-yy)*sk, xr=xl+w;
         for(int px=(int)MathFloor(xl);px<(int)MathCeil(xr);px++)
         {
            double cov=MathMin(px+1.0,xr)-MathMax((double)px,xl);
            if(cov>0.0) DcPx(px,py,c,cov);
         }
      }
   }

   // 實心菱形（3×3 超取樣抗鋸齒）
   void DcDiamond(double cx,double cy,double r,uint c)
   {
      int x0=(int)MathFloor(cx-r), y0=(int)MathFloor(cy-r), x1=(int)MathCeil(cx+r), y1=(int)MathCeil(cy+r);
      for(int py=y0;py<y1;py++)
         for(int px=x0;px<x1;px++)
         {
            int hit=0;
            for(int sy=0;sy<3;sy++)
               for(int sx=0;sx<3;sx++)
                  if(MathAbs(px+(sx+0.5)/3.0-cx)+MathAbs(py+(sy+0.5)/3.0-cy)<=r) hit++;
            if(hit>0) DcPx(px,py,c,hit/9.0);
         }
   }
};

CDCCanvas g_cv;
bool      g_cvOK=false;
uint      g_cvStatic[];
double    g_ps=1.0;                  // 面板縮放
double    g_fs=1.0;                  // 字體倍率
int       g_mg=12;                   // 外光暈邊距（像素）
int       g_budgetL=-1;              // 回撤預算對應的層數
datetime  g_budgetT=0;
int       g_ladN=52;                 // 階梯條格數（依預算線自動調整）
uint      g_panelTick=0;

// 色票
uint T_BG,T_BG2,T_BD,T_TX,T_SUB,T_DIM,T_A1,T_A2,T_LONG,T_SHORT,T_POS,T_NEG,T_WARN,T_OFF,T_HALO,T_CARD,T_LINE,T_HERO1,T_HERO2,T_HEROTX,T_GRN;
string F_TXT = "Microsoft JhengHei UI";   // 中文
string F_NUM = "Segoe UI";                // 數字／英文
string F_TTL = "Microsoft JhengHei UI";   // 標題「多財多億」
string F_SER = "Times New Roman";         // v1.82 黑金面板：大數字用襯線字

// v1.79 今日獲利（本 EA 今天已平倉損益，含隔夜利息與手續費）
double g_dayPnl=0;
int    g_dayDeals=0;
uint   g_dayPnlTick=0;
void DayPnlUpdate()
{
   if(g_dayPnlTick!=0 && GetTickCount()-g_dayPnlTick<2000) return;
   g_dayPnlTick=GetTickCount();
   datetime now=TimeCurrent();
   datetime d0=now-(now%86400);                              // 伺服器日期的 00:00
   if(!HistorySelect(d0,now+60)) return;
   double sum=0; int n=0;
   int tot=HistoryDealsTotal();
   for(int i=0;i<tot;i++)
   {
      ulong tk=HistoryDealGetTicket(i);
      if(tk==0) continue;
      if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol) continue;
      if(HistoryDealGetInteger(tk,DEAL_MAGIC)!=Magic) continue;
      long tp=HistoryDealGetInteger(tk,DEAL_TYPE);
      if(tp!=DEAL_TYPE_BUY && tp!=DEAL_TYPE_SELL) continue;
      sum+=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_COMMISSION)+HistoryDealGetDouble(tk,DEAL_FEE);
      long en=HistoryDealGetInteger(tk,DEAL_ENTRY);
      if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_INOUT || en==DEAL_ENTRY_OUT_BY) n++;
   }
   g_dayPnl=sum; g_dayDeals=n;
}

// v1.79 玫瑰金屬：象牙白底、白卡片、今日獲利放在玫瑰金漸層色塊上
// 賺錢＝玫瑰金、虧損與超出預算＝藍；多鏈＝玫瑰金、空鏈＝銀灰藍（不用紅綠，色弱也分得清）
void PanelThemeSet()
{
   g_cham=false;
   // 「黑金」：黑底、金框、今日獲利放在金條色塊上；賺錢＝金、虧損＝綠、超過預算線＝紅
   T_BG  =DCARGB(255,11,10,8);     T_BG2=DCARGB(255,16,14,11);    T_BD=DCARGB(255,212,175,95);
   T_TX  =DCARGB(255,240,232,215); T_SUB=DCARGB(255,205,187,148); T_DIM=DCARGB(255,140,126,98);
   T_A1  =DCARGB(255,212,175,95);  T_A2=DCARGB(255,240,214,150);                 // 金／亮金
   T_NEG =DCARGB(255,226,112,92);  T_WARN=DCARGB(255,232,160,60);                // 危險紅／警示橘
   T_SHORT=DCARGB(255,206,207,212);                                              // 空鏈：銀
   T_CARD=DCARGB(255,16,14,11);    T_LINE=DCARGB(255,120,96,52);
   T_OFF =DCARGB(55,212,175,95);   T_HALO=DCARGB(110,0,0,0);
   T_LONG=T_A1;                      // 多鏈：金
   T_POS =T_A2;                      // 賺錢：亮金
   T_GRN =DCARGB(255,110,200,160);   // 虧損：綠
   T_HERO1=T_A2;  T_HERO2=T_A1;  T_HEROTX=DCARGB(255,38,26,8);   // 金條色塊上的深色字
   F_TXT=(PanelFontTxt!="") ? PanelFontTxt : "Microsoft JhengHei UI";
   F_NUM=(PanelFontNum!="") ? PanelFontNum : "Bahnschrift";
   F_SER=(PanelFontSerif!="") ? PanelFontSerif : "Times New Roman";
   F_TTL=F_TXT;
}

// 座標換算：基準座標 → 畫布像素
double PD(double v){ return v*g_ps; }
double PX(double v){ return g_mg+v*g_ps; }
double PY(double v){ return g_mg+v*g_ps; }

// 文字寬度（基準像素），sp＝字距
double PTxtW(string s,string font,double size,bool bold,double sp)
{
   int wt=bold ? FW_BOLD : FW_NORMAL;
   if(!bold) wt=FW_MEDIUM;                                   // 玫瑰金屬：一般字也偏粗
   g_cv.FontSet(font,(int)MathMax(7,MathRound(size*g_ps*g_fs)),wt,0);
   int n=StringLen(s);
   if(sp<=0) return g_cv.TextWidth(s)/g_ps;
   int spx=(int)MathRound(sp*g_ps), w=0;
   for(int i=0;i<n;i++) w+=g_cv.TextWidth(StringSubstr(s,i,1))+(i<n-1?spx:0);
   return w/g_ps;
}

// 文字輸出：ha 0=靠左 1=置中 2=靠右；sp＝字距；glow＝發光
void PTxt(double x,double y,string s,uint c,string font,double size,int ha=0,bool bold=false,double sp=0,bool glow=false)
{
   if(s=="") return;
   double wb=PTxtW(s,font,size,bold,sp);                     // 同時完成 FontSet
   int w=(int)MathRound(wb*g_ps);
   int ix=(int)MathRound(PX(x)), iy=(int)MathRound(PY(y));
   if(ha==1) ix-=w/2; else if(ha==2) ix-=w;
   int spx=(int)MathRound(sp*g_ps);
   int n=StringLen(s);
   int passes=(glow && PanelGlow) ? 5 : 1;
   for(int p=0;p<passes;p++)
   {
      int ox=0, oy=0; uint cc=c;
      if(p<passes-1){ cc=WithA(c,45); if(p==0) ox=-1; else if(p==1) ox=1; else if(p==2) oy=-1; else oy=1; }
      if(sp<=0) g_cv.TextOut(ix+ox,iy+oy,s,cc,TA_LEFT|TA_TOP);
      else
      {
         int xx=ix+ox;
         for(int i=0;i<n;i++)
         {
            string ch=StringSubstr(s,i,1);
            g_cv.TextOut(xx,iy+oy,ch,cc,TA_LEFT|TA_TOP);
            xx+=g_cv.TextWidth(ch)+spx;
         }
      }
   }
}

string Money(double v,int dg=2)
{
   string sign = v<0 ? "-" : "";
   double a=MathAbs(v);
   string s=DoubleToString(a,dg);
   int dot=StringFind(s,".");
   string ip = dot>=0 ? StringSubstr(s,0,dot) : s;
   string fp = dot>=0 ? StringSubstr(s,dot) : "";
   string out="";
   int n=StringLen(ip);
   for(int i=0;i<n;i++)
   {
      out+=StringSubstr(ip,i,1);
      int rem=n-1-i;
      if(rem>0 && rem%3==0) out+=",";
   }
   return sign+out+fp;
}

string Signed(double v,int dg=2){ return (v>0?"+":"")+Money(v,dg); }

string KFmt(double v)
{
   if(v<1000) return DoubleToString(v,0);
   if(MathAbs(MathMod(v,1000.0))<1e-6) return IntegerToString((long)MathRound(v/1000.0))+"K";
   return DoubleToString(v/1000.0,1)+"K";
}

// 回撤預算對應的層數：剛觸發第 N 層時，整條鏈浮虧 ≥ DDBudget 的最小 N
int BudgetLayer()
{
   if(DDBudget<=0) return -1;
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE), ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0 || ts<=0) return -1;
   double k=tv/ts;                    // 1 手 × 價格變動 1.0 的盈虧（帳戶貨幣）
   double sl=0, slo=0;
   for(int N=0;N<400;N++)
   {
      double lot=(N<g_vk) ? 0.0 : LotForLayer(N), off=LevelOff(N);   // v1.78 虛擬層不佔浮虧
      sl+=lot; slo+=lot*off;
      if((off*sl-slo)*k >= DDBudget) return N;
   }
   return 400;
}

// 金額相對預算的顏色：一般／過半（黃）／八成以上（橘）
uint FracColor(double frac,uint normal)
{
   if(frac>=0.8) return T_NEG;
   if(frac>=0.5) return T_WARN;
   return normal;
}

// ── v1.82 新面板（黑金，1040×570）：底圖 DCDY_bg.bmp（已編進 EX5）＋動態數值疊字 ──
// 文字用「垂直置中」輸出：cy＝文字中線、E＝字高（基準像素），內部換成字型格高 E×1.2
void NTxt(double x,double cy,string s,uint c,string font,double E,int ha=0,bool bold=false,double sp=0,bool glow=false)
{
   double S=E*1.2;
   PTxt(x,cy-S*0.5,s,c,font,S,ha,bold,sp,glow);
}
double NTxtW(string s,string font,double E,bool bold,double sp=0){ return PTxtW(s,font,E*1.2,bold,sp); }

double CardY(int side){ return side==0 ? 103 : 313; }

// 層數儀表：圓心 (469, 卡片y+98)，從左下 225° 順時針掃 270° 到右下（0°＝正上方）
#define GA_X     469.0
#define GA_DY    98.0
#define GA_R     47.0       // 進度弧半徑
#define GA_T     6.0        // 進度弧粗細
#define GA_A0    225.0
#define GA_SW    270.0
// 儀表滿格層數：預算線後再多 6 層，最少 52、最多 80（沿用原階梯條規則）
void LadderSize()
{
   int n=(g_budgetL>=0) ? g_budgetL+6 : 52;
   if(n<52) n=52;
   if(n>80) n=80;
   g_ladN=n;
}
double GaAng(double layers){ return GA_A0+GA_SW*MathMax(0.0,MathMin(1.0,layers/g_ladN)); }
void GaArc(int side,double l0,double l1,uint c)
{
   if(l1<=l0) return;
   double cy=CardY(side)+GA_DY;
   g_cv.DcArc(PX(GA_X),PY(cy),PD(GA_R),PD(GA_T),GaAng(l0),GaAng(l1),c);
}

// 回撤預算條（x 58～357、y 466～472）
double BudPos(double frac){ return 58+299.0*MathMax(0.0,MathMin(1.0,frac)); }

// 底圖：BMP 縮放到目前面板大小後快取（2×2 取樣，只在建立面板時做一次）
uint g_bgPix[];
int  g_bgW=0, g_bgH=0;
bool g_bgOK=false;
bool BgLoad()
{
   uint src[]; uint sw=0, sh=0;
   if(!ResourceReadImage(BG_RES,src,sw,sh)) return false;
   if(sw<200 || sh<100 || ArraySize(src)<(int)(sw*sh)) return false;
   int tw=(int)MathRound(PD(PNL_W)), th=(int)MathRound(PD(PNL_H));
   if(tw<100 || th<50) return false;
   ArrayResize(g_bgPix,tw*th);
   double kx=(double)sw/tw, ky=(double)sh/th;
   for(int y=0;y<th;y++)
      for(int x=0;x<tw;x++)
      {
         uint sr=0, sg=0, sb=0;
         for(int t=0;t<4;t++)
         {
            int ix=(int)((x+((t&1)!=0 ? 0.75 : 0.25))*kx);
            int iy=(int)((y+((t&2)!=0 ? 0.75 : 0.25))*ky);
            if(ix>=(int)sw) ix=(int)sw-1;
            if(iy>=(int)sh) iy=(int)sh-1;
            uint p=src[iy*(int)sw+ix];
            sr+=(p>>16)&0xFF; sg+=(p>>8)&0xFF; sb+=p&0xFF;
         }
         g_bgPix[y*tw+x]=0xFF000000|((sr/4)<<16)|((sg/4)<<8)|(sb/4);
      }
   g_bgW=tw; g_bgH=th;
   return true;
}

// 讀不到底圖時的簡易底板（只有色塊、框線與標題）
void FbBox(double x,double y,double w,double h,double r,uint c)
{
   g_cv.DcFillRR(PX(x),PY(y),PD(w),PD(h),PD(r),c);
   g_cv.DcStrokeRR(PX(x),PY(y),PD(w),PD(h),PD(r),WithA(T_A1,150),1.0);
}

// 靜態圖層：底圖、預算條軌道、兩個儀表的底弧與危險區
void PanelBuildStatic()
{
   g_cv.Erase(0);
   LadderSize();
   double ox=PX(0), oy=PY(0), pw=PD(PNL_W), ph=PD(PNL_H), rc=PD(12);
   if(PanelGlow) g_cv.DcGlowRR(ox,oy,pw,ph,rc,T_HALO,g_mg);
   if(g_bgOK) g_cv.DcBlit(g_bgPix,g_bgW,g_bgH,(int)MathRound(ox),(int)MathRound(oy),rc);
   else
   {
      g_cv.DcFillRR(ox,oy,pw,ph,rc,T_BG);
      g_cv.DcStrokeRR(ox,oy,pw,ph,rc,T_A1,1.5);
      FbBox(43,103,329,311,8,DCARGB(255,217,184,112));
      FbBox(43,427,329,83,8,T_CARD);
      FbBox(393,103,355,197,8,T_CARD); FbBox(393,313,355,197,8,T_CARD);
      FbBox(768,103,230,407,8,T_CARD);
      NTxt(110,39,"多財多億",T_A1,F_TTL,28,0,true,8);
      NTxt(66,137,"今日獲利",T_HEROTX,F_TXT,15,0,true,4);
      NTxt(57,448,"回撤預算",T_A2,F_TXT,13,0,true,3);
      NTxt(57,490,"目前浮虧",T_A2,F_TXT,12);
      string lb[4]={"淨值","浮動盈虧","今日最大回撤","歷史最大回撤"};
      for(int i=0;i<4;i++) NTxt(797,135+102*i,lb[i],T_A2,F_TXT,12.5,0,true,2);
      for(int s=0;s<2;s++)
      {
         double y=CardY(s); uint lc=(s==0)?T_SUB:T_SHORT;
         NTxt(573,y+45,(s==0)?"多鏈":"空鏈",(s==0)?T_A1:T_SHORT,F_TTL,19,0,true,5);
         NTxt(547,y+86,"均價",lc,F_TXT,11.5); NTxt(644,y+86,"止盈",lc,F_TXT,11.5);
         NTxt(547,y+134,"距離",lc,F_TXT,11.5); NTxt(644,y+134,"浮動",lc,F_TXT,11.5);
         NTxt(GA_X,y+GA_DY+18,"LEVEL",lc,F_NUM,10.5,1,true,2);
      }
   }

   // 回撤預算條軌道（最後 20% 帶紅色警戒）
   g_cv.DcFillRR(PX(58),PY(466),PD(299),PD(6),PD(3),T_OFF);
   g_cv.DcFillRR(PX(58+299*0.8),PY(466),PD(299*0.2),PD(6),PD(3),WithA(T_NEG,80));

   // 兩個儀表的底弧（暗）＋預算線之後的危險區（紅）
   for(int s=0;s<2;s++)
   {
      uint tc=(s==0)?DCARGB(60,212,175,95):DCARGB(50,206,207,212);
      GaArc(s,0,(g_budgetL>=0)?g_budgetL:g_ladN,tc);
      if(g_budgetL>=0) GaArc(s,g_budgetL,g_ladN,WithA(T_NEG,110));
   }
   g_cv.SnapTo(g_cvStatic);
}

// 一像素細線（基準座標）
void VLine(double x,double y0,double y1,uint c){ g_cv.DcRect(MathRound(PX(x)),PY(y0),1.0,PD(y1-y0),c); }

// 面板縮放：PanelScale>0 用手動值；0＝依螢幕 DPI，且不超出圖表視窗（v1.69）
double CalcPanelScale()
{
   double sc=PanelScale;
   if(sc>0) return MathMax(0.5,MathMin(3.0,sc));
   int dpi=(int)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   sc=(dpi>0) ? dpi/96.0 : 1.0;
   long chH=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   long chW=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   double baseW=PNL_W+24.0, baseH=PNL_H+24.0;
   if(chH>0){ double f=(chH-PanelY-4)/baseH; if(f<sc) sc=f; }
   if(chW>0){ double f=(chW-PanelX-4)/baseW; if(f<sc) sc=f; }
   return MathMax(0.5,MathMin(3.0,sc));
}

bool PanelCreate()
{
   PanelThemeSet();
   g_ps=CalcPanelScale();
   g_fs=MathMax(0.7,MathMin(1.4,FontScale));
   g_mg=(int)MathRound(12*g_ps);
   ObjectsDeleteAll(0,PFX);                                   // 清掉舊版面板物件
   int w=(int)MathRound(PNL_W*g_ps)+2*g_mg, h=(int)MathRound(PNL_H*g_ps)+2*g_mg;
   if(!g_cv.CreateBitmapLabel(PFX+"CV",PanelX,PanelY,w,h,COLOR_FORMAT_ARGB_NORMALIZE))
   { Print("面板建立失敗（CCanvas）"); return false; }
   ObjectSetInteger(0,PFX+"CV",OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PFX+"CV",OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PFX+"CV",OBJPROP_BACK,false);
   ObjectSetInteger(0,PFX+"CV",OBJPROP_ZORDER,100);
   g_cvOK=true;
   g_bgOK=BgLoad();
   if(!g_bgOK) Print("面板底圖讀取失敗（DCDY_bg.bmp），改用簡易底板");
   g_budgetL=BudgetLayer(); g_budgetT=TimeCurrent();
   PanelBuildStatic();
   return true;
}

void PanelDestroy()
{
   if(g_cvOK){ g_cv.Destroy(); g_cvOK=false; }
}

// v1.78 面板用：有真實單看真實鏈；只有虛擬層時回傳虛擬鏈（手數、浮動為 0）
bool ChainView(int side,int &maxL,double &anchor,double &avg,double &lots,double &pnl)
{
   if(ChainState(side,maxL,anchor,avg,lots,pnl)) return true;
   if(!g_vlOn[side]) return false;
   VirtState(side,maxL,anchor,avg); lots=0; pnl=0;
   return true;
}

void DrawChainCard(int side)
{
   double y=CardY(side);
   uint cc=(side==0)?T_LONG:T_SHORT;
   int maxL; double anchor,avg,lots,pnl;
   bool on=ChainView(side,maxL,anchor,avg,lots,pnl);
   bool virt=(on && lots<=0 && g_vlOn[side]);

   // ── 左邊層數儀表：進度弧（超過預算線的部分改紅）＋中央層數＋危線 ──
   if(on)
   {
      double shown=MathMin((double)(maxL+1),(double)g_ladN);
      double bl=(g_budgetL>=0) ? (double)g_budgetL : (double)g_ladN;
      int    a=virt ? 120 : 255;                                     // v1.78 只有虛擬層時以暗色表示
      GaArc(side,0,MathMin(shown,bl),WithA(cc,a));
      if(shown>bl) GaArc(side,bl,shown,WithA(T_NEG,a));
   }
   NTxt(GA_X,y+GA_DY-9,on?IntegerToString(maxL):"—",on?T_TX:T_DIM,F_SER,40,1,true);
   if(g_budgetL>=0) NTxt(GA_X,y+GA_DY+51,StringFormat("危線 %d",g_budgetL),T_NEG,F_TXT,11.5,1,true);

   // ── 狀態膠囊（卡片右上角）──
   string st="待機"; uint sc=T_DIM;
   if(!on && EdgeBlocked(side)) { st=(side==0)?"近低點暫停":"近高點暫停"; sc=T_WARN; }   // v1.80
   if(on)
   {
      st="運行中"; sc=cc;
      if(virt)                                                         { st="虛擬層";   sc=T_SUB; }   // v1.78
      else if(g_closing[side])                                         { st="收網中";   sc=T_A2; }
      else if(g_frozen[side])                                          { st=g_frozenVel[side]?"急速凍結":"新聞凍結"; sc=T_WARN; }
      else if(g_pending[side]>0)                                       { st=StringFormat("補格中 %d",g_pending[side]); sc=T_WARN; }
      else if(TimeCurrent()-g_lastAdd[side]<AddCooldownSec && maxL>=1) { st=StringFormat("冷卻 %ds",(int)(AddCooldownSec-(TimeCurrent()-g_lastAdd[side]))); sc=cc; }
   }
   double tgw=NTxtW(st,F_TXT,10.5,true,0)+16, px0=730-tgw;
   g_cv.DcFillRR(PX(px0),PY(y+10),PD(tgw),PD(17),PD(8.5),WithA(sc,40));
   g_cv.DcStrokeRR(PX(px0),PY(y+10),PD(tgw),PD(17),PD(8.5),WithA(sc,170),1.0);
   NTxt(px0+tgw/2.0,y+18.5,st,sc,F_TXT,10.5,1,true);

   // ── 手數（標題列右邊）：數字＋「手」，太長時縮小避免壓到鏈名 ──
   double uw=NTxtW("手",F_TXT,12,false,0);
   if(on)
   {
      string ls=StringFormat("%.2f",lots);
      double lE=17, lim=730-uw-4-640;
      while(lE>11 && NTxtW(ls,F_NUM,lE,true,0)>lim) lE-=1;
      NTxt(730,y+46,"手",T_SUB,F_TXT,12,2);
      NTxt(730-uw-4,y+45,ls,T_TX,F_NUM,lE,2,true);
   }
   else NTxt(730,y+45,"—",T_DIM,F_NUM,16,2,true);

   // ── 均價／止盈／距離／浮動 ──
   double tp   = on ? ((side==0)?avg+TPDist(side,maxL):avg-TPDist(side,maxL)) : 0;
   double dist = on ? ((side==0)? tp-SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK)-tp) : 0;
   string tpx = g_tpDeferred[side] ? "(虛擬)" : ((on && DeepTPLayer>0 && DeepTPUsd>0 && maxL>=DeepTPLayer) ? "(深層)" : "");
   if(tpx!="") NTxt(672,y+86,tpx,T_DIM,F_TXT,10.5);
   NTxt(547,y+108,on?DoubleToString(avg,_Digits):"—",on?T_TX:T_DIM,F_NUM,18,0,true);
   NTxt(644,y+108,on?DoubleToString(tp,_Digits):"—",on?T_A2:T_DIM,F_NUM,18,0,true);
   NTxt(547,y+156,on?StringFormat("%.2f",dist):"—",on?T_TX:T_DIM,F_NUM,18,0,true);
   NTxt(644,y+156,on?Signed(pnl,(MathAbs(pnl)>=10000)?0:2):"—",on?(pnl>=0?T_POS:T_GRN):T_DIM,F_NUM,18,0,true);
}

// 預算條上的刻度（今日最大、歷史最大）：條上方一顆菱形＋穿過條的細線
void BudgetTick(double frac,uint c)
{
   if(frac<=0) return;
   double x=BudPos(frac);
   g_cv.DcRect(MathRound(PX(x)),PY(461),1.0,PD(16),c);
   g_cv.DcDiamond(PX(x)+0.5,PY(458),PD(3.5),c);
}

// 右側四格數值的一格：idx 0～3（標題在底圖上）；extra＝標題右邊的小字
void StatCell(int idx,string val,uint vc,string extra)
{
   double y=135+102*idx;
   if(extra!="") NTxt(982,y,extra,T_SUB,F_NUM,12.5,2);
   double E=34;
   while(E>20 && NTxtW(val,F_SER,E,true,0)>197) E-=1;
   NTxt(785,y+28,val,vc,F_SER,E,0,true);
}

void PushTok(string &a[],string s){ int n=ArraySize(a); ArrayResize(a,n+1); a[n]=s; }

void DrawPanel()
{
   if(!ShowPanel) return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   if(g_cvOK && GetTickCount()-g_panelTick < 200) return;
   g_panelTick=GetTickCount();
   if(!g_cvOK && !PanelCreate()) return;

   // 預算層數每 60 秒重算
   if(TimeCurrent()-g_budgetT>=60)
   {
      g_budgetT=TimeCurrent();
      int bl=BudgetLayer();
      if(bl!=g_budgetL){ g_budgetL=bl; PanelBuildStatic(); }
   }
   g_cv.LoadFrom(g_cvStatic);
   DayPnlUpdate();

   datetime now=TimeCurrent();
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY), fl=eq-bal;

   // ── 標題列：品種／版本、右上狀態鈕、時間、新聞訊息 ──
   NTxt(111,63,_Symbol+" · V1.93",T_A2,F_NUM,11,0,true,4);

   string st="RUNNING"; uint sc=T_A1;
   if(g_tpDeferred[0]||g_tpDeferred[1]) { st="THROTTLE"; sc=T_WARN; }
   if(NewsBlocked())                    { st="NEWS";     sc=T_WARN; }
   if(NewsFreeze() || g_frozenVel[0] || g_frozenVel[1]) { st="FREEZE"; sc=T_WARN; }
   if(FridayGate())                     { st="FRI GATE"; sc=T_WARN; }
   if(EdgeBlocked(0) || EdgeBlocked(1)) { st="EDGE";     sc=T_WARN; }   // v1.80
   if(RegimeHot() || Regime2Hot())      { st="HOT";      sc=T_WARN; }
   if(g_halted)                         { st="HALTED";   sc=T_NEG;  }
   double cw=NTxtW(st,F_NUM,12,true,3)+46, cx0=998-cw;
   g_cv.DcFillRR(PX(cx0),PY(32),PD(cw),PD(30),PD(3),sc);
   g_cv.DcFillRR(PX(cx0),PY(32),PD(cw),PD(13),PD(3),DCARGB(55,255,255,255));        // 上半高光
   g_cv.DcCircle(PX(cx0+19),PY(47),PD(3.6),T_HEROTX);
   NTxt(cx0+30,47,st,T_HEROTX,F_NUM,12,0,true,3);

   string tm=TimeToString(now,TIME_SECONDS);
   NTxt(cx0-20,47,tm,T_A2,F_NUM,15,2,true,1.5);
   double sx=cx0-20-NTxtW(tm,F_NUM,15,true,1.5)-16;
   VLine(sx,38,56,WithA(T_A1,120));

   string f2; uint f2c=T_SUB;
   if(FridayGate())                          { f2="週五收盤前 · 不開新鏈，有獲利即出場"; f2c=T_WARN; }
   else if(RegimeHot())                      { f2=StringFormat("行情過熱 · %d 小時區間 %.0f 美元，暫停開新鏈",RegimeHours,RegimeRange()); f2c=T_WARN; }
   else if(Regime2Hot() && HotModeOn())      { f2=StringFormat("長期波動過熱 · 區間 %.1f%%，新鏈改用寬格距 ×%.1f、手數 ×%.1f",Regime2RangePct(),HotGridMul,(HotLotMul>0?HotLotMul:1.0)); f2c=T_WARN; }   // v1.81
   else if(Regime2Hot())                     { f2=StringFormat("長期波動過熱 · %d 根 H1 區間 %.1f%%，暫停開新鏈",Regime2Hours,Regime2RangePct()); f2c=T_WARN; }   // v1.80
   else if(EdgeBlocked(1))                   { f2=StringFormat("接近高點（差 %.1f%%）· 暫停開新空鏈",EdgeDistPct(1)); f2c=T_WARN; }
   else if(EdgeBlocked(0))                   { f2=StringFormat("接近低點（差 %.1f%%）· 暫停開新多鏈",EdgeDistPct(0)); f2c=T_WARN; }
   else if(EdgeHours>0 && EdgePct>0 && !EdgeBlockLow && EdgeDistPct(0)>=0 && EdgeDistPct(0)<EdgePct)
                                             { f2=StringFormat("接近低點（差 %.1f%%）· 低點過濾已關，照常開多鏈",EdgeDistPct(0)); f2c=T_SUB; }   // v1.84
   else if(NewsFreeze())                     { f2=StringFormat("新聞凍結加倉中 · %d 分鐘內不加倉",NewsFreezeAfterMin); f2c=T_WARN; }
   else if(g_frozenVel[0]||g_frozenVel[1])   { f2=StringFormat("逆向凍結 · %d 分鐘 > $%.0f 或 %d 分鐘 > $%.0f，暫停加倉",VelWinMin,VelUsd,Vel2WinMin,Vel2Usd); f2c=T_WARN; }
   else if(NewsBlocked())                    { f2=NewsStatusText(); f2c=T_WARN; }
   else if(g_tpDeferred[0]||g_tpDeferred[1]) { f2="改單已達上限 · 暫由虛擬 TP 保底"; f2c=T_WARN; }
   else                                       f2=NewsStatusText();
   double room=sx-16-300;                                    // 左邊不要壓到標題
   while(StringLen(f2)>4 && NTxtW(f2,F_TXT,13,false,0)>room) f2=StringSubstr(f2,0,StringLen(f2)-2)+"…";
   NTxt(sx-16,47,f2,f2c,F_TXT,13,2);

   // ── 今日獲利（金條色塊；標題、外框在底圖上）──
   double dp=g_dayPnl;
   string hs=(MathAbs(dp)>=100000) ? Signed(dp,0) : Signed(dp,2);
   double base0=bal-dp;
   double pct=(base0>0) ? dp/base0*100.0 : 0.0;
   double E=66;
   while(E>30 && NTxtW(hs,F_SER,E,true,0)>282) E-=2;
   NTxt(66,226,hs,T_HEROTX,F_SER,E,0,true);
   NTxt(66,318,StringFormat("%s%.2f%%",(pct>0?"+":""),pct),T_HEROTX,F_NUM,15,0,true);
   double rx=348;
   NTxt(rx,319,"筆",T_HEROTX,F_TXT,13,2,true);
   rx-=NTxtW("筆",F_TXT,13,true,0)+4;
   string dn=IntegerToString(g_dayDeals);
   NTxt(rx,316,dn,T_HEROTX,F_SER,22,2,true);
   rx-=NTxtW(dn,F_SER,22,true,0)+4;
   NTxt(rx,319,"成交",T_HEROTX,F_TXT,13,2,true);

   // ── 右側四格數值 ──
   double dayFrac=(DDBudget>0)?g_dayMaxDDAmt/DDBudget:0;
   StatCell(0,Money(eq,0),T_TX,"餘額 "+Money(bal,0));
   StatCell(1,(MathAbs(fl)>=10000)?Signed(fl,0):Signed(fl),(fl>=0)?T_A2:T_GRN,"");
   StatCell(2,Money(g_dayMaxDDAmt,0),FracColor(dayFrac,T_TX),(g_dayMaxDDT>0 && g_dayMaxDDAmt>0)?TimeToString(g_dayMaxDDT,TIME_MINUTES):"");
   StatCell(3,Money(g_histMaxDDAmt,0),T_TX,StringFormat("%.1f%%",g_histMaxDDPct));

   // ── 回撤預算條：目前浮虧填色，刻度＝今日最大（白）／歷史最大（暗金）──
   double loss=MathMax(0.0,-fl);
   double frac=(DDBudget>0)?loss/DDBudget:0;
   NTxt(357,448,StringFormat("使用 %.1f%%  ·  %s",frac*100,KFmt(DDBudget)),T_SUB,F_TXT,12.5,2);
   double fw=299.0*MathMax(0.0,MathMin(1.0,frac));
   if(fw>0) g_cv.DcFillRR(PX(58),PY(466),PD(MathMax(fw,6.0)),PD(6),PD(3),FracColor(frac,T_GRN));
   if(DDBudget>0)
   {
      BudgetTick(g_histMaxDDAmt/DDBudget,DCARGB(255,141,115,64));
      BudgetTick(dayFrac,T_TX);
   }
   NTxt(108,490,Money(loss,0),(loss>0)?T_GRN:T_SUB,F_NUM,13,0,true);

   // ── 多空鏈卡片 ──
   DrawChainCard(0);
   DrawChainCard(1);

   // ── 頁尾參數膠囊 ──
   string tpm = TPMode==0 ? "VTP" : (TPMode==1 ? "SRV TP" : StringFormat("MOD %02d/%d",ModsLastMinute(),MaxModsPerMin));
   string es  = EarlyStepUsd>0 ? StringFormat("(%d@%.2f)",EarlyLayers,EarlyStepUsd) : "";
   string tps = TPAtrMult>0 ? StringFormat("ATRx%.2f",TPAtrMult) : DoubleToString(ChainTargetUsd,2);
   string tk[];
   PushTok(tk,StringFormat("GRID %.2f%s",GridStepUsd,es));
   PushTok(tk,"TP "+tps);
   PushTok(tk,tpm);
   if(RecycleLayer>0) PushTok(tk,StringFormat("RCY L%d",RecycleLayer));
   if(g_vk>0 || HotVirtualLayers>0 || TBVirtualLayers>0) PushTok(tk,StringFormat("VL%d/H%d/T%d",g_vk,HotVirtualLayers>=0?HotVirtualLayers:g_vk,TBVirtualLayers>=0?TBVirtualLayers:g_vk)); // v1.93
   if((Regime2Hours>0 && Regime2Pct>0) || (EdgeHours>0 && EdgePct>0)) PushTok(tk,"SAFE");   // v1.80
   if(HotModeOn() && Regime2Hours>0 && Regime2Pct>0) PushTok(tk,"WIDE");                    // v1.81
   if(TrendBoostLayer>0 && TrendBoostLotMul>1.0) PushTok(tk,(TrendBoostFrontLot>0 && TrendBoostFrontLayers>0)?"TB+":"TB");   // v1.82
   if(!EdgeBlockLow && EdgeHours>0 && EdgePct>0) PushTok(tk,"LOW-OK");      // v1.84
   double fx=43;
   for(int i=0;i<ArraySize(tk);i++)
   {
      double tw=NTxtW(tk[i],F_NUM,12,true,1.2)+22;
      if(fx+tw>850) break;
      g_cv.DcFillRR(PX(fx),PY(533),PD(tw),PD(19),PD(3),DCARGB(200,16,14,11));
      g_cv.DcStrokeRR(PX(fx),PY(533),PD(tw),PD(19),PD(3),WithA(T_A1,150),1.0);
      NTxt(fx+11,542.5,tk[i],T_A2,F_NUM,12,0,true,1.2);
      fx+=tw+7;
   }

   g_cv.Update(true);
}


//+------------------------------------------------------------------+
//| v1.50 新聞過濾                                                   |
//|  實盤：讀 MT5 經濟日曆（伺服器時間），每 30 分鐘更新               |
//|  回測：測試器沒有日曆，改讀 Common\Files\<NewsFile>（腳本匯出）    |
//+------------------------------------------------------------------+
datetime g_newsT[];
string   g_newsN[];
datetime g_newsLoaded=0;
bool     g_newsFromFile=false;

bool NewsKeywordHit(string name)
{
   string ks[]; int n=StringSplit(NewsKeywords,',',ks);
   string up=name; StringToUpper(up);
   for(int i=0;i<n;i++)
   {
      string k=ks[i]; StringTrimLeft(k); StringTrimRight(k); if(k=="") continue;
      StringToUpper(k);
      if(StringFind(up,k)>=0) return true;
   }
   return false;
}

void NewsAdd(datetime t,string name)
{
   int n=ArraySize(g_newsT);
   for(int i=0;i<n;i++) if(g_newsT[i]==t) return;     // 同一時間只記一筆
   ArrayResize(g_newsT,n+1); ArrayResize(g_newsN,n+1);
   g_newsT[n]=t; g_newsN[n]=name;
}


// v1.62 內建 2025 年美國重大新聞（美東時間）：非農、CPI、PPI、零售銷售、GDP 初值、PCE、FOMC
//       10～11 月政府停擺期間延後公布的數據已依實際公布日調整；如需完整清單請用 DC_ExportNews 匯出（NewsSource=2）
string NEWS_2025[] = {
   "2025.01.10 08:30|非農就業 NFP",
   "2025.01.14 08:30|PPI 生產者物價",
   "2025.01.15 08:30|CPI 消費者物價",
   "2025.01.16 08:30|零售銷售",
   "2025.01.29 14:00|FOMC 利率決議",
   "2025.01.30 08:30|GDP 初值",
   "2025.01.31 08:30|PCE 個人消費支出",
   "2025.02.07 08:30|非農就業 NFP",
   "2025.02.12 08:30|CPI 消費者物價",
   "2025.02.13 08:30|PPI 生產者物價",
   "2025.02.14 08:30|零售銷售",
   "2025.02.28 08:30|PCE 個人消費支出",
   "2025.03.07 08:30|非農就業 NFP",
   "2025.03.12 08:30|CPI 消費者物價",
   "2025.03.13 08:30|PPI 生產者物價",
   "2025.03.17 08:30|零售銷售",
   "2025.03.19 14:00|FOMC 利率決議",
   "2025.03.28 08:30|PCE 個人消費支出",
   "2025.04.04 08:30|非農就業 NFP",
   "2025.04.10 08:30|CPI 消費者物價",
   "2025.04.11 08:30|PPI 生產者物價",
   "2025.04.16 08:30|零售銷售",
   "2025.04.30 08:30|GDP 初值 / PCE 個人消費支出",
   "2025.05.02 08:30|非農就業 NFP",
   "2025.05.07 14:00|FOMC 利率決議",
   "2025.05.13 08:30|CPI 消費者物價",
   "2025.05.15 08:30|PPI 生產者物價 / 零售銷售",
   "2025.05.30 08:30|PCE 個人消費支出",
   "2025.06.06 08:30|非農就業 NFP",
   "2025.06.11 08:30|CPI 消費者物價",
   "2025.06.12 08:30|PPI 生產者物價",
   "2025.06.17 08:30|零售銷售",
   "2025.06.18 14:00|FOMC 利率決議",
   "2025.06.27 08:30|PCE 個人消費支出",
   "2025.07.03 08:30|非農就業 NFP",
   "2025.07.15 08:30|CPI 消費者物價",
   "2025.07.16 08:30|PPI 生產者物價",
   "2025.07.17 08:30|零售銷售",
   "2025.07.30 08:30|GDP 初值",
   "2025.07.30 14:00|FOMC 利率決議",
   "2025.07.31 08:30|PCE 個人消費支出",
   "2025.08.01 08:30|非農就業 NFP",
   "2025.08.12 08:30|CPI 消費者物價",
   "2025.08.14 08:30|PPI 生產者物價",
   "2025.08.15 08:30|零售銷售",
   "2025.08.29 08:30|PCE 個人消費支出",
   "2025.09.05 08:30|非農就業 NFP",
   "2025.09.10 08:30|PPI 生產者物價",
   "2025.09.11 08:30|CPI 消費者物價",
   "2025.09.16 08:30|零售銷售",
   "2025.09.17 14:00|FOMC 利率決議",
   "2025.09.26 08:30|PCE 個人消費支出",
   "2025.10.24 08:30|CPI 消費者物價",
   "2025.10.29 14:00|FOMC 利率決議",
   "2025.11.20 08:30|非農就業 NFP",
   "2025.11.25 08:30|PPI 生產者物價 / 零售銷售",
   "2025.12.05 08:30|PCE 個人消費支出",
   "2025.12.10 14:00|FOMC 利率決議",
   "2025.12.16 08:30|零售銷售 / 非農就業 NFP",
   "2025.12.18 08:30|CPI 消費者物價",
   "2025.12.23 08:30|GDP 初值"
};

// 內建 2026 年美國重大新聞（美東時間），來源：BLS、BEA、Federal Reserve、Census 官方發布日程
string NEWS_2026[] = {
   "2026.01.07 10:00|JOLTS 職缺",
   "2026.01.09 08:30|非農就業 NFP",
   "2026.01.13 08:30|CPI 消費者物價",
   "2026.01.14 08:30|PPI 生產者物價 / 零售銷售",
   "2026.01.22 08:30|GDP",
   "2026.01.22 10:00|PCE 個人消費支出",
   "2026.01.28 14:00|FOMC 利率決議",
   "2026.01.30 08:30|PPI 生產者物價",
   "2026.02.05 10:00|JOLTS 職缺",
   "2026.02.10 08:30|零售銷售",
   "2026.02.11 08:30|非農就業 NFP",
   "2026.02.13 08:30|CPI 消費者物價",
   "2026.02.20 08:30|PCE 個人消費支出 / GDP",
   "2026.02.27 08:30|PPI 生產者物價",
   "2026.03.06 08:30|非農就業 NFP / 零售銷售",
   "2026.03.11 08:30|CPI 消費者物價",
   "2026.03.13 08:30|PCE 個人消費支出 / GDP",
   "2026.03.13 10:00|JOLTS 職缺",
   "2026.03.18 08:30|PPI 生產者物價",
   "2026.03.18 14:00|FOMC 利率決議",
   "2026.03.31 10:00|JOLTS 職缺",
   "2026.04.01 08:30|零售銷售",
   "2026.04.03 08:30|非農就業 NFP",
   "2026.04.09 08:30|PCE 個人消費支出 / GDP",
   "2026.04.10 08:30|CPI 消費者物價",
   "2026.04.14 08:30|PPI 生產者物價",
   "2026.04.21 08:30|零售銷售",
   "2026.04.29 14:00|FOMC 利率決議",
   "2026.04.30 08:30|PCE 個人消費支出 / GDP",
   "2026.05.05 10:00|JOLTS 職缺",
   "2026.05.08 08:30|非農就業 NFP",
   "2026.05.12 08:30|CPI 消費者物價",
   "2026.05.13 08:30|PPI 生產者物價",
   "2026.05.14 08:30|零售銷售",
   "2026.05.28 08:30|PCE 個人消費支出 / GDP",
   "2026.06.02 10:00|JOLTS 職缺",
   "2026.06.05 08:30|非農就業 NFP",
   "2026.06.10 08:30|CPI 消費者物價",
   "2026.06.11 08:30|PPI 生產者物價",
   "2026.06.17 08:30|零售銷售",
   "2026.06.17 14:00|FOMC 利率決議",
   "2026.06.25 08:30|PCE 個人消費支出 / GDP",
   "2026.06.30 10:00|JOLTS 職缺",
   "2026.07.02 08:30|非農就業 NFP",
   "2026.07.14 08:30|CPI 消費者物價",
   "2026.07.15 08:30|PPI 生產者物價",
   "2026.07.16 08:30|零售銷售",
   "2026.07.29 14:00|FOMC 利率決議",
   "2026.07.30 08:30|PCE 個人消費支出 / GDP",
   "2026.08.04 10:00|JOLTS 職缺",
   "2026.08.07 08:30|非農就業 NFP",
   "2026.08.12 08:30|CPI 消費者物價",
   "2026.08.13 08:30|PPI 生產者物價",
   "2026.08.14 08:30|零售銷售",
   "2026.08.26 08:30|PCE 個人消費支出 / GDP",
   "2026.09.01 10:00|JOLTS 職缺",
   "2026.09.04 08:30|非農就業 NFP",
   "2026.09.10 08:30|PPI 生產者物價",
   "2026.09.11 08:30|CPI 消費者物價",
   "2026.09.16 08:30|零售銷售",
   "2026.09.16 14:00|FOMC 利率決議",
   "2026.09.29 10:00|JOLTS 職缺",
   "2026.09.30 08:30|PCE 個人消費支出 / GDP",
   "2026.10.02 08:30|非農就業 NFP",
   "2026.10.14 08:30|CPI 消費者物價",
   "2026.10.15 08:30|PPI 生產者物價 / 零售銷售",
   "2026.10.28 14:00|FOMC 利率決議",
   "2026.10.29 08:30|PCE 個人消費支出 / GDP",
   "2026.11.03 10:00|JOLTS 職缺",
   "2026.11.06 08:30|非農就業 NFP",
   "2026.11.10 08:30|CPI 消費者物價",
   "2026.11.13 08:30|PPI 生產者物價",
   "2026.11.17 08:30|零售銷售",
   "2026.11.25 08:30|PCE 個人消費支出 / GDP",
   "2026.12.01 10:00|JOLTS 職缺",
   "2026.12.04 08:30|非農就業 NFP",
   "2026.12.09 14:00|FOMC 利率決議",
   "2026.12.10 08:30|CPI 消費者物價",
   "2026.12.15 08:30|PPI 生產者物價",
   "2026.12.16 08:30|零售銷售",
   "2026.12.23 08:30|PCE 個人消費支出 / GDP"
};

// v1.73 內建 2027 年美國重大新聞（美東時間）：非農、CPI、PPI 取自 BLS 2027 發布日程，FOMC 取自聯準會 2027 會議日程
// v1.84：2027 依官方時程重建（BLS 2026/10–11 公布的 NFP／CPI／PPI／JOLTS、Census 零售銷售、BEA PCE／GDP、
//        Fed 2026/11/12 修訂的 FOMC：10/26–27 改為策略會議不公布利率、12 月會議移到 11/16–17）；時間為美東時間
string NEWS_2027[] = {
   "2027.01.05 10:00|JOLTS 職缺",
   "2027.01.08 08:30|非農就業 NFP",
   "2027.01.13 08:30|CPI 消費者物價",
   "2027.01.14 08:30|PPI 生產者物價",
   "2027.01.15 08:30|零售銷售",
   "2027.01.27 14:00|FOMC 利率決議",
   "2027.01.28 08:30|PCE 個人消費支出 / GDP",
   "2027.02.02 10:00|JOLTS 職缺",
   "2027.02.05 08:30|非農就業 NFP",
   "2027.02.11 08:30|CPI 消費者物價",
   "2027.02.12 08:30|PPI 生產者物價",
   "2027.02.17 08:30|零售銷售",
   "2027.02.25 08:30|PCE 個人消費支出",
   "2027.03.05 08:30|非農就業 NFP",
   "2027.03.09 10:00|JOLTS 職缺",
   "2027.03.10 08:30|CPI 消費者物價",
   "2027.03.12 08:30|PPI 生產者物價",
   "2027.03.16 08:30|零售銷售",
   "2027.03.17 14:00|FOMC 利率決議",
   "2027.03.30 10:00|JOLTS 職缺",
   "2027.03.31 08:30|PCE 個人消費支出",
   "2027.04.02 08:30|非農就業 NFP",
   "2027.04.13 08:30|CPI 消費者物價",
   "2027.04.14 08:30|PPI 生產者物價",
   "2027.04.16 08:30|零售銷售",
   "2027.04.28 14:00|FOMC 利率決議",
   "2027.04.29 08:30|PCE 個人消費支出 / GDP",
   "2027.05.04 10:00|JOLTS 職缺",
   "2027.05.07 08:30|非農就業 NFP",
   "2027.05.12 08:30|CPI 消費者物價",
   "2027.05.13 08:30|PPI 生產者物價",
   "2027.05.14 08:30|零售銷售",
   "2027.05.27 08:30|PCE 個人消費支出",
   "2027.06.02 10:00|JOLTS 職缺",
   "2027.06.04 08:30|非農就業 NFP",
   "2027.06.09 14:00|FOMC 利率決議",
   "2027.06.10 08:30|CPI 消費者物價",
   "2027.06.11 08:30|PPI 生產者物價",
   "2027.06.16 08:30|零售銷售",
   "2027.06.25 08:30|PCE 個人消費支出",
   "2027.06.29 10:00|JOLTS 職缺",
   "2027.07.02 08:30|非農就業 NFP",
   "2027.07.14 08:30|CPI 消費者物價",
   "2027.07.15 08:30|PPI 生產者物價",
   "2027.07.16 08:30|零售銷售",
   "2027.07.28 14:00|FOMC 利率決議",
   "2027.07.29 08:30|PCE 個人消費支出 / GDP",
   "2027.08.03 10:00|JOLTS 職缺",
   "2027.08.06 08:30|非農就業 NFP",
   "2027.08.10 08:30|PPI 生產者物價",
   "2027.08.11 08:30|CPI 消費者物價",
   "2027.08.16 08:30|零售銷售",
   "2027.08.25 08:30|PCE 個人消費支出",
   "2027.08.31 10:00|JOLTS 職缺",
   "2027.09.03 08:30|非農就業 NFP",
   "2027.09.10 08:30|PPI 生產者物價",
   "2027.09.14 08:30|CPI 消費者物價",
   "2027.09.15 14:00|FOMC 利率決議",
   "2027.09.16 08:30|零售銷售",
   "2027.09.30 08:30|PCE 個人消費支出",
   "2027.10.05 10:00|JOLTS 職缺",
   "2027.10.08 08:30|非農就業 NFP",
   "2027.10.14 08:30|CPI 消費者物價",
   "2027.10.15 08:30|PPI 生產者物價 / 零售銷售",
   "2027.10.28 08:30|PCE 個人消費支出 / GDP",
   "2027.11.02 10:00|JOLTS 職缺",
   "2027.11.05 08:30|非農就業 NFP",
   "2027.11.10 08:30|CPI 消費者物價",
   "2027.11.12 08:30|PPI 生產者物價",
   "2027.11.16 08:30|零售銷售",
   "2027.11.17 14:00|FOMC 利率決議",
   "2027.11.24 08:30|PCE 個人消費支出",
   "2027.12.01 10:00|JOLTS 職缺",
   "2027.12.03 08:30|非農就業 NFP",
   "2027.12.10 08:30|CPI 消費者物價",
   "2027.12.15 08:30|PPI 生產者物價 / 零售銷售",
   "2027.12.22 08:30|PCE 個人消費支出"
};

// v1.86 盲點修補6：美東(ET)與歐夏令券商(GMT+2/+3)在3月中下旬與10月底~11月初有1小時DST錯位，自動校正
int NewsDstAdjSec(datetime et)
{
   MqlDateTime d; TimeToStruct(et,d);
   // 美國3月第2週日~歐洲3月最後週日、歐洲10月最後週日~美國11月第1週日：ET比伺服器快1小時(offset=6而非7)
   if(d.mon==3 && d.day>=8 && d.day<=31)
   {
      MqlDateTime m01; TimeToStruct(StringToTime(StringFormat("%04d.03.01 00:00",d.year)),m01);
      int usStart = 8 + ((7 - m01.day_of_week) % 7);
      MqlDateTime m31; TimeToStruct(StringToTime(StringFormat("%04d.03.31 00:00",d.year)),m31);
      int euEnd = 31 - m31.day_of_week;
      if(d.day>=usStart && d.day<euEnd) return -3600;
   }
   if((d.mon==10 && d.day>=25) || (d.mon==11 && d.day<=7))
   {
      MqlDateTime o31; TimeToStruct(StringToTime(StringFormat("%04d.10.31 00:00",d.year)),o31);
      int euStart = 31 - o31.day_of_week;
      MqlDateTime n01; TimeToStruct(StringToTime(StringFormat("%04d.11.01 00:00",d.year)),n01);
      int usEnd = (n01.day_of_week==0) ? 1 : (8 - n01.day_of_week);
      if((d.mon==10 && d.day>=euStart) || (d.mon==11 && d.day<usEnd)) return -3600;
   }
   return 0;
}
void NewsLoadBuiltin()
{
   for(int i=0;i<ArraySize(NEWS_2025);i++)
   {
      string p[]; if(StringSplit(NEWS_2025[i],'|',p)<2) continue;
      datetime et=StringToTime(p[0]);
      if(et>0) NewsAdd(et+NewsServerOffsetH*3600+NewsDstAdjSec(et),p[1]);
   }
   for(int i=0;i<ArraySize(NEWS_2026);i++)
   {
      string p[]; if(StringSplit(NEWS_2026[i],'|',p)<2) continue;
      datetime et=StringToTime(p[0]);
      if(et>0) NewsAdd(et+NewsServerOffsetH*3600+NewsDstAdjSec(et),p[1]);
   }
   for(int i=0;i<ArraySize(NEWS_2027);i++)                   // v1.73
   {
      string p[]; if(StringSplit(NEWS_2027[i],'|',p)<2) continue;
      datetime et=StringToTime(p[0]);
      if(et>0) NewsAdd(et+NewsServerOffsetH*3600+NewsDstAdjSec(et),p[1]);
   }
}

bool NewsLoadFile()
{
   int h=FileOpen(NewsFile,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(h==INVALID_HANDLE) return false;
   while(!FileIsEnding(h))
   {
      string ts=FileReadString(h); if(FileIsLineEnding(h) && ts=="") continue;
      string imp=FileReadString(h);
      string nm=FileReadString(h);
      while(!FileIsLineEnding(h) && !FileIsEnding(h)) nm+=","+FileReadString(h);
      datetime t=StringToTime(ts);
      if(t<=0) continue;
      int im=(int)StringToInteger(imp);
      if(im>=NewsMinImportance || NewsKeywordHit(nm)) NewsAdd(t,nm);
   }
   FileClose(h);
   return true;
}

void NewsLoadCalendar()
{
   string cs[]; int nc=StringSplit(NewsCurrencies,',',cs);
   datetime from=TimeCurrent()-86400, to=TimeCurrent()+3*86400;
   for(int c=0;c<nc;c++)
   {
      string cur=cs[c]; StringTrimLeft(cur); StringTrimRight(cur); if(cur=="") continue;
      MqlCalendarValue vals[];
      if(CalendarValueHistory(vals,from,to,NULL,cur)<=0) continue;
      for(int i=0;i<ArraySize(vals);i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[i].event_id,ev)) continue;
         int im=(int)ev.importance;                  // 0 無 1 低 2 中 3 高
         if(im>=NewsMinImportance || NewsKeywordHit(ev.name)) NewsAdd(vals[i].time,ev.name);
      }
   }
}

void NewsLoad(bool force=false)
{
   if(!NewsFilter) return;
   datetime now=TimeCurrent();
   bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   if(NewsSource==2)
   {
      if(g_newsLoaded>0 && (tester || now-g_newsLoaded<1800)) return;
      g_newsLoaded=now; ArrayResize(g_newsT,0); ArrayResize(g_newsN,0);
      g_newsFromFile=NewsLoadFile();
      if(!g_newsFromFile){ NewsLoadBuiltin(); PrintFormat("新聞過濾：找不到 Common\\Files\\%s，改用內建新聞表",NewsFile); }
      return;
   }
   if(NewsSource==1 && !tester)
   {
      if(!force && g_newsLoaded>0 && now-g_newsLoaded<1800) return;
      g_newsLoaded=now; ArrayResize(g_newsT,0); ArrayResize(g_newsN,0);
      NewsLoadBuiltin();
      NewsLoadCalendar();
      return;
   }
   // v1.86 盲點修補6：若已超過內建新聞表最後日期（2027/12/22）且非回測，自動接軌 MT5 內建日曆
   datetime builtinEnd=StringToTime("2027.12.23 00:00");
   if(!tester && now>builtinEnd)
   {
      if(!force && g_newsLoaded>0 && now-g_newsLoaded<1800) return;
      g_newsLoaded=now; ArrayResize(g_newsT,0); ArrayResize(g_newsN,0);
      NewsLoadCalendar();
      PrintFormat("警告：內建 2025-2027 新聞表已過期，已自動改用 MT5 官方經濟日曆（%d 筆）",ArraySize(g_newsT));
      return;
   }
   if(g_newsLoaded>0) return;                         // 內建表只載入一次
   g_newsLoaded=now;
   NewsLoadBuiltin();
   PrintFormat("新聞過濾：已載入內建 2025～2027 重大新聞 %d 筆（伺服器時間 = 美東 +%d，含DST自動校正）",ArraySize(g_newsT),NewsServerOffsetH);
}

// 目前是否在新聞窗口內（新聞前 NewsBeforeMin 分鐘 ～ 新聞後 NewsAfterMin 分鐘）
int NewsActiveIndex()
{
   if(!NewsFilter) return -1;
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_newsT);i++)
      if(now>=g_newsT[i]-NewsBeforeMin*60 && now<=g_newsT[i]+NewsAfterMin*60) return i;
   return -1;
}
bool NewsBlocked(){ return NewsActiveIndex()>=0; }

// v1.72 行情過熱：最近 RegimeHours 小時（含當根 H1）最高價－最低價
double RegimeRange()
{
   if(RegimeHours<=0) return 0;
   int n=RegimeHours+1;
   int ih=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,n,0);
   int il=iLowest(_Symbol,PERIOD_H1,MODE_LOW,n,0);
   if(ih<0 || il<0) return 0;
   return iHigh(_Symbol,PERIOD_H1,ih)-iLow(_Symbol,PERIOD_H1,il);
}
bool RegimeHot()
{
   if(RegimeHours<=0 || RegimeRangeUsd<=0) return false;
   return RegimeRange() > RegimeRangeUsd;
}

// v1.80 取最近 n 根 H1（含當根）的最高價與最低價；歷史不足時用現有的 K 棒；失敗回傳 false
bool H1HighLow(int n,double &hi,double &lo)
{
   hi=0; lo=0;
   int bars=Bars(_Symbol,PERIOD_H1);
   if(n<=0 || bars<=0) return false;
   if(n>bars) n=bars;
   int ih=iHighest(_Symbol,PERIOD_H1,MODE_HIGH,n,0);
   int il=iLowest(_Symbol,PERIOD_H1,MODE_LOW,n,0);
   if(ih<0 || il<0) return false;
   hi=iHigh(_Symbol,PERIOD_H1,ih); lo=iLow(_Symbol,PERIOD_H1,il);
   return (hi>0 && lo>0);
}

// v1.80 長期波動過熱：最近 Regime2Hours 根 H1（含當根）最高價－最低價，佔現價的百分比（同一秒只算一次）
double Regime2RangePct()
{
   static datetime lastT=0;
   static double   lastV=0;
   if(Regime2Hours<=0) return 0;
   datetime now=TimeCurrent();
   if(now==lastT && lastT>0) return lastV;
   lastT=now; lastV=0;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), hi=0, lo=0;
   if(bid<=0 || !H1HighLow(Regime2Hours+1,hi,lo)) return 0;
   lastV=(hi-lo)/bid*100.0;
   return lastV;
}
bool Regime2Hot()
{
   if(Regime2Hours<=0 || Regime2Pct<=0) return false;
   return Regime2RangePct() > Regime2Pct;
}

// v1.80 高低點過濾：現價離最近 EdgeHours 根 H1（含當根）最高價／最低價的距離百分比（同一秒只算一次）
//        side 1＝離最高價（擋空鏈用）、side 0＝離最低價（擋多鏈用）；資料不足回傳 -1
double EdgeDistPct(int side)
{
   static datetime lastT=0;
   static double   dHi=-1, dLo=-1;
   if(EdgeHours<=0) return -1;
   datetime now=TimeCurrent();
   if(now!=lastT || lastT==0)
   {
      lastT=now; dHi=-1; dLo=-1;
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), hi=0, lo=0;
      if(bid>0 && H1HighLow(EdgeHours+1,hi,lo))
      {
         dHi=MathMax(0.0,(hi-bid)/hi*100.0);                               // 現價比最高價低多少 %
         dLo=MathMax(0.0,(bid-lo)/lo*100.0);                               // 現價比最低價高多少 %
      }
   }
   return (side==1) ? dHi : dLo;
}
// side 0＝多鏈（離低點太近不開）、1＝空鏈（離高點太近不開）
bool EdgeBlocked(int side)
{
   if(EdgeHours<=0 || EdgePct<=0) return false;
   double d=EdgeDistPct(side);
   if(!(d>=0 && d<EdgePct)) return false;
   if(side==0 && !EdgeBlockLow) return false;                          // v1.84 低點側過濾可關（預設關＝放行多鏈）
   return true;
}
// v1.62 是否在新聞凍結時段（公佈當下 ～ +NewsFreezeAfterMin）
bool NewsFreeze()
{
   if(!NewsFilter || !NewsFreezeAdds || NewsFreezeAfterMin<=0) return false;
   datetime now=TimeCurrent();
   for(int i=0;i<ArraySize(g_newsT);i++)
      if(now>=g_newsT[i] && now<g_newsT[i]+NewsFreezeAfterMin*60) return true;
   return false;
}

string NewsStatusText()
{
   if(!NewsFilter) return "新聞過濾：關";
   datetime now=TimeCurrent();
   int a=NewsActiveIndex();
   if(a>=0)
   {
      long left=(long)(g_newsT[a]+NewsAfterMin*60-now);
      string nm=g_newsN[a]; if(StringLen(nm)>22) nm=StringSubstr(nm,0,22)+"…";
      return StringFormat("新聞暫停開新鏈：%s %s · %d 分後恢復",TimeToString(g_newsT[a],TIME_MINUTES),nm,(int)(left/60)+1);
   }
   datetime nx=0; string nn="";
   for(int i=0;i<ArraySize(g_newsT);i++) if(g_newsT[i]>now && (nx==0 || g_newsT[i]<nx)){ nx=g_newsT[i]; nn=g_newsN[i]; }
   if(nx==0) return "下一則重大新聞：無";
   if(StringLen(nn)>20) nn=StringSubstr(nn,0,20)+"…";
   return StringFormat("下一則：%s %s",TimeToString(nx,TIME_DATE|TIME_MINUTES),nn);
}


//+------------------------------------------------------------------+
//| v1.60 週五收盤保護                                               |
//+------------------------------------------------------------------+
int FridayCloseSec()
{
   static int cached=-1;
   static long cachedDay=-1;
   long today=(long)(TimeCurrent()/86400);
   if(cached>=0 && cachedDay==today) return cached;   // v1.86 盲點修補4：每日重查一次收盤時間
   cachedDay=today;
   int best=-1; datetime from,to;
   for(uint i=0;i<10;i++)
   {
      if(!SymbolInfoSessionTrade(_Symbol,FRIDAY,i,from,to)) break;
      int e=(int)((long)to%86400);
      if(e==0 && (long)to>0) e=86400;
      if(e>best) best=e;
   }
   if(best<=0)
   {
      string p[]; int n=StringSplit(FridayCloseTime,':',p);
      best = (n>=2) ? (int)StringToInteger(p[0])*3600+(int)StringToInteger(p[1])*60 : 23*3600+55*60;
   }
   cached=best;
   return cached;
}

bool FridayGate()
{
   if(FridayGateHours<=0) return false;
   MqlDateTime t; TimeToStruct(TimeCurrent(),t);
   if(t.day_of_week!=5) return false;
   int sec=t.hour*3600+t.min*60+t.sec;
   return sec >= FridayCloseSec() - (int)(FridayGateHours*3600);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // v1.69 圖表視窗改變大小：自動縮放模式下重新計算面板大小（v1.77 手動加倉按鍵已移除）
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      if(g_cvOK && PanelScale<=0 && MathAbs(CalcPanelScale()-g_ps)>0.04)
      { PanelDestroy(); g_panelTick=0; DrawPanel(); }
   }
}

void OnTick()
{
   datetime nowT=TimeCurrent();
   // v1.86 盲點修補5：偵測週末休市或異常停盤重開（相鄰 tick > 30 分鐘），首輪補格限 1 層防開盤跳空連補 5 單
   if(g_lastTickT>0 && (nowT-g_lastTickT)>1800)
   {
      if(CountSide(0)>0) g_resume[0]=true;
      if(CountSide(1)>0) g_resume[1]=true;
   }
   g_lastTickT=nowT;
   VelRecord();                                                   // v1.74
   DDUpdate();
   NewsLoad();
   CheckEquityStop();
   ProcessSide(0);
   ProcessSide(1);
   DrawPanel();
}
//+------------------------------------------------------------------+
