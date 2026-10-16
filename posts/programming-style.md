---
title: "My Programming Style"
date: 2026-10-16
tags: programming, tech
---

## Coding Style

### 共通

- 可能であれば、関数型プログラミング言語を使用する
- 例外的状況にのみ例外を使う
- 例外は握りつぶさず、下位層のエラーメッセージや情報を含んでthrowする
- 不正な値でないかチェックした後には、チェック後であることがわかる型に変える(参考: [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/))
- マジックナンバーを使用しない
- 変数名は単語の短さよりも可読性を優先する
- implicit importを避け、explicit importを使う。数が多い場合にはqualified importを使用する
- 未使用importは削除する
- 観察可能な振る舞い(observable behavior)のみを公開APIにするよう心がける
- 本質的なビジネスルールはドメイン層(Domain Layer)に保持する
  - アプリケーション・サービス層(Application Service Layer)では、外部状態(DBや外部API)の取得および処理のオーケストレーションを担う
  - パフォーマンス最適化や外部状態に強く依存する判断に限り、意思決定の一部をアプリケーション・サービス層で行うことを許容する
- コマンド・クエリ分離(Command Query Separation: CQS)を考慮する

### Haskell

- 単相関数を優先する。理由: 型から情報が得られたほうが可読性が良いため
- トップレベル関数には型をつける
- 代数的データ型(ADT)を使用し、不正な状態を表現できないようにする
- 条件分岐は以下の優先順位で使用する
  - パターンマッチ: 引数の構造で分岐する場合(優先度高)
  - ガード: 引数の値が満たす性質で分岐する場合(優先度中)
  - ifとcaseは必要に応じて使用する(優先度低)
    - case式: doブロックや`where`、`let`などの式の中で分岐したいとき
    - if式: インラインでの簡単な条件分岐
- ポイントフリースタイルは、使わないと記述が冗長になる場合に限って使用する
- 自前の再帰関数よりも、畳み込み関数を優先する
- 非正格な演算子を使用する場合、`foldr`系列の関数でshort-circuit(短絡)できないか検討する
- `let`よりも`where`を優先して使う。理由: 関数の本体が型宣言と近くなるほうが可読性が良いと感じるため。
  - ガードをまたがずに変数を定義したい場合やリスト内包表記の中など、`let`しか使えない場面では`let`を使う
- lambda式よりも部分適用を優先する。e.g. `map (\x -> x + 10)`よりも`map (+10)`を使う
- lambda式よりも関数合成を優先する
- lambda式は、高階関数に渡す場合や、1度しか使わない関数を書く場合に使う
- qualified importを使用する際には、importしたものが何かわかる名前を付ける。e.g. NG例: `import Data.Set qualified as S` 良い例: `import Data.Set qualified as Set`
  - 後置のqualified構文には`ImportQualifiedPost`拡張が必要(GHC2021では既定で有効)
- `()`よりも`$`を優先し、視認性を上げる
- 部分関数を可能な限り避ける

#### 競技プログラミングの場合(Haskell)

- 入出力は`interact`を使用する
- 入力を信頼し、`head`などの部分関数を使ってもよい
- TLE(Time Limit Exceeded)にならない範囲において、STモナドなどを使った破壊的変更よりも不変(immutable)なデータ構造を優先する
- 遅延ストリームを意識してリストを使用する。理由: 生成と消費を1回の走査で行い、消費済みのセルを別の場所から参照しないようにすることで、使い終わったセルから順にGCできることで、リスト全体が同時にメモリに載せなくてすみ、メモリ使用量が一定になる。
  - 良い例: 生成側はリスト内包表記、消費側が`foldl'`や`sum`など。
  - 悪い例: `sum xs / length xs`のように同じリストを2回走査するとリスト全体がメモリに載る。

### コメント

- documentation commentは利用者に対する契約を記載する
  - 型で表現できないか検討する
  - 引数の意味が型からわかりにくい場合には、引数の説明を記載する
- inline comment(trailing comment)
  - 基本的にはコードの意図が直感的にわかりにくい場合に使用する
  - Howを書きたくなったときには、関数名や変数名を変えることを検討する
  - 自分のリポジトリに限り、自分が調べた部分やパッとわからなかった部分には`NOTE:`をつけてメモを書いておく
- implementation commentは実装の意図や理由を説明するために使用する
  - コードの右に書くのではなく、コードの上に書くことを優先する
- section commentはコードのセクションを区切るために使用し、セクションの内容を説明する
  - section commentが増える場合には関数やメソッドの分割を検討する

### 関数型プログラミング言語が使用できない場合

- メソッドは純粋関数(pure function)を優先する
- 変数は不変な状態を優先する
- ガード節(early return)をバリデーションに使用する。ロジックの分岐はif elseを優先する
- ヘキサゴナルアーキテクチャ(Hexagonal Architecture)より、関数型アーキテクチャ(Functional Architecture)を優先し、関数的核(functional core)と可変殻(mutable shell)を分離する
  - ドメイン・ロジック(Domain Logic)はなるべく純粋関数として実装し、副作用(side effect)を伴う処理はアプリケーション・サービス層に分離する
- nullを返すようなメソッドを作らないよう心がけ、JavaでいうOptionalや空コレクション、空配列を使う

#### Object Oriented Programming(Java)

- ドメインモデル(Domain Model)の完全性(completeness)、純粋性(purity)、パフォーマンスとのトレードオフが発生する場合には、意思決定プロセスをドメイン層とコントローラーに分けて対応する。可能なら、ドメインモデルの完全性を目指す
- クラスは必須フィールドをすべてコンストラクタで初期化し、バリデーションを行う
- 不変クラス(Immutable Class)、値オブジェクト(Value Object)を優先する
- 回復不可能な状態には非チェック例外(Unchecked Exception)としてthrowする

---

## (テスト戦略)

(LLMありきだと前提が変わってはいるため、手でコードを書いている前提での記載)

主に、[単体テストの考え方/使い方](https://amzn.asia/d/0eesYQaC)に影響を受けている。

- Kent BeckのTDD(Test-Driven Development)の使用を好む
- 古典学派(Classical School)的なアプローチを使用する。ドメイン層、アプリケーション・サービス層それぞれの観察可能な振る舞いをテストする
  - ドメイン層は、モックを使わずに単体テストで検証できるよう、関数的核として設計することを優先する
  - アプリケーション・サービス層のテストコードでは、外部から確認できるプロセス外依存がある場合に限りモックを使用し、interaction(呼び出し)を検証してもよい
- 単体テストはAAA(Arrange-Act-Assert)パターンを基本とする
  - 同じフェーズを複数回含まない(NG例: Actフェーズが2回ある)
  - Actフェーズが2行以上になるときには設計を疑う
  - パラメータ化されたテストを書く際には、可読性を重視するため、正常系と異常系の検証をするテストメソッドを分ける
- テスト対象のメソッド名をテスト名に含めず、振る舞いで命名する
  - NG例: `Sum_TwoNumbers_ReturnsSum`
  - 良い例: `Sum_of_two_numbers`
- カバレッジは絶対視しないが、改善のため測定を行う

---

## GitHub運用

### 自分のリポジトリ

- Conventional Commitsを行う
- ブランチ名は冒頭に`feature/`、`hotfix/`、`documentation/`、`refactor/`のいずれかをつける
- OpenSSF Scorecardのバッジを`README.md`につける
- LICENSEはMIT Licenseを使用する

#### Releaseについて

[GitHubのReleasesでファイルを配る際のセキュリティ対策とその実践方法](https://zenn.dev/sigma_tom/articles/2f1949dd7658f0)に基づいてリリースする

- Release自体の方式変更 --> Release artifactの差し替え防止
  - Immutable releasesを利用する
  - Releaseの作者をGitHub Actionsにする
- 署名の付与 --> GitHubアカウント乗っ取り時の不正リリース防止
  - リリースタグに署名する
  - commitに署名する

### 自分の管理外のOSS活動

- そのリポジトリのルールを最優先にする
- 手でコードを書く。理由: 1つのPRから得られる自分の理解の質を最大にするため
  - (自分のレベル感的に)手でコードを書く程度の情熱がないなら、PRは出さずにForkして自分用に使うべき
- LLMを使った場合は、IssueやPRにLLMを使用した範囲を明示的に記載する。参考: [GHC Policy on LLM contributions](https://gitlab.haskell.org/ghc/ghc/-/wikis/contributing/AI)
- LLMをコード生成以外でも使用した場合には、commitに`Assisted-By:`を適切につける
- コメントをくれた人やreviewerには`Reviewed-by:`、`Suggested-by:`、`Co-authored-by:`を忘れずにつける。

---

