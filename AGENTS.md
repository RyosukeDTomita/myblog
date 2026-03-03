# Agent Instructions

## Input Notification
- ユーザーからの入力が必要になった場合、質問メッセージを送る直前に `play` コマンドで通知音を鳴らす。
- 基本コマンド: `play -q -t alsa default -n synth 0.15 sine 880 vol 0.3`
- 失敗時のフォールバック: `play -nq synth 0.15 sine 880`
- どちらも失敗する場合は、質問だけを送信して処理を継続する。
