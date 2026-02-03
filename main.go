package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/eventlog"
)

var (
	user32                     = syscall.NewLazyDLL("user32.dll")
	kernel32                   = syscall.NewLazyDLL("kernel32.dll")
	openClipboard              = user32.NewProc("OpenClipboard")
	closeClipboard             = user32.NewProc("CloseClipboard")
	getClipboardData           = user32.NewProc("GetClipboardData")
	getClipboardOwner          = user32.NewProc("GetClipboardOwner")
	getWindowThreadProcessId   = user32.NewProc("GetWindowThreadProcessId")
	openProcess                = kernel32.NewProc("OpenProcess")
	queryFullProcessImageNameW = kernel32.NewProc("QueryFullProcessImageNameW")
	closeHandle                = kernel32.NewProc("CloseHandle")
)

const (
	CF_UNICODETEXT     = 13
	PROCESS_QUERY_INFO = 0x0400
)

func getClipboardText() string {
	ret, _, _ := openClipboard.Call(0)
	if ret == 0 {
		return ""
	}
	defer closeClipboard.Call()

	h, _, _ := getClipboardData.Call(CF_UNICODETEXT)
	if h == 0 {
		return ""
	}

	ptr := (*uint16)(unsafe.Pointer(h))
	text := syscall.UTF16ToString((*[1 << 20]uint16)(unsafe.Pointer(ptr))[:])
	return text
}

func getClipboardOwnerProcess() (string, uint32, error) {
	hwnd, _, _ := getClipboardOwner.Call()
	if hwnd == 0 {
		return "", 0, fmt.Errorf("no clipboard owner")
	}

	var processID uint32
	getWindowThreadProcessId.Call(hwnd, uintptr(unsafe.Pointer(&processID)))

	if processID == 0 {
		return "", 0, fmt.Errorf("could not get process ID")
	}

	hProcess, _, _ := openProcess.Call(PROCESS_QUERY_INFO, 0, uintptr(processID))
	if hProcess == 0 {
		return "", processID, fmt.Errorf("could not open process")
	}
	defer closeHandle.Call(hProcess)

	var size uint32 = 260
	buf := make([]uint16, size)
	queryFullProcessImageNameW.Call(
		hProcess,
		0,
		uintptr(unsafe.Pointer(&buf[0])),
		uintptr(unsafe.Pointer(&size)),
	)

	exePath := syscall.UTF16ToString(buf)
	return exePath, processID, nil
}

type clipboardService struct {
	logger *log.Logger
}

func (m *clipboardService) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (ssec bool, errno uint32) {
	const cmdsAccepted = svc.AcceptStop | svc.AcceptShutdown
	changes <- svc.Status{State: svc.StartPending}
	changes <- svc.Status{State: svc.Running, Accepts: cmdsAccepted}

	// Get executable directory for log file
	exePath, _ := os.Executable()
	logDir := filepath.Dir(exePath)
	logPath := filepath.Join(logDir, "clipboard_hijacker_log.txt")

	logFile, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer logFile.Close()

	m.logger = log.New(logFile, "", log.LstdFlags)
	m.logger.Println("Clipboard Hijacker Detection Service Started")

	scammerAddress := "0x6bf57f255a78D197f5F7328830a168914ed2724D"
	lastClipboard := ""
	detectionCount := 0

	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

loop:
	for {
		select {
		case <-ticker.C:
			currentClipboard := getClipboardText()

			if currentClipboard != lastClipboard && lastClipboard != "" {
				if strings.Contains(currentClipboard, scammerAddress) {
					detectionCount++
					timestamp := time.Now().Format("2006-01-02 15:04:05")

					exePath, pid, err := getClipboardOwnerProcess()
					if err == nil {
						logMsg := fmt.Sprintf("\n[DETECTION #%d] %s\nPID: %d\nLocation: %s\nOriginal: %s\nReplaced with: %s\n",
							detectionCount, timestamp, pid, exePath, lastClipboard, currentClipboard)
						m.logger.Println(logMsg)
					} else {
						logMsg := fmt.Sprintf("\n[DETECTION #%d] %s\nCould not identify process: %v\nOriginal: %s\nReplaced with: %s\n",
							detectionCount, timestamp, err, lastClipboard, currentClipboard)
						m.logger.Println(logMsg)
					}
				}
			}

			lastClipboard = currentClipboard

		case c := <-r:
			switch c.Cmd {
			case svc.Interrogate:
				changes <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				m.logger.Println("Service stopping...")
				break loop
			default:
				m.logger.Printf("Unexpected control request #%d", c)
			}
		}
	}

	changes <- svc.Status{State: svc.StopPending}
	return
}

func runService(name string, isDebug bool) {
	var err error
	if isDebug {
		elog, _ := eventlog.Open(name)
		defer elog.Close()
		elog.Info(1, fmt.Sprintf("starting %s service", name))
	}

	run := svc.Run
	err = run(name, &clipboardService{})
	if err != nil {
		return
	}

	if isDebug {
		elog, _ := eventlog.Open(name)
		defer elog.Close()
		elog.Info(1, fmt.Sprintf("%s service stopped", name))
	}
}

func main() {
	const svcName = "ClipCatcher"

	isIntSess, err := svc.IsAnInteractiveSession()
	if err != nil {
		log.Fatalf("failed to determine if we are running in an interactive session: %v", err)
	}

	if !isIntSess {
		runService(svcName, false)
		return
	}

	fmt.Println("This program is designed to run as a Windows service.")
	fmt.Println("Use install.bat to install the service.")
}
