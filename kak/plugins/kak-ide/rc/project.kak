
declare-option -docstring %{
    Files/directories that mark a project root, in priority order.
    A VCS root always wins over these.
} str-list kak_ide_root_markers \
    .git .hg .svn .jj .project-root \
    Cargo.toml package.json tsconfig.json jsconfig.json deno.json \
    go.mod pyproject.toml .luarc.json Makefile

declare-option -docstring "project root of the current buffer (cached)" \
    str kak_ide_project_root

declare-option -hidden str kak_ide_root_sh %{
    dir="${kak_buffile%/*}"
    [ -d "$dir" ] || dir="$PWD"
    root=$(cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$root" ]; then
        eval "set -- $kak_quoted_opt_kak_ide_root_markers"
        d="$dir"
        while [ -n "$d" ] && [ "$d" != "/" ]; do
            for m do
                if [ -e "$d/$m" ]; then root="$d"; break 2; fi
            done
            d="${d%/*}"
        done
    fi
    [ -n "$root" ] || root="$PWD"
}

define-command kak-ide-detect-root -docstring %{
    kak-ide-detect-root: resolve and cache the current buffer's project root
} %{
    set-option buffer kak_ide_project_root %sh{
        : "$kak_buffile" "$kak_quoted_opt_kak_ide_root_markers"
        eval "$kak_opt_kak_ide_root_sh"
        printf '%s' "$root"
    }
}

define-command kak-ide-project-root -docstring %{
    kak-ide-project-root: echo the current buffer's project root
} %{
    kak-ide-detect-root
    echo -markup "{Information}%opt{kak_ide_project_root}"
}

hook global BufCreate .* kak-ide-detect-root
hook global BufWritePost .* kak-ide-detect-root
