package main

import (
	"context"
	"runtime"
	"strconv"
	"strings"
	"time"
)

func collectTopProcesses() []ProcessInfo {
	if runtime.GOOS != "darwin" {
		return nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	// Use ps to get top processes by CPU.
	out, err := runCmd(ctx, "ps", "-Aceo", "pcpu,pmem,comm", "-r")
	if err != nil {
		return nil
	}

	lines := strings.Split(strings.TrimSpace(out), "\n")
	var procs []ProcessInfo
	for i, line := range lines {
		if i == 0 {
			continue
		}
		if i > 5 {
			break
		}
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		cpuVal, _ := strconv.ParseFloat(fields[0], 64)
		memVal, _ := strconv.ParseFloat(fields[1], 64)
		name := fields[len(fields)-1]
		// Strip path from command name.
		if idx := strings.LastIndex(name, "/"); idx >= 0 {
			name = name[idx+1:]
		}
		procs = append(procs, ProcessInfo{
			Name:   name,
			CPU:    cpuVal,
			Memory: memVal,
		})
	}
	return procs
}
