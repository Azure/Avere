package file

import (
	"os"
	"sync"

	"github.com/Azure/Avere/src/go/pkg/log"
)

// DirectoryManager ensures directories are created, and ensuring only a single create ever gets sent to filesystem
type DirectoryManager struct {
	mux         sync.Mutex
	directories map[string]bool
}

// InitializeDirectoryManager initilizes the directory manager
func InitializeDirectoryManager() *DirectoryManager {
	return &DirectoryManager{
		directories: make(map[string]bool),
	}
}

// EnsureDirectory ensures the directory exists, and if already created returns the directory
func (d *DirectoryManager) EnsureDirectory(path string) error {
	d.mux.Lock()
	defer d.mux.Unlock()

	if _, ok := d.directories[path]; !ok {
		log.Info.Printf("os.MkdirAll(%s)", path)
		if e := os.MkdirAll(path, os.ModePerm); e != nil {
			return e
		}
		d.directories[path] = true
	}

	return nil
}
