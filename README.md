# MoonOData

MoonBit 实现的 OData 4.0 应用层编解码：资源路径、`$filter`/`$select`/`$expand` 等查询选项、JSON 实体集，以及 EDMX 里的 EntityType/EntitySet。不发 HTTP，不实现服务端运行时。

安装：把模块加进 `moon.mod`，或克隆后 `moon check --target wasm-gc`。

## 示例

### 1. 商品查询

```text
moon run cmd/main --target wasm-gc
```

`FILTER` 行是 `/Products?$filter=...&$select=Name,Price&$top=5`。`Name eq 'Bread' and Price gt 2` 会加上括号；`$top` 为整数 `5`，不是 `5.0`。

### 2. 按键展开导航

同一命令的 `EXPAND` 行：`/Orders(42)/Customer?$expand=Address&$count=true`。键 `42` 保持整数写法。

### 3. JSON 实体集

`JSON` 行带 `@odata.context` 和 `value` 数组。Bread 的 `ID` 为 `1`，`Price` 为 `2.5`。

## 测试

```text
moon test --target wasm-gc --deny-warn
moon test --target wasm --deny-warn
moon test --target js --deny-warn
```

当前 11 个测试覆盖过滤解析、未知选项、负 `$top`、EDMX 与 JSON 往返。

## 范围

支持：路径键谓词、常用 `$filter` 函数、`$select/$expand/$orderby/$top/$skip/$count`、OData JSON、EDMX 子集。

不做：HTTP 客户端、OData 服务端、`$apply`、Atom、OData 2.0 verbose JSON、Microsoft Graph 登录。

上游：SAP/python-pyodata Apache-2.0，行为重写，未复制 Python 源码。
