function awb --description 'Launch Agent Workbench; Ctrl-b Shift-b returns to its tmux pane'
    set -l workbench_manifest "$HOME/workspace/github/agent-workbench/Cargo.toml"
    if not command -q workbench; and not test -f "$workbench_manifest"
        echo "awb: workbench is not installed and $workbench_manifest was not found." >&2
        return 1
    end

    # Only TUI launches register a return shortcut; CLI subcommands leave it alone.
    if set -q TMUX; and set -q TMUX_PANE; and not contains -- "$argv[1]" register list --help
        command tmux bind-key B switch-client -t "$TMUX_PANE"
        or return $status
    end

    if command -q workbench
        command workbench $argv
    else
        command cargo run --quiet --manifest-path "$workbench_manifest" -p workbench-tui --bin workbench -- $argv
    end
end
