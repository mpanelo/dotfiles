# tmux

## Rename Session

```bash
tmux rename-session -t [target-session] [new-name]
# alias rename
```

OR `<Prefix> + $`

# vim

## Copy to system clipboard

`"+y`

## Telescope

### fzf-native

Use [fzf syntax](https://github.com/junegunn/fzf#search-syntax) in your Telescope queries.

| Token     | Match type                 | Description                          |
| --------- | -------------------------- | ------------------------------------ |
| `sbtrkt`  | fuzzy-match                | Items that match `sbtrkt`            |
| `'wild`   | exact-match (quoted)       | Items that include `wild`            |
| `^music`  | prefix-exact-match         | Items that start with `music`        |
| `.mp3$`   | suffix-exact-match         | Items that end with `.mp3`           |
| `!fire`   | inverse-exact-match        | Items that do not include `fire`     |
| `!^music` | inverse-prefix-exact-match | Items that do not start with `music` |
| `!.mp3$`  | inverse-suffix-exact-match | Items that do not end with `.mp3`    |
