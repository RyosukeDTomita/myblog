---
title: "My Programming Style"
date: 2026-07-24
tags: programming, tech
---

## Coding Style

### プログラミング一般

- マジックナンバーを使用しない。
- 変数名は単語の短さよりも可読性を優先する
- 変数は不変(immutable)な状態を優先する。
- implicit importを避け、explicit importを使う。数が多い場合にはqualified importを使用する。
  - 未使用importは削除する。
- メソッドは純粋関数(pure function)を優先する。
- ガード節(early return)をバリデーションに使用する。ロジックの分岐はif elseを優先する
- 観察可能な振る舞い(observable behavior)のみを公開APIにするよう心がける。

### 設計

- ヘキサゴナルアーキテクチャ(Hexagonal Architecture)より、関数型アーキテクチャ(Functional Architecture)を好み、関数的核(functional core)と可変殻(mutable shell)の分離を基本とする
  - ドメイン・ロジック(Domain Logic)は純粋関数として実装し、副作用(side effect)を伴う処理はアプリケーション・サービス層(Application Service Layer)に分離する。
  - 外部依存(external dependency)はドメイン層(Domain Layer)で定義されたインターフェースを介して扱う(インターフェースは実装の差し替えではなく、ドメインが外部依存を扱わないようにすることが目的)。
- アプリケーション・サービス層では、外部状態(DBや外部API)の取得および処理のオーケストレーションを担う。パフォーマンス最適化や外部状態に強く依存する判断に限り、意思決定の一部をアプリケーション層で行うことを許容するが、本質的なビジネスルールはドメイン層に保持する。
- 上層でのvalidationで対応可能な例外はthrowせず、上層でのvalidationで対応する。
- コマンド・クエリ分離(Command Query Separation: CQS)を考慮する。

### テスト戦略

- Kent BeckのTDDの使用を好む
- 古典学派(Classical School)的なアプローチを使用する。ドメイン層、アプリケーション・サービス層それぞれの観察可能な振る舞いをテストする。
  - ドメイン層のテスト対象はモックを使用せず、単体テストで検証できるよう、関数核として設計することを優先する。
  - アプリケーション・サービス層のテストコードでは、外部から確認できるプロセス外依存がある場合に限りモックを使用し、interaction(呼び出し)を検証しても良い。
- 単体テストはAAAパターンを基本とする。
  - 同じフェーズを複数回含まない(NG例: Actフェーズが2回ある)
  - Actフェーズが2行以上になるときには設計を疑う
  - パラメータ化されたテストを書く際には、可読性を重視するため、正常系と異常系の検証をするテストメソッドを分ける。
- テスト対象のメソッド名をテスト名に含めず、振る舞いで命名する
  - NG例: `Sum_TwoNumbers_ReturnsSum`
  - 良い例: `Sum_of_two_numbers`
- カバレッジは絶対視しないが、改善のため測定を行う。
- テスタビリティ向上のため、依存性注入(Dependency Injection)が必要であれば行う WIP

### Object Oriented Programming(Java)

- ドメインモデル(Domain Model)の完全性(completeness)、純粋性(purity)、performance とのトレードオフが発生する場合には、意思決定プロセスをドメイン層とコントローラーに分けて対応する。可能なら、ドメインモデルの完全性を目指す
- クラスは必須フィールドをすべてコンストラクタで初期化し、バリデーションを行う。
- 不変クラス(Immutable Class)、値オブジェクト(Value Object)を優先する
- nullを返すようなメソッドを作らないよう心がける。可能なら、Optionalや空コレクションや空配列を使う
- 回復不可能な状態には非チェック例外(Unchecked Exception)としてthrowする
- 例外は握りつぶさず、下位層のエラーメッセージや情報を含んでthrowする。

### Haskell

- 関数を作成する際には、型から情報が得られたほうが可読性が良いため、単相関数を優先する。
- 条件分岐は以下の優先順位とする
  - パターンマッチ: 引数の構造で分岐できる場合 (優先度高)
  - ガード: 引数の値が満たす性質で分岐する (優先度中)
  - ifとcaseは必要に応じて使用する (優先度低)
    - case式: doブロックや`where`、`let`などの式の中で分岐したい時
      - `Maybe`
    - if式: インラインでの簡単な条件分岐
- ポイントフリースタイルはなるべく使わない。
- 自前の再帰関数よりも、`foldr`、`foldl'`、`mapAccumL`を優先して使用する。
- 非正格な演算子を使用する場合、`foldr`系列のshort-circuit(短絡)して効率化する。
- 関数の本体が型宣言と近くなるほうが可読性が良いと感じるので`let`よりも`where`を優先して使う。ガードをまたがずに変数を定義したい場合やリスト内包表記の中など`let`しか使えない場面`let`を使う。
- lambda式よりも部分適用を優先する。e.g. `map (\x -> x + 10)`よりも`map (+10)`を使う。
- lambda式よりも関数合成を優先する。
- lambda式は高階関数に渡す、もしくは1度だけ使う関数を使うときに使う。
- 関数の型定義は視認性が良くなるので、必ず書く。
- qualified importを使用する際にはimportしたのがなにかわかりやすくする。 e.g. NG例: `import Data.Set qualified as S` 良い例:  `import Data.Set qualified as Set`
- 視認性の問題から、`()`よりも`$`を優先する。
- ``{-# OPTIONS_GHC -Wunused-imports -Werror=incomplete-patterns #-}`で部分関数を避ける`
- `{-# OPTIONS_GHC -Wunused-imports #-}`で未使用importを避ける。

#### 競技プログラミングの場合の例外的処置

- 入出力は`interact`を使用する。
- 入力を信頼し、`head`などの部分関数を使っても良い。
- TLEにならない範囲において、STモナドを使った破壊的変更よりもイミュータブルを優先する。

### コメント

- documentation commentは利用者に対する契約を記載する
  - 型で表現できないか検討する
  - 引数の意味が型からわかりにくい場合には、引数の説明を記載する
- inline comment(trailing comment)
  - 基本的にはコードの意図が直感的にわかりにくい場合に使用する
  - Howを書きたくなった時には、関数名や変数名を変えることを検討する
  - 自分のリポジトリに限り、自分が調べた部分やパッとわからなかった部分には`NOTE:`をつけてメモを書いておく。
- implementation commentは実装の意図や理由を説明するために使用する
  - コードの右に書くのではなく、コードの上に書くことを優先する
- section commentはコードのセクションを区切るために使用し、セクションの内容を説明する。
  - section commentが増える場合には関数やメソッドの分割を検討する

---

## GitHub運用

- Conventional Commitsを行う
- ブランチ名は冒頭にfeature/、hotfix/、documentation/、refactor/のいずれかをつける。
- GitHub Security ScorecardをREADME.mdにつける
- LICENSEはMIT or NOLICENSEを使用する

### Releaseについて

[GitHubのReleasesでファイルを配る際のセキュリティ対策とその実践方法](https://zenn.dev/sigma_tom/articles/2f1949dd7658f0)に基づいてリリースする

- Release自体の方式変更 --> Release artifactの差し替え防止
  - Immutable Releasesを利用する
  - Releaseの作者をGitHub Actionsにする

- 署名の付与 --> GitHub アカウント乗っ取り時の不正リリース防止
  - Release Tagに署名をうつ
  - commitに署名をうつ

---
