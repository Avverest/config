# Faces для kak-tree-sitter, построенные на палитре kanagawa.kak.
#
# kak-tree-sitter выводит имя face из capture-группы: "foo.bar.zoo" ->
# ts_foo_bar_zoo, который наследует ts_foo_bar, а тот — ts_foo. Поэтому
# достаточно задать базовые группы; подгруппы уточняют их там, где это
# что-то меняет.
#
# Файл рассчитан на то, что kanagawa.kak уже загружен (он объявляет
# declare-option str <цвет>), поэтому источится ПОСЛЕ colorscheme.

# ── Базовые группы ───────────────────────────────────────────────────────
set-face global ts_attribute            "%opt{blue_green}"
set-face global ts_comment              "%opt{gray}+i"
set-face global ts_constant             "%opt{blue_green}"
set-face global ts_constructor          "%opt{pink}"
set-face global ts_error                "%opt{red}+b"
set-face global ts_function             "%opt{blue}"
set-face global ts_hint                 "%opt{aqua}"
set-face global ts_include              "%opt{purple}"
set-face global ts_info                 "%opt{cyan}"
set-face global ts_keyword              "%opt{purple}"
set-face global ts_label                "%opt{pink}"
set-face global ts_namespace            "%opt{white}"
set-face global ts_operator             "%opt{lime}"
set-face global ts_property             "%opt{light_orange}"
set-face global ts_punctuation          "%opt{white}"
set-face global ts_special              "%opt{orange}"
set-face global ts_string               "%opt{green}"
set-face global ts_tag                  "%opt{pink}"
set-face global ts_text                 "%opt{white}"
set-face global ts_type                 "%opt{cyan}"
set-face global ts_variable             "%opt{white}"
set-face global ts_warning              "%opt{yellow}+b"

# ── Уточнения ────────────────────────────────────────────────────────────
# Комментарии-документация заметнее обычных.
set-face global ts_comment_block        "%opt{gray}+i"
set-face global ts_comment_line         "%opt{gray}+i"
set-face global ts_comment_unused       "%opt{dimgray}+i"

# Константы: литералы отличаются от именованных констант.
set-face global ts_constant_builtin     "%opt{orange}"
set-face global ts_constant_builtin_boolean "%opt{orange}"
set-face global ts_constant_numeric     "%opt{yellow}"
set-face global ts_constant_character   "%opt{green}"
set-face global ts_constant_character_escape "%opt{light_orange}+b"

# Функции.
set-face global ts_function_builtin     "%opt{cyan}+b"
set-face global ts_function_method      "%opt{blue}"
set-face global ts_function_macro       "%opt{aqua}"

# Ключевые слова: control-flow ярче объявлений.
set-face global ts_keyword_control      "%opt{pink}"
set-face global ts_keyword_control_import "%opt{purple}+i"
set-face global ts_keyword_control_return "%opt{pink}+b"
set-face global ts_keyword_control_conditional "%opt{pink}"
set-face global ts_keyword_control_repeat "%opt{pink}"
set-face global ts_keyword_control_exception "%opt{red}"
set-face global ts_keyword_function     "%opt{purple}"
set-face global ts_keyword_operator     "%opt{lime}"
set-face global ts_keyword_storage      "%opt{purple}"
set-face global ts_keyword_storage_type "%opt{purple}"
set-face global ts_keyword_storage_modifier "%opt{purple}+i"

# Пунктуация: скобки не должны перетягивать внимание.
set-face global ts_punctuation_bracket   "%opt{dimgray}"
set-face global ts_punctuation_delimiter "%opt{dimgray}"
set-face global ts_punctuation_special   "%opt{lime}"

# Строки и шаблонные литералы.
set-face global ts_string_escape        "%opt{light_orange}+b"
set-face global ts_string_regexp        "%opt{light_orange}"
set-face global ts_string_special       "%opt{light_orange}"

# Типы.
set-face global ts_type_builtin         "%opt{cyan}+i"
set-face global ts_type_parameter       "%opt{blue_green}+i"
set-face global ts_type_enum_variant    "%opt{blue_green}"

# Переменные: параметры и поля отличаются от локальных.
set-face global ts_variable_builtin     "%opt{orange}+i"
set-face global ts_variable_parameter   "%opt{light_orange}"
set-face global ts_variable_other_member "%opt{white}"
set-face global ts_variable_other_member_private "%opt{dimgray}"

# JSX/HTML-теги.
set-face global ts_tag_error            "%opt{red}+b"

# Markup (markdown в комментариях/инъекциях).
set-face global ts_markup_bold          "+b"
set-face global ts_markup_italic        "+i"
set-face global ts_markup_heading       "%opt{orange}+b"
set-face global ts_markup_link_uri      "%opt{green}+u"
set-face global ts_markup_link_url      "%opt{green}+u"
set-face global ts_markup_link_text     "%opt{blue}"
set-face global ts_markup_raw           "%opt{green}"
set-face global ts_markup_quote         "%opt{gray}+i"
set-face global ts_markup_strikethrough "+s"

# Diff (в git-контексте).
set-face global ts_diff_plus            "%opt{green}"
set-face global ts_diff_minus           "%opt{red}"
set-face global ts_diff_delta           "%opt{yellow}"
