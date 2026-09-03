function q(s) {
    gsub(/'/, "''", s)
    return "'" s "' "
}
{ body = body $0 "\n" }
END {
    sub(/\n$/, "", body)
    gsub(/\$\{[0-9]+:/, "${", body)
    gsub(/\$\{[0-9]+\}/, "${}", body)
    gsub(/\$[0-9]+/, "${}", body)
    printf "%s", q(ENVIRON["KAK_SNIP_DESC"])
    printf "%s", q(ENVIRON["KAK_SNIP_TRIG"])
    printf "%s", q("snippets-insert " q(body))
}
