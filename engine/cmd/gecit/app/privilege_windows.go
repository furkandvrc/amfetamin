package app

import (
	"fmt"

	"golang.org/x/sys/windows"
)

func checkPrivileges() error {
	var sid *windows.SID
	err := windows.AllocateAndInitializeSid(
		&windows.SECURITY_NT_AUTHORITY,
		2,
		windows.SECURITY_BUILTIN_DOMAIN_RID,
		windows.DOMAIN_ALIAS_RID_ADMINS,
		0, 0, 0, 0, 0, 0,
		&sid,
	)
	if err != nil {
		return fmt.Errorf("check admin: %w", err)
	}
	defer windows.FreeSid(sid)

	token := windows.Token(0)
	member, err := token.IsMember(sid)
	if err != nil {
		return fmt.Errorf("check admin: %w", err)
	}
	if !member {
		return fmt.Errorf("gecit requires Administrator privileges — run as Administrator")
	}
	return nil
}
