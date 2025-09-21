# ドメインモデル設計メモ

## 全体方針
- Phoenix LiveView から扱いやすいように、対局状態は構造体 `%ToukonAiShogi.Game.State{}` に集約する。
- 盤面は 9x9 の座標を `{file, rank}` タプルで表し、`file` は 1〜9、`rank` は 1〜9 の整数を利用する。
- 駒は `%ToukonAiShogi.Game.Piece{}` で表し、`type`（駒種）、`owner`（`:sente` or `:gote`）、`promoted` を保持する。必要に応じて `id` を付与し LiveView 側が安定した DOM key を持てるようにする。
- 「持ち駒」は手番ごとのリストで管理し、平手初期状態では空配列。縁台ルールなので合法手チェックは後続フェーズで導入する。

## モジュール構成
```
ToukonAiShogi.Game               # コンテキスト。初期化やステート更新 API を提供
├── ToukonAiShogi.Game.State     # 対局全体を保持する構造体
├── ToukonAiShogi.Game.Board     # 盤面を表現する構造体
├── ToukonAiShogi.Game.Piece     # 駒の構造体定義
├── ToukonAiShogi.Game.InitialSetup
                                  # 初期盤面・初期ステート生成ヘルパー
├── ToukonAiShogi.GameRooms       # 各対局ルームのプロセス管理（PubSub ブロードキャスト）
├── ToukonAiShogi.GameRoom        # ルームごとの GenServer 実装
└── ToukonAiShogi.GameSessions    # 対局結果の永続化（Ecto）
```

## State 構造体
- `board`: `ToukonAiShogi.Game.Board`
- `turn`: `:sente | :gote`
- `captures`: `%{sente: [Piece.t()], gote: [Piece.t()]}`
- `move_log`: `list`（順次追加。MVP では簡易的な記録でもよい）
- `request_log`: `list`（"リクエスト" イベントの履歴）
- `metadata`: `map`（UI 向け補助情報。例: 直前の手、成り選択中フラグ）

### metadata の暫定フィールド
- `selected_piece`: LiveView UI がハイライト中の駒 ID
- `pending_move`: `%{from: {file, rank}, to: {file, rank}}` 形式で未適用の移動要求を保持
- `last_move`: 直近に適用された指し手（`promote` や `captured` 情報を含む）
- `last_request`: 最新のリクエスト記録（リクエストした手番・判定結果）
- `result`: 対局結果（例: `%{type: :resign, winner: :sente, loser: :gote}`）

## Board 構造体
- `squares`: `%{{file, rank} => Piece.t()}`
- ヘルパー
  - `fetch/2` `put/3` `drop/2` など単純操作を提供予定（MVP では必要最小限のみ）
  - 将来の合法手判定や棋譜生成に備えて、盤面操作は関数経由で行う想定。

## Piece 構造体
- `id`: `String.t()` – DOM key や棋譜保存で利用。
- `type`: `:gyoku | :hisya | :kaku | :kin | :gin | :kei | :kyo | :fu | :ryu | :uma | :narigin | :narikei | :narikyo | :tokin`
- `owner`: `:sente | :gote`
- `promoted`: `boolean`

## 初期盤面
- `InitialSetup.starting_board/0` が `%Board{}` を返す。
- `InitialSetup.starting_state/0` が `%State{}` を返す。`turn` は `:sente`、`move_log` と `request_log` は空配列。
- LiveView 側は `Game.new/0` を呼び出して初期状態を取得し、クライアントへ送信する。

## 初期盤面 JSON
- `priv/static/game/initial_state.json` に初期状態のスナップショットを保存。
- 将来的に JS 側で静的ロードしたい場合に利用。Elixir 側では `InitialSetup.initial_state_json/0` を通じて再利用できるようにする。

## 「リクエスト」フロー
1. 手番が一手指し終えた後、相手は任意タイミングで「リクエスト」できる。
2. リクエストを受けると `request_log` に `{requestor, current_turn, decision}` を追記。
3. MVP では判定ロジックを実装せず、LiveView UI 側で「引き分け（再戦）」とする想定。
4. 今後の実装余地
   - 判定モジュール `ToukonAiShogi.Game.RequestJudge` で評価し、結果に応じて勝敗処理。
   - 誤リクエスト時の敗北など、Requirements.md に基づいたペナルティを付与。

## 今後の拡張ポイント
- 棋譜保存は `move_log` を CSA など既存フォーマットに変換するモジュールを追加する。
- 合法手チェックは別モジュール化し、縁台ルール用フラグで OFF/ON を切り替え。
- AI 対戦時は `ToukonAiShogi.Game` に Bot 用インターフェースを追加予定。
