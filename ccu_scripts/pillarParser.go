package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
)

func writeCCUFiles(configInfo configData) {
	fmt.Println("Reading heritage groups...")
	heritageGroups := getCCUKeys(configInfo.pillarsFolder, "heritage_group")
	fmt.Println("Reading heritage families...")
	heritageFamilies := getCCUKeys(configInfo.pillarsFolder, "heritage_family")
	fmt.Println("Reading language groups...")
	languageGroups := getCCUKeys(configInfo.pillarsFolder, "language_group")
	fmt.Println("Reading language families...")
	languageFamilies := getCCUKeys(configInfo.pillarsFolder, "language_family")
	fmt.Println("Reading language unions...")
	languageUnions := getCCUKeys(configInfo.pillarsFolder, "language_union")

	fmt.Println("Creating scripted effect file...")
	outFile, err := os.Create(filepath.Join(configInfo.scriptedEffectsOutFolder, "ccu_scripted_effects.txt"))
	if err != nil {
		log.Fatal(err)
	}
	writeHeader(outFile)
	_, err = outFile.WriteString("ccu_initialize_culture = {\n")
	_, err = outFile.WriteString("\tccu_initialize_heritage_group = yes\n")
	_, err = outFile.WriteString("\tccu_initialize_heritage_family = yes\n")
	_, err = outFile.WriteString("\tccu_initialize_language_group = yes\n")
	_, err = outFile.WriteString("\tccu_initialize_language_family = yes\n")
	_, err = outFile.WriteString("\tccu_initialize_language_union = yes\n")
	_, err = outFile.WriteString("}\n\n")
	writeCCUEffects(heritageGroups, "heritage_group", false, outFile)
	_, err = outFile.WriteString("\n\n")
	writeCCUEffects(heritageFamilies, "heritage_family", false, outFile)
	_, err = outFile.WriteString("\n\n")
	writeCCUEffects(languageGroups, "language_group", false, outFile)
	_, err = outFile.WriteString("\n\n")
	writeCCUEffects(languageFamilies, "language_family", false,outFile)
	_, err = outFile.WriteString("\n\n")
	writeCCUEffects(languageUnions, "language_union", true, outFile)


	fmt.Println("Creating localization files...")
	writeCCULocalization(configInfo.localizationOutFolder, heritageGroups, "heritage_group", "-")
	writeCCULocalization(configInfo.localizationOutFolder, heritageFamilies, "heritage_family", " ")
	writeCCULocalization(configInfo.localizationOutFolder, languageGroups, "language_group", "-")
	writeCCULocalization(configInfo.localizationOutFolder, languageFamilies, "language_family", "-")
	writeCCULocalization(configInfo.localizationOutFolder, languageUnions, "language_union", "-")
	allKeys := [][]string{heritageFamilies, heritageGroups, languageFamilies, languageGroups, languageUnions}
	writeCCUGUI(allKeys, configInfo.scriptedGUIOutFolder)

}

func writeCCULocalization(locDir string, keys []string, varName string, delimiter string) {
	outFile, err := os.Create(filepath.Join(locDir, "ccu_" +varName+ "_l_english.yml"))
	if err != nil {
		log.Fatal(err)
	}
	writeLocHeader(outFile)
	for _, key := range keys {

		fields := strings.Split(key, "_")[2:]
		newKey := ""
		for _, field := range fields {
			newKey += field + delimiter
		}
		newKey = newKey[0:len(newKey)-1]
		newKey = strings.Title(newKey)
		gameConcept := "[" + varName + "|E]"
		_, err = outFile.WriteString("culture_parameter_" + key + ":0 \"#P +[EmptyScope.ScriptValue('same_" + varName + "_cultural_acceptance')|0]#! [cultural_acceptance_baseline|E] with Cultures sharing the " + newKey + " " + gameConcept + "\"\n")
	}
}

func writeCCUGUI(keys [][]string, guiDir string) {
	_, err := os.Stat(guiDir)
	if err != nil {
		_ = os.Mkdir(guiDir, 755)
	}
	outFile, err := os.Create(filepath.Join(guiDir, "ccu_dummy.txt"))
	if err != nil {
		log.Fatal(err)
	}
	writeHeader(outFile)
	_, err = outFile.WriteString("ccu_dummy = {\n\tscope = province\n\teffect = {\n")
	for _, keySlice := range keys {
		for _, key := range keySlice {
			_, err = outFile.WriteString("\t\tif = { limit = { var:temp = flag:" + key2flag(key) + " } set_variable = { name = temp value = flag:" + key2flag(key) + " } }\n")
		}
	}
	_, err = outFile.WriteString("\t}\n}")
}

func writeCCUEffects(keys []string, varName string, defaultNone bool, outFile *os.File) {
	_, _ = outFile.WriteString("ccu_initialize_" + varName + " = {\n")
	if len(keys) > 0 {
		for i, key := range keys {
			flagName := key2flag(key)
			if i == 0 {
				_, _ = outFile.WriteString("\tif = { limit = { has_cultural_parameter = " + key + " } set_variable = { name = " + varName + " value = flag:" + flagName + " } }\n")
			} else {
				_, _ = outFile.WriteString("\telse_if = { limit = { has_cultural_parameter = " + key + " } set_variable = { name = " + varName + " value = flag:" + flagName + " } }\n")
			}
		}
		if defaultNone { _, _ = outFile.WriteString("\telse = { set_variable = { name = " + varName + " value = flag:none } }\n") }
	} else {
		_, _ = outFile.WriteString("\tset_variable = { name = " + varName + " value = flag:none }\n")
	}
	_, _ = outFile.WriteString("}\n\n")
}

func key2flag(key string) string {
	keyFields := strings.Split(key, "_")[2:]
	flagName := keyFields[0]
	for i := 1; i < len(keyFields); i++ {
		flagName += "_" + keyFields[i]
	}
	return flagName
}

func getCCUKeys(inDir string, searchString string) []string {

	keys := make(map[string]int)

	fileInfo, err := ioutil.ReadDir(inDir)
	if err != nil {
		fmt.Println("failed to read directory: " + inDir)
		log.Fatal(err)
	}
	for _, file := range fileInfo {
		filePath := filepath.Join(inDir, file.Name())
		thisFile, err := os.Open(filePath)
		if err != nil {
			fmt.Println("Failed to open file: " + filePath)
			log.Fatal(err)
		}
		scanner := bufio.NewScanner(thisFile)
		for scanner.Scan() {
			line := cleanLine(scanner.Text())
			if strings.Contains(line, "= yes") {
				fields := strings.Fields(line)
				for _, field := range fields {
					if strings.Contains(field, searchString) {
						if _, ok := keys[field]; ok {
							keys[field]++
						} else {
							keys[field] = 1
						}
					}
				}
			}
		}
		_ = thisFile.Close()
	}

	keySlice := make([]string, 0)
	for key := range keys {
		keySlice = append(keySlice, key)
	}
	keySlice = qsort(keySlice)
	return keySlice
}

func writeLocHeader(outFile *os.File) {
	_, _ = outFile.WriteString("\ufeff")
	_, _ = outFile.WriteString("l_english:\n\n")
	_, _ = outFile.WriteString("#############################################\n")
	_, _ = outFile.WriteString("# CCU Patcher\n")
	_, _ = outFile.WriteString("# by Vertimnus\n")
	_, _ = outFile.WriteString("# This file was compiled by a machine.\n")
	_, _ = outFile.WriteString("# It should never be manually edited.\n")
	_, _ = outFile.WriteString("#############################################\n\n")
}

func bakEliminator(path string) {
	_ = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Fatalf(err.Error())
		}
		if !info.IsDir() && len(strings.Split(info.Name(), ".")) > 1 && strings.Split(info.Name(), ".")[len(strings.Split(info.Name(), "."))-1] == "bak" {
			fmt.Printf("Deleting: %s\n", info.Name())
			err = os.Remove(path)
			if err != nil {
				log.Fatal(err)
			}
		}

		return nil
	})
}