# kak-ide — project root detection
#
# Shared primitive. Section 6.1 (tool detection), 7.2 (find/replace),
# 7.3 (import resolution) and 7.4 (pickers) all resolve paths against the
# project root rather than the server's working directory.

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
    # Sets $root to the project root of $kak_buffile.
    # Prefers the VCS toplevel; falls back to the nearest marker file;
    # falls back again to the server's cwd.
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
        # Kakoune only exports the kak_* variables it can see spelled out in
        # this block. The snippet below is eval'd from an option, so name the
        # variables it needs here or they arrive unset and $root falls back
        # to the server's cwd.
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

# Resolve the root once per buffer, before anything that depends on it.
hook global BufCreate .* kak-ide-detect-root
hook global BufWritePost .* kak-ide-detect-root
