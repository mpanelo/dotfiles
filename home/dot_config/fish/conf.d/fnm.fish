# fnm is available on demand; no version installation or directory auto-switching.
if status is-interactive; and command -q fnm
    fnm env --shell fish | source
end
