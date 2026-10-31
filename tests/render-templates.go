// Offline syntax/render validation using Go's template engine. This is not a
// replacement for the still-required real chezmoi dry-run on a clean Mac.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"text/template"
)

func main() {
	if len(os.Args) != 4 {
		panic("usage: render-templates REPOSITORY DESTINATION ARCH")
	}
	repo, dest, arch := os.Args[1], os.Args[2], os.Args[3]
	funcs := template.FuncMap{
		"quote":    strconv.Quote,
		"joinPath": filepath.Join,
		"include": func(path string) (string, error) {
			data, err := os.ReadFile(path)
			return string(data), err
		},
		"fromJson": func(s string) (any, error) {
			var value any
			err := json.Unmarshal([]byte(s), &value)
			return value, err
		},
	}
	data := map[string]any{"chezmoi": map[string]any{
		"workingTree": repo, "sourceDir": repo, "destDir": dest,
		"homeDir": "/Users/isolated-fixture", "arch": arch, "os": "darwin",
	}}
	err := filepath.WalkDir(filepath.Join(repo, "home"), func(path string, entry os.DirEntry, err error) error {
		if err != nil || entry.IsDir() || !strings.HasSuffix(path, ".tmpl") {
			return err
		}
		rel, err := filepath.Rel(filepath.Join(repo, "home"), path)
		if err != nil {
			return err
		}
		parts := strings.Split(strings.TrimSuffix(rel, ".tmpl"), string(filepath.Separator))
		for i, part := range parts {
			part = strings.TrimPrefix(part, "empty_")
			part = strings.TrimPrefix(part, "executable_")
			if strings.HasPrefix(part, "dot_") {
				part = "." + strings.TrimPrefix(part, "dot_")
			}
			parts[i] = part
		}
		out := filepath.Join(append([]string{dest}, parts...)...)
		if err := os.MkdirAll(filepath.Dir(out), 0700); err != nil {
			return err
		}
		file, err := os.Create(out)
		if err != nil {
			return err
		}
		defer file.Close()
		text, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		t, err := template.New(rel).Option("missingkey=error").Funcs(funcs).Parse(string(text))
		if err != nil {
			return err
		}
		return t.Execute(file, data)
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
