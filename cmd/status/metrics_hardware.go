package main

import (
	"context"
	"runtime"
	"strings"
	"time"
)

func collectHardware(totalRAM uint64, disks []DiskStatus) HardwareInfo {
	if runtime.GOOS != "darwin" {
		return HardwareInfo{
			Model:     "Unknown",
			CPUModel:  runtime.GOARCH,
			TotalRAM:  humanBytes(totalRAM),
			DiskSize:  "Unknown",
			OSVersion: runtime.GOOS,
		}
	}

	// Model and CPU from system_profiler.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	var model, cpuModel, osVersion string

	out, err := runCmd(ctx, "system_profiler", "SPHardwareDataType")
	if err == nil {
		lines := strings.Split(out, "\n")
		for _, line := range lines {
			lower := strings.ToLower(strings.TrimSpace(line))
			// Prefer "Model Name" over "Model Identifier".
			if strings.Contains(lower, "model name:") {
				parts := strings.Split(line, ":")
				if len(parts) == 2 {
					model = strings.TrimSpace(parts[1])
				}
			}
			if strings.Contains(lower, "chip:") {
				parts := strings.Split(line, ":")
				if len(parts) == 2 {
					cpuModel = strings.TrimSpace(parts[1])
				}
			}
			if strings.Contains(lower, "processor name:") && cpuModel == "" {
				parts := strings.Split(line, ":")
				if len(parts) == 2 {
					cpuModel = strings.TrimSpace(parts[1])
				}
			}
		}
	}

	ctx2, cancel2 := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel2()
	out2, err := runCmd(ctx2, "sw_vers", "-productVersion")
	if err == nil {
		osVersion = "macOS " + strings.TrimSpace(out2)
	}

	diskSize := "Unknown"
	if len(disks) > 0 {
		diskSize = humanBytes(disks[0].Total)
	}

	return HardwareInfo{
		Model:     model,
		CPUModel:  cpuModel,
		TotalRAM:  humanBytes(totalRAM),
		DiskSize:  diskSize,
		OSVersion: osVersion,
	}
}
