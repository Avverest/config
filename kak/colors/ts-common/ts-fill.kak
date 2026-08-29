# Fills the ts_* faces that kak-tree-sitter's queries emit but that themes
# commonly leave undefined. Every line is an alias onto a face the theme
# already defines, so the colours remain the theme's own.
#
# Source this at the END of a theme, after its own ts_* block: a face the
# theme already set is simply re-pointed to the same visual result, and the
# faces it never set gain a sensible inherited colour instead of falling
# back to Default.
#
# Alias targets are resolved lazily at render time, so it does not matter
# whether the theme defines the target above or below this point, and a
# theme that omits an intermediate entirely still resolves through it.
#
# Three intermediates (ts_function_method, ts_keyword_storage,
# ts_keyword_control_conditional) are not defined by every theme. Themes that
# omit them define a fallback themselves, just above where they source this
# file, so nothing here overwrites a theme that sets its own colour.

evaluate-commands %sh{
    printf 'set-face global %s %s\n' \
        ts_function_call              ts_function \
        ts_function_method_call       ts_function_method \
        ts_function_method_private    ts_function_method \
        ts_keyword_control            ts_keyword \
        ts_keyword_control_repeat     ts_keyword_control_conditional \
        ts_keyword_function           ts_keyword \
        ts_keyword_operator           ts_operator \
        ts_keyword_special            ts_keyword \
        ts_keyword_storage_type       ts_keyword_storage \
        ts_constant_numeric_integer   ts_constant \
        ts_constant_numeric_float     ts_constant \
        ts_operator_special           ts_operator \
        ts_punctuation_bracket        ts_punctuation \
        ts_punctuation_delimiter      ts_punctuation \
        ts_import                     ts_keyword_control_import \
        ts_markup_raw_block           ts_markup_raw \
        ts_charset                    ts_keyword \
        ts_keyframes                  ts_keyword \
        ts_media                      ts_keyword \
        ts_supports                   ts_keyword \
        ts_variable_other_member_private ts_variable_other_member
}
