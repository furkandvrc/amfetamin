package dns

import (
	"os"
	"path/filepath"
)

const legacyDNSBackupName = "gecit-dns-backup"

func dnsBackupPaths() []string {
	switch {
	case os.Getenv("ProgramData") != "":
		base := os.Getenv("ProgramData")
		return []string{
			filepath.Join(base, "amfetamin-dns-backup"),
			filepath.Join(base, legacyDNSBackupName),
		}
	default:
		return []string{
			"/tmp/amfetamin-dns-backup",
			"/tmp/" + legacyDNSBackupName,
		}
	}
}

func primaryDNSBackupPath() string {
	return dnsBackupPaths()[0]
}

func ReadDNSBackup() ([]byte, string, error) {
	for _, p := range dnsBackupPaths() {
		if data, err := os.ReadFile(p); err == nil {
			return data, p, nil
		}
	}
	return nil, "", os.ErrNotExist
}

func RemoveDNSBackupFiles() {
	for _, p := range dnsBackupPaths() {
		os.Remove(p)
	}
}
