# isucon5q-crystal

## Overview

[isucon5-qualifier-standalone](https://github.com/matsuu/vagrant-isucon/tree/master/isucon5-qualifier-standalone) 上で動作するWebAppのcrystal言語版です。

* フレームワークは [kemal](http://kemalcr.com/) をforkして微修正したもの
  * [at-grandpa/kemal/tree/add-content-length](https://github.com/at-grandpa/kemal/tree/add-content-length)
  * 静的ファイルのレスポンスヘッダに`Content-Length`が無かったため
* DBアクセスは [crystal-mysql](https://github.com/waterlink/crystal-mysql) をforkして微修正したもの
  * [at-grandpa/crystal-mysql/tree/multi-byte-char-support](https://github.com/at-grandpa/crystal-mysql/tree/multi-byte-char-support)
  * マルチバイト文字に対応していなかったため


## Usage

[isucon5-qualifier-standalone](https://github.com/matsuu/vagrant-isucon/tree/master/isucon5-qualifier-standalone)に従ってvagrant環境を用意する。
```
$ vagrant up
```

vagrant環境にssh。
```
$ vagrant ssh
```

`isucon`ユーザーになる。
```
sudo su - isucon
```

このリポジトリをclone。
```
$ git clone https://github.com/at-grandpa/isucon5q-crystal/
```

setupする。
```
$ cd isucon5q-crystal
$ make setup
```

指示に従って環境をsetupしていく。


## 動作確認

`isucon`ユーザーのhomeにベンチマークツールがあるので実行してみる。
```
$ cd
$ sh ./bench.sh
```

スコアが表示されればOK。

## ファイル編集後のビルド

ファイルを編集した後は、

```
$ make build
```

を実行すれば、

* 他言語のserviceを停止
* `shards update`
* crystalのコードをbuildして、webapp配下に配置
* `isuxi.crystal.service`をrestart

をします。
