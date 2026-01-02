package main

import (
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync/atomic"

	tea "github.com/charmbracelet/bubbletea"
)

func deletePathCmd(path string, counter *int64) tea.Cmd {
	return func() tea.Msg {
		count, err := deletePathWithProgress(path, counter)
		return deleteProgressMsg{
			done:  true,
			err:   err,
			count: count,
			path:  path,
		}
	}
}

// deleteMultiplePathsCmd deletes paths and aggregates results.
func deleteMultiplePathsCmd(paths []string, counter *int64) tea.Cmd {
	return func() tea.Msg {
		var totalCount int64
		var errors []string

		// Delete deeper paths first to avoid parent/child conflicts.
		pathsToDelete := append([]string(nil), paths...)
		sort.Slice(pathsToDelete, func(i, j int) bool {
			return strings.Count(pathsToDelete[i], string(filepath.Separator)) > strings.Count(pathsToDelete[j], string(filepath.Separator))
		})

		for _, path := range pathsToDelete {
			count, err := deletePathWithProgress(path, counter)
			totalCount += count
			if err != nil {
				if os.IsNotExist(err) {
					continue
				}
				errors = append(errors, err.Error())
			}
		}

		var resultErr error
		if len(errors) > 0 {
			resultErr = &multiDeleteError{errors: errors}
		}

		return deleteProgressMsg{
			done:  true,
			err:   resultErr,
			count: totalCount,
			path:  "",
		}
	}
}

// multiDeleteError holds multiple deletion errors.
type multiDeleteError struct {
	errors []string
}

func (e *multiDeleteError) Error() string {
	if len(e.errors) == 1 {
		return e.errors[0]
	}
	return strings.Join(e.errors[:min(3, len(e.errors))], "; ")
}

func deletePathWithProgress(root string, counter *int64) (int64, error) {
	var count int64
	var firstErr error

	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			// Skip permission errors but continue.
			if os.IsPermission(err) {
				if firstErr == nil {
					firstErr = err
				}
				return filepath.SkipDir
			}
			if firstErr == nil {
				firstErr = err
			}
			return nil
		}

		if !d.IsDir() {
			if removeErr := os.Remove(path); removeErr == nil {
				count++
				if counter != nil {
					atomic.StoreInt64(counter, count)
				}
			} else if firstErr == nil {
				firstErr = removeErr
			}
		}

		return nil
	})

	if err != nil && firstErr == nil {
		firstErr = err
	}

	if removeErr := os.RemoveAll(root); removeErr != nil {
		if firstErr == nil {
			firstErr = removeErr
		}
	}

	return count, firstErr
}
