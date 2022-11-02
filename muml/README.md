# muml
![](https://github.com/mock-up/muml/workflows/build/badge.svg)
![](https://github.com/mock-up/muml/workflows/docs/badge.svg)

mock-up markup languageは[mock-up](https://github.com/mock-up/mock-up)において動画編集を記述するための、JSONで表現されるマークアップ言語です。

## mumlBuilder
mumlはmock-upがデフォルトで提供するタグとプロパティを読み出す他に、`mumlBuilder`を用いたユーザー拡張が認められます。
この機能はmock-upのプラグインを処理するために必要です。

mumlを拡張するためには`mumlRootObj`型を継承した`ref object`型を定義します。  
内部的に構造体が含まれていても構いませんが、現状ではそれらも`mumlRootObj`型を継承した`ref object`型である必要があります。

```nim
type
  nest1 = ref object of mumlRootObj
    nest1_field1: int
  
  newElement = ref object of mumlRootObj
    field1: int
    field2: string
    field3: nest1

mumlBuilder(newElement)
```

上のコードを実行すると、次のJSONをmumlとして解釈できるようになります。

```json
{
  "field1": 10,
  "field2": "hello",
  "field3": {
    "nest1_field1": 20
  }
}
```

## Document
- [muml - nim docs](https://mock-up.github.io/muml/muml.html)
