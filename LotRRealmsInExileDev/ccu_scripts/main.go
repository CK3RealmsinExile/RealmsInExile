package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

func main() {
	fmt.Println()
	fmt.Println("#################################################")
	fmt.Println("CCU Patcher")
	fmt.Println("By Vertimnus")
	currentTime := time.Now()
	fmt.Println("Compiled " + currentTime.Month().String() + " " + strconv.Itoa(currentTime.Day()) + ", " + strconv.Itoa(currentTime.Year()))
	fmt.Println("#################################################")
	fmt.Println()
	time.Sleep(100)

	path, _ := os.Getwd()
	modDirectory := filepath.Dir(path)

	var configInfo configData
	configInfo.modOutFolder = modDirectory
	configInfo.pillarsFolder = filepath.Join(configInfo.modOutFolder, "common", "culture", "pillars")
	configInfo.localizationOutFolder = filepath.Join(configInfo.modOutFolder, "localization", "english", "ccu")
	configInfo.scriptedEffectsOutFolder = filepath.Join(configInfo.modOutFolder, "common", "scripted_effects")
	configInfo.scriptedGUIOutFolder = filepath.Join(configInfo.modOutFolder, "common", "scripted_guis")
	writeCCUFiles(configInfo)
	bakEliminator(modDirectory)
}

func writeHeader(outFile *os.File) {
	_, _ = outFile.WriteString("\ufeff")
	_, _ = outFile.WriteString("#############################################\n")
	_, _ = outFile.WriteString("# CCU Patcher\n")
	_, _ = outFile.WriteString("# by Vertimnus\n")
	_, _ = outFile.WriteString("# This file was compiled by a machine.\n")
	_, _ = outFile.WriteString("# It should never be manually edited.\n")
	_, _ = outFile.WriteString("#############################################\n\n")
}