# kak-ide — goto file / import navigation  (plan Section 7.3)
#
# `gf` in Kakoune opens the file whose name is selected. That covers a literal
# path and nothing else: it cannot follow `from "./util"` to util.ts, resolve a
# tsconfig `paths` alias, or turn `mod err;` into err.rs.
#
# Resolution order, per §7.3's "prefer LSP goto-definition and treat the regex
# resolvers as the *fallback*":
#
#   1. bin/kak-ide-resolve — filesystem probing, per language. Fast, works with
#      no server running, and is exact for relative imports and asset refs.
#   2. lsp-definition — for anything the resolver declines (bare package
#      specifiers, external crates), where the server knows the real answer.
#   3. Kakoune's native `gf` — last resort, for a plain path in a plain file.
#
# Several candidates (a .ts and a .js of the same name, say) go to a picker
# rather than being guessed at silently.

declare-option -hidden str kak_ide_resolve_helper "%val{config}/plugins/kak-ide/bin/kak-ide-resolve"

define-command kak-ide-goto-file -docstring %{
    kak-ide-goto-file: open the file or import target under the cursor
} %{ kak-ide-goto-file-impl 'edit -existing' }

define-command kak-ide-goto-file-vsplit -docstring %{
    kak-ide-goto-file-vsplit: open the file under the cursor in a pane to the right
} %{ kak-ide-goto-file-impl kak-ide-open-vsplit }

define-command kak-ide-goto-file-hsplit -docstring %{
    kak-ide-goto-file-hsplit: open the file under the cursor in a pane below
} %{ kak-ide-goto-file-impl kak-ide-open-hsplit }

define-command -hidden -params 1 kak-ide-goto-file-impl %{
    kak-ide-detect-root
    evaluate-commands -save-regs 'ls' %{
        set-register s %val{selection}
        # The whole line is the unit of resolution: an import specifier is
        # identified by its surrounding syntax (`from "…"`, `url(…)`, `mod x;`),
        # not by where the cursor happens to sit inside it.
        evaluate-commands -draft %{
            execute-keys x
            set-register l %val{selection}
        }
        evaluate-commands %sh{
            helper="$kak_opt_kak_ide_resolve_helper"
            line="$kak_reg_l"
            sel="$kak_reg_s"
            # An explicit multi-character selection wins: quote it so the
            # resolver's specifier extraction picks it up verbatim.
            case "$sel" in
                ''|?) : ;;
                *[!\ ]*)
                    case "$sel" in *' '*|*'
'*) : ;;
                       *) line="\"$sel\"" ;;
                    esac ;;
            esac
            [ -x "$helper" ] || { printf 'fail %%{kak-ide: resolver not executable}\n'; exit 0; }

            found=$("$helper" "$kak_opt_kak_ide_project_root" "$kak_buffile" \
                              "$kak_opt_filetype" "$line" 2>/dev/null)
            n=$(printf '%s' "$found" | grep -c . || true)

            if [ "$n" -eq 1 ]; then
                printf '%s %%{%s}\n' "$1" "$found"
            elif [ "$n" -gt 1 ]; then
                # Ambiguous — let the picker decide rather than guessing.
                list=$(printf '%s' "$found" | sed "s/'/''/g")
                printf "require-module fzf\n"
                printf "fzf -kak-cmd %%{%s} -preview -items-cmd %%{printf '%%s\\\\n' '%s'} -fzf-args %%{--reverse}\n" \
                    "$1" "$list"
            else
                # Nothing on disk matched. Ask the language server, which knows
                # about node_modules and ~/.cargo/registry; fall back to
                # Kakoune's own gf if there is no server.
                printf 'try %%{ lsp-definition } catch %%{ try %%{ execute-keys gf } catch %%{ fail "kak-ide: cannot resolve %s" } }\n' \
                    "$(printf '%s' "$line" | tr -d '\n' | cut -c1-40)"
            fi
        }
    }
}
