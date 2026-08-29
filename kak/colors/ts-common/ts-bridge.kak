# Bridges kak-tree-sitter's ts_* faces onto the classic Kakoune faces
# (keyword, string, function, type, …) that every upstream theme defines.
#
# Themes written before kak-tree-sitter set only the classic faces. Under
# tree-sitter those are never consulted: highlighting comes entirely from
# ts_*, so such a theme renders flat. Sourcing this at the end of one such
# theme gives it full tree-sitter highlighting in its own colours, because
# every entry here is an alias onto a face the theme itself has set.
#
# This is the coarse layer: it names only the ts_* roots. Source
# ts-fill.kak after it to expand the roots into the finer-grained faces
# (ts_function_call, ts_punctuation_bracket, …) that the queries also emit.
#
# `constant` is the one classic face a few themes omit (cyanide, monokai,
# mygruvbox, warm). Aliasing ts_constant onto an unset face would leave it
# Default, so those themes set `constant` themselves just above where they
# source this file. Every face named below is therefore always defined.

evaluate-commands %sh{
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
