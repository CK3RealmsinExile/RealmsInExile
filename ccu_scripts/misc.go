package main

type configData struct {
	modOutFolder string

	mapDataFolder string
	mapDataBackupFolder string
	landedTitleFolder string

	innovationsFolder string
	tenetsFolder string
	traditionsFolder string
	pillarsFolder string

	terrainFolder string
	metamodFolder string

	onActionsFolder string

	processMap bool
	printEvents bool
	patchMode bool

	pixel_exponent float64

	dependencies []string

	// derivative parameters
	scriptedEffectsOutFolder string
	localizationOutFolder    string
	scriptedGUIOutFolder     string
}

// removes comment blocks from a line (string)
func cleanLine(line string) string {
	// Look out for following byte signifying a comment
	commentByte := []byte("#")[0]
	// iterate through all bytes in line
	for i := 0; i < len(line); i++ {
		// if byte = comment byte, return line up until that byte
		if line[i] == commentByte {
			if i > 1 { return line[0:i] } else { return "" }
		}
	}
	// if no comments found, return whole line
	return line
}