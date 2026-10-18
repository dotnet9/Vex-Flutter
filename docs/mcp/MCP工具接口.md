# MCP 接口参考

当前源码公开 **35 个工具**，全部以 `vex_` 开头。运行中的 `tools/list` 返回实际 `inputSchema`、枚举值与 `annotations`，是参数定义的最终依据。未声明的参数和错误类型会被拒绝。

## 协议约定

- 传输为无状态 Streamable HTTP，地址 `/mcp` 或 `/mcp/`，POST JSON；不要求 Session ID。
- 支持协商 `2025-03-26`、`2025-06-18`、`2025-11-25`；后续请求的 `MCP-Protocol-Version` 应使用协商结果。
- JSON-RPC 请求 ID 为字符串或整数。通知返回 HTTP 202，不响应消息内容；不带 ID 的请求不会执行工具。
- 单个请求体最多 1 MiB，读取超时 15 秒。确认等待不是网络上传超时，客户端需要给用户留出确认时间。
- 成功调用的 `content[0].text` 是 JSON 编码结果。对象结果另附 `structuredContent`；数组结果从文本 JSON 读取。
- 工具业务失败返回 `isError: true` 与文字说明；不存在的工具、参数类型/必填/枚举错误用 JSON-RPC `-32602`，未知方法为 `-32601`。

所有工具都接受可选的 `document_id: string` 与 `revision: integer`，若提供，必须匹配当前文档。**写客户端应先读取当前文档，然后同时传这两个值**，避免在错误文档上应用旧修改。`vex_apply_edits` 强制要求二者。

偏移与长度使用 **UTF-16 单元**，不是词数或可见字符数。中文通常为 1，`😀` 为 2，CRLF 换行也是 2；端点不可切开表情的代理对。范围为 `[start, end)`，选区要求 `0 <= start <= end`。

## 读取与发现（11 个）

本组不需要修改确认，但文档相关读取仍受当前访问范围约束。

| 工具 | 参数 | 返回结果 |
| --- | --- | --- |
| `vex_get_capabilities` | 无 | `tools`、`scope`、`write_confirmation`、`offset_unit`、`file_types`、当前 `document_id` |
| `vex_get_document` | 无 | 当前内存正文 `text`、`document_id`、`revision`、`path`、`name`、`dirty` |
| `vex_get_outline` | 无 | 标题数组：`id`、`parent_id`、`title`、`level`、标题 `offset`、章节 `end` |
| `vex_get_selection` | 无 | `start`、`end`、选中文本 `text`；无有效选区时文本为空 |
| `vex_list_files` | `offset?` 非负整数；`limit?` 1～1000，默认 200 | 范围内文件与已打开文档的 `{name,path}` 数组；未保存文档 `path` 可为 null |
| `vex_read_file` | `path` 绝对路径 | 磁盘版本 `{path,name,text}`；不切换文档，不包含其他文档的未保存修改 |
| `vex_find_text` | `query`；`case_sensitive?` 默认 false | 字面量匹配 `{offset,length}`，最多 1000 条，附当前 `document_id` 和 `revision` |
| `vex_get_map` | 无 | `layout` 与标题节点 `nodes`：`id,parent_id,title,level` |
| `vex_get_app_status` | 无 | `name,layout,palette,language,sidebar,outline,revision` |
| `vex_ui_get_state` | 无 | 同上，读取工作区界面状态 |
| `vex_get_operation_audit` | 无 | 最近 100 条以内 `{time,tool,result}`，新记录在前；读取操作记录本身不新增记录 |

文件列表不含预览正文。目录范围会递归枚举，默认忽略构建目录、依赖目录等生成物；未提供排序或跨页快照保证，枚举期间文件变化可能影响分页。分页结果不足 `limit` 表示当前已到末尾。

`vex_get_map` 提供的是文章章节结构，不是自由导图的画布坐标或独立节点正文。`id` 与源码解析有关，修改后应重新获取大纲，不能假定旧标题 ID 永久有效。

## 文档与正文（12 个）

以下全部属于需确认操作；其中 `vex_set_selection` 只改变选区，`vex_open_document` / `vex_new_document` 不覆盖已打开文档的未保存修改。

| 工具 | 必填参数 | 可选参数与行为 |
| --- | --- | --- |
| `vex_new_document` | 无 | 新建未命名草稿；仅当前文档权限允许，目录权限不创建无路径文档 |
| `vex_open_document` | `path` | 打开范围内现有文件；已打开时切换，不重新覆盖缓冲区 |
| `vex_set_selection` | `start,end` | 选择并定位正文范围，不修改文本 |
| `vex_replace_document` | `text` | 替换当前全文，进入正常撤销历史 |
| `vex_apply_text_edit` | `offset,length,text` | 在原文本范围上执行单次替换 |
| `vex_insert_text` | `text` | `offset?`；省略时在文末插入 |
| `vex_replace_selection` | `text` | 替换当前有效选区 |
| `vex_replace_text` | `query,text` | 区分大小写的字面量匹配；不唯一时必须传 `replace_all: true`；空查询/无匹配失败 |
| `vex_apply_edits` | `edits,document_id,revision` | 1～100 条 `{offset,length,text}`；以同一原文计算，不得重叠或起点相同；原子修改、一次撤销 |
| `vex_save_document` | 无 | 走正常保存和冲突检查；未保存草稿需要用户选择位置，取消返回失败 |
| `vex_undo` | 无 | 撤销一次，不自动保存 |
| `vex_redo` | 无 | 重做一次，不自动保存 |

修改与保存是分开的，自动保存默认关闭；不要把工具返回成功理解为内容已经写入磁盘。磁盘冲突也不会通过 MCP 强制覆盖。

## 章节结构（5 个）

| 工具 | 必填参数 | 可选参数与行为 |
| --- | --- | --- |
| `vex_rename_section` | `id,title` | 标题必须为非空单行，不改正文 |
| `vex_add_section` | `title` | `id?` 参照标题，`child?` 默认 false；无 id 在文末添加一级标题 |
| `vex_delete_section` | `id` | `keep_contents?` 默认 false；true 仅移除标题，false 删除整个章节含后代 |
| `vex_move_section` | `id` | `direction: -1/1` 同级上移/下移，或 `parent_id` 移到另一标题下；二选一 |
| `vex_change_section_level` | `id,delta` | `delta` 为 -1/1，整棵子章节一起提升/降低；限制一至六级 |

章节移动不能产生自包含/父子循环，越界级别会拒绝；已经处于首尾的同级移动可以无变化成功。

## 界面与导图（7 个）

| 工具 | 参数与允许值 |
| --- | --- |
| `vex_ui_set_layout` | `layout`: `instant,source,read,map,sourceRender,sourceMap,instantMap,three`；仍服从窗口单栏/双栏限制 |
| `vex_ui_set_theme` | `palette`: `weft,graphite,ocean,sand,rose,iris,olive,ember`，只改变界面主题色 |
| `vex_ui_set_theme_mode` | `mode`: `system,light,dark`，同时照顾界面与正文的明暗 |
| `vex_ui_set_typography` | `typography`: `simple,document,book,technical,column,editorial`，独立改变正文排版 |
| `vex_ui_set_language` | `language`: `zh,en,ja,zh_Hant` |
| `vex_ui_show_sidebar_tab` | `tab`: `files,outline`，同时显示侧边栏 |
| `vex_set_map_layout` | `layout`: `right,balanced,radial,down,outline,fishbone` |

成功的需确认操作返回 `{ok:true,document_id,revision}`。界面变化或选区变化可以不增加正文 revision；打开或新建文档后返回新当前文档的信息。

## 安全修改示例

以下展示 `tools/call` 的 `params`，不是完整 HTTP 请求。先调用 `vex_get_document`，以返回的真实 ID 和 revision 替换占位值。

```json
{
  "name": "vex_apply_edits",
  "arguments": {
    "document_id": "<读取结果中的 document_id>",
    "revision": 12,
    "edits": [
      {"offset": 0, "length": 0, "text": "# 新标题\n\n"}
    ]
  }
}
```

如果 revision 不匹配：重新读取正文，再由客户端重新计算或让用户确认修改；**不要只把版本号换成最新值重发旧偏移**。操作成功后需要落盘，再请求 `vex_save_document`，同样传入最新 ID 和 revision。

只读提示 `readOnlyHint` 与本机世界提示 `openWorldHint` 是帮助客户端展示用途的描述，不是权限凭据；服务端始终独立检查实际权限。
