# Gives a theme full kak-tree-sitter highlighting in its own colours.
#
# kak-tree-sitter highlights only through ts_* faces. A theme that predates it
# sets only the classic Kakoune faces (keyword, string, function, type, ...),
# so under tree-sitter it renders flat. This file supplies the missing ts_*
# faces as aliases onto faces the theme itself already defines, so the colours
# stay the theme's own.
#
# Source it at the END of a theme, after the theme's own faces.
#
# Two layers, applied in order:
#
#   bridge  the ts_* roots onto the classic faces (ts_keyword -> keyword).
#           Skipped when the theme sets its own ts_* roots -- see the option
#           below. This is the layer that would flatten a modern theme.
#
#   fill    the finer-grained ts_* leaves the queries also emit, onto those
#           roots (ts_function_call -> ts_function). Always applied: it names
#           only faces a theme is unlikely to set, and each alias inherits
#           whatever colour the root ended up with -- the theme's own, when
#           the theme set it.
#
# Alias targets resolve lazily at render time, so the order of definition does
# not matter, and a theme that omits an intermediate still resolves through it.
#
# A theme that defines its own ts_* roots must turn the bridge layer off:
#
#     set-option global ts_common_bridge false
#     source "%val{config}/colors/ts-common/ts-common.kak"
#
# The modus and catppuccin families and night-owl do exactly that -- bridging
# them would overwrite ~80 hand-tuned colours with flat classic-face aliases.
# The option is read once here and reset to true afterwards, so it never
# leaks into the next theme the user switches to.
#
# `constant` is the one classic face a few themes omit (cyanide, monokai,
# mygruvbox, warm). Aliasing ts_constant onto an unset face would leave it
# Default, so those themes set `constant` themselves just above where they
# source this file. Likewise three intermediates (ts_function_method,
# ts_keyword_storage, ts_keyword_control_conditional) are not defined by every
# theme; themes that omit them define a fallback the same way.

declare-option -hidden bool ts_common_bridge true

# --- Layer 1: ts_* roots onto the classic faces ------------------------------

evaluate-commands %sh{
    [ "$kak_opt_ts_common_bridge" = true ] || exit 0
    printf 'set-face global %s %s\n' \
        ts_keyword                      keyword \
        ts_keyword_conditional          keyword \
        ts_keyword_control_conditional  keyword \
        ts_keyword_control_import       meta \
        ts_keyword_directive            meta \
        ts_keyword_storage              keyword \
        ts_keyword_storage_modifier     keyword \
        ts_keyword_storage_modifier_mut keyword \
        ts_keyword_storage_modifier_ref keyword \
        ts_keyword_control_exception    keyword \
        ts_keyword_control_return       keyword \
        ts_function                     function \
        ts_function_builtin             builtin \
        ts_function_macro               meta \
        ts_function_method              function \
        ts_type                         type \
        ts_type_builtin                 type \
        ts_type_enum_variant            type \
        ts_type_enum_variant_builtin    type \
        ts_type_parameter               type \
        ts_constructor                  type \
        ts_string                       string \
        ts_string_regexp                string \
        ts_string_escape                meta \
        ts_string_special               string \
        ts_string_symbol                string \
        ts_constant                     constant \
        ts_constant_builtin             builtin \
        ts_constant_builtin_boolean     builtin \
        ts_constant_character           string \
        ts_constant_character_escape    meta \
        ts_constant_macro               meta \
        ts_constant_numeric             value \
        ts_variable                     variable \
        ts_variable_builtin             builtin \
        ts_variable_other_member        variable \
        ts_variable_parameter           variable \
        ts_comment                      comment \
        ts_comment_unused               comment \
        ts_operator                     operator \
        ts_punctuation                  comma \
        ts_punctuation_special          meta \
        ts_property                     variable \
        ts_namespace                    module \
        ts_label                        meta \
        ts_attribute                    meta \
        ts_markup_bold                  bold \
        ts_markup_italic                italic \
        ts_markup_strikethrough         comment \
        ts_markup_heading               title \
        ts_markup_heading_1             title \
        ts_markup_heading_2             header \
        ts_markup_heading_3             header \
        ts_markup_heading_4             header \
        ts_markup_heading_5             header \
        ts_markup_heading_6             header \
        ts_markup_heading_marker        comment \
        ts_markup_list_checked          bullet \
        ts_markup_list_numbered         bullet \
        ts_markup_list_unchecked        bullet \
        ts_markup_list_unnumbered       bullet \
        ts_markup_link_label            link \
        ts_markup_link_url              link \
        ts_markup_link_uri              link \
        ts_markup_link_text             link \
        ts_markup_quote                 block \
        ts_markup_raw                   mono \
        ts_diff_plus                    string \
        ts_diff_minus                   meta \
        ts_diff_delta                   type \
        ts_diff_delta_moved             keyword \
        ts_error                        Error \
        ts_warning                      meta \
        ts_hint                         comment \
        ts_info                         type \
        ts_embedded                     keyword \
        ts_include                      meta \
        ts_load                         meta \
        ts_tag                          keyword \
        ts_tag_error                    Error \
        ts_text                         Default \
        ts_text_title                   title \
        ts_conceal                      comment \
        ts_special                      meta \
        ts_spell                        Default
}

# --- Layer 2: ts_* leaves onto the roots -------------------------------------

evaluate-commands %sh{
    printf 'set-face global %s %s\n' \
        ts_function_call                 ts_function \
        ts_function_method_call          ts_function_method \
        ts_function_method_private       ts_function_method \
        ts_keyword_control               ts_keyword \
        ts_keyword_control_repeat        ts_keyword_control_conditional \
        ts_keyword_function              ts_keyword \
        ts_keyword_operator              ts_operator \
        ts_keyword_special               ts_keyword \
        ts_keyword_storage_type          ts_keyword_storage \
        ts_constant_numeric_integer      ts_constant \
        ts_constant_numeric_float        ts_constant \
        ts_operator_special              ts_operator \
        ts_punctuation_bracket           ts_punctuation \
        ts_punctuation_delimiter         ts_punctuation \
        ts_import                        ts_keyword_control_import \
        ts_markup_raw_block              ts_markup_raw \
        ts_charset                       ts_keyword \
        ts_keyframes                     ts_keyword \
        ts_media                         ts_keyword \
        ts_supports                      ts_keyword \
        ts_variable_other_member_private ts_variable_other_member
}

set-option global ts_common_bridge true
