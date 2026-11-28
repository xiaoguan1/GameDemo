-- GameDemo luacheck 配置
-- 本地跑法: luacheck --config .luacheckrc
-- CI 门禁: (E011) 语法错误 + (W113) 读取了全项目任何文件都没定义过的变量 = 真 bug, 直接失败
--
-- 本项目特点:
--   1. 模块之间通过 Import/fenv 共享环境, 大量跨文件全局变量。
--      因此开启 allow_defined_top: 任何文件顶层赋值过的全局视为已定义,
--      只有「全项目从未定义却读取」的变量才会报警 —— 这是真正的拼写错误/漏定义。
--   2. 新增一个运行时注入全局时, 若它不是在任何 .lua 顶层定义的(如 C 侧注入、_G 注入),
--      需要登记到下方 globals 列表, 否则 W113 会误报。

std = "lua51+gamedemo"

-- 自定义标准库: tool/luaplugins 对 string/table 的运行时扩展, 以及 tool 全局表
stds = {
    gamedemo = {
        globals = {
            "utf8",             -- 引擎实际运行在 Lua 5.4, utf8 为标准库
            string = {
                -- Lua5.2+/5.4 标准库函数 (std 选 lua51, 需补登记)
                fields = { "beginswith", "endswith", "split", "pack", "unpack" },
            },
            table = {
                fields = { "clear", "copy", "deepcopy", "empty", "equal",
                    "has_value", "onlyread", "ptreq", "size", "pack", "unpack" },
            },
            tool = {
                fields = { "dump", "dumptree", "repr", "serialise", "traceback" },
            },
        },
    },
}

-- 跨文件共享的模块全局: 顶层赋值即隐式定义 (匹配 Import/fenv 机制)
allow_defined_top = true

-- 运行时注入全局 (preload/宏/日志/startup 注入, 非任何 .lua 顶层赋值)
globals = {
    -- tool/luaplugins 注入
    "Import", "ICopy", "TryCall", "Class", "scoroutine",
    -- game/global/macro/fenv.lua 补的 Lua5.1 兼容函数
    "getfenv", "setfenv", "getfsrc",
    -- game/global/log.lua 日志宏 (服务启动时 dofile)
    "_INFO", "_INFO_F", "_DEBUG", "_DEBUG_F", "_WARN", "_WARN_F",
    "_ERROR", "_ERROR_F", "_MEM_ALARM", "_MEM_ALARM_F",
    "_LOG_EVENT", "_LOG_EVENT_F",
    -- game/global/macro/*.lua 常量宏 (preload 时 dofile)
    "ONE_DAY_SEC", "ONE_HOUR_SEC", "ONE_MIN_SEC",
    "UPDATE_TYPE", "UPDATE_DOFILE_FILE", "LOG_LEVEL",
    "LOG_COLORS", "LOG_COLOR_FMT",
    "BASIC_SERVICE_MAP", "USER_NODE", "CROSS_NODE", "NODE_LIST", "ALL_SERVICE_MAP",
    "TOOL_FILES", "MACRO_FILES", "DOFILELIST",
    -- oop/class 生成环境注入
    "SuperClass", "newClass",
    -- 服务运行环境 (startup/服务入口 _G 注入)
    "SERVICE_NAME", "SELF_CLUSTERNAME",
    "ACCEPT", "RESPONSE", "WHANDLE",
    "AGENT_INDEX", "MAPCELL_INDEX",
    -- 协议表
    "RPROTOMAP", "PROTOMAP",
    -- 服务内函数作用域惰性 Import 赋值 (非顶层, allow_defined_top 不生效, 需登记)
    "FileLog", "DbLog", "CLUSTER_GATE", "Ghelper", "LoadP",
}

exclude_files = {
    -- 非 Lua 文件 (luacheck 扫描目录时会全部解析, 必须排除)
    "**/*.sh", "**/*.c", "**/*.h", "**/*.so", "**/Makefile",
    "**/*.proto", "**/*.pb", "**/*.conf", "**/*.md",
    -- 第三方库
    "tool/3rd",
    -- 自动生成产物 (禁止手改, 由 gen_proto.sh 生成)
    "protocol/protomap.lua",
    "protocol/save-prot-id",
}

-- 代码行超长与空白风格不检查
max_line_length = false
ignore = { "611", "612", "613", "614" }
